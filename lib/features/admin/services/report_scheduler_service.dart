// lib/features/admin/services/report_scheduler_service.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/report_schedule.dart';
import '../../../core/services/app_logger.dart';

class ReportSchedulerService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all schedules for current user
  static Stream<List<ReportSchedule>> getUserSchedules() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _database
        .ref('report_schedules/$userId')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <ReportSchedule>[];

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.entries
          .map((entry) => ReportSchedule.fromMap(
                Map<String, dynamic>.from(entry.value),
                entry.key,
              ))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }).handleError((error) {
      AppLogger.error('Error loading report schedules', error: error);
      return <ReportSchedule>[];
    });
  }

  // Create new schedule
  static Future<bool> createSchedule(ReportSchedule schedule) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final ref = _database.ref('report_schedules/$userId').push();
      final scheduleWithId = schedule.copyWith(
        id: ref.key!,
        userId: userId,
        nextScheduled: schedule.calculateNextScheduledDate(),
      );

      await ref.set(scheduleWithId.toMap());

      AppLogger.info('Report schedule created', data: {
        'scheduleId': ref.key,
        'frequency': schedule.frequency,
      });

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error creating report schedule',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Update existing schedule
  static Future<bool> updateSchedule(ReportSchedule schedule) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final updatedSchedule = schedule.copyWith(
        nextScheduled: schedule.calculateNextScheduledDate(),
      );

      await _database
          .ref('report_schedules/$userId/${schedule.id}')
          .update(updatedSchedule.toMap());

      AppLogger.info('Report schedule updated', data: {
        'scheduleId': schedule.id,
        'frequency': schedule.frequency,
      });

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error updating report schedule',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Delete schedule
  static Future<bool> deleteSchedule(String scheduleId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _database.ref('report_schedules/$userId/$scheduleId').remove();

      AppLogger.info('Report schedule deleted', data: {
        'scheduleId': scheduleId,
      });

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting report schedule',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Toggle schedule enabled/disabled
  static Future<bool> toggleSchedule(String scheduleId, bool isEnabled) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _database
          .ref('report_schedules/$userId/$scheduleId')
          .update({'isEnabled': isEnabled});

      AppLogger.info('Report schedule toggled', data: {
        'scheduleId': scheduleId,
        'isEnabled': isEnabled,
      });

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error toggling report schedule',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Mark schedule as sent (update lastSent and nextScheduled)
  static Future<bool> markScheduleAsSent(String scheduleId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get current schedule to calculate next date
      final snapshot = await _database
          .ref('report_schedules/$userId/$scheduleId')
          .get();

      if (!snapshot.exists) return false;

      final schedule = ReportSchedule.fromMap(
        Map<String, dynamic>.from(snapshot.value as Map),
        scheduleId,
      );

      await _database
          .ref('report_schedules/$userId/$scheduleId')
          .update({
        'lastSent': DateTime.now().toIso8601String(),
        'nextScheduled': schedule.calculateNextScheduledDate().toIso8601String(),
      });

      AppLogger.info('Report schedule marked as sent', data: {
        'scheduleId': scheduleId,
      });

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error marking schedule as sent',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Get all active schedules (for backend processing - would be used by Cloud Functions)
  static Future<List<ReportSchedule>> getAllActiveSchedules() async {
    try {
      final snapshot = await _database.ref('report_schedules').get();
      if (!snapshot.exists) return [];

      final allSchedules = <ReportSchedule>[];
      final usersData = Map<String, dynamic>.from(snapshot.value as Map);

      for (final userEntry in usersData.entries) {
        final userSchedules = Map<String, dynamic>.from(userEntry.value);
        for (final scheduleEntry in userSchedules.entries) {
          final schedule = ReportSchedule.fromMap(
            Map<String, dynamic>.from(scheduleEntry.value),
            scheduleEntry.key,
          );
          if (schedule.isEnabled) {
            allSchedules.add(schedule);
          }
        }
      }

      return allSchedules;
    } catch (e, stackTrace) {
      AppLogger.error('Error loading all active schedules',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }
}
