// lib/features/admin/models/report_schedule.dart

class ReportSchedule {
  final String id;
  final String userId;
  final String userEmail;
  final String frequency; // 'daily', 'weekly', 'monthly'
  final int? dayOfWeek; // 1-7 for weekly (1=Monday)
  final int? dayOfMonth; // 1-31 for monthly
  final String timeOfDay; // HH:mm format (e.g., "09:00")
  final List<String> recipientEmails;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? lastSent;
  final DateTime? nextScheduled;

  ReportSchedule({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.frequency,
    this.dayOfWeek,
    this.dayOfMonth,
    required this.timeOfDay,
    required this.recipientEmails,
    required this.isEnabled,
    required this.createdAt,
    this.lastSent,
    this.nextScheduled,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'frequency': frequency,
      'dayOfWeek': dayOfWeek,
      'dayOfMonth': dayOfMonth,
      'timeOfDay': timeOfDay,
      'recipientEmails': recipientEmails,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'lastSent': lastSent?.toIso8601String(),
      'nextScheduled': nextScheduled?.toIso8601String(),
    };
  }

  factory ReportSchedule.fromMap(Map<String, dynamic> map, String id) {
    return ReportSchedule(
      id: id,
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      frequency: map['frequency'] ?? 'monthly',
      dayOfWeek: map['dayOfWeek'],
      dayOfMonth: map['dayOfMonth'],
      timeOfDay: map['timeOfDay'] ?? '09:00',
      recipientEmails: List<String>.from(map['recipientEmails'] ?? []),
      isEnabled: map['isEnabled'] ?? true,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastSent: map['lastSent'] != null ? DateTime.parse(map['lastSent']) : null,
      nextScheduled: map['nextScheduled'] != null ? DateTime.parse(map['nextScheduled']) : null,
    );
  }

  ReportSchedule copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? frequency,
    int? dayOfWeek,
    int? dayOfMonth,
    String? timeOfDay,
    List<String>? recipientEmails,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? lastSent,
    DateTime? nextScheduled,
  }) {
    return ReportSchedule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      frequency: frequency ?? this.frequency,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      recipientEmails: recipientEmails ?? this.recipientEmails,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastSent: lastSent ?? this.lastSent,
      nextScheduled: nextScheduled ?? this.nextScheduled,
    );
  }

  String getFrequencyDisplay() {
    switch (frequency) {
      case 'daily':
        return 'Daily at $timeOfDay';
      case 'weekly':
        final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final dayName = dayOfWeek != null && dayOfWeek! >= 1 && dayOfWeek! <= 7
            ? days[dayOfWeek! - 1]
            : 'Unknown';
        return 'Weekly on $dayName at $timeOfDay';
      case 'monthly':
        return 'Monthly on day $dayOfMonth at $timeOfDay';
      default:
        return 'Unknown frequency';
    }
  }

  DateTime calculateNextScheduledDate() {
    final now = DateTime.now();
    final timeParts = timeOfDay.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    DateTime next;

    switch (frequency) {
      case 'daily':
        next = DateTime(now.year, now.month, now.day, hour, minute);
        if (next.isBefore(now)) {
          next = next.add(const Duration(days: 1));
        }
        break;

      case 'weekly':
        if (dayOfWeek == null) return now;
        next = DateTime(now.year, now.month, now.day, hour, minute);
        // Find next occurrence of the specified day of week
        while (next.weekday != dayOfWeek) {
          next = next.add(const Duration(days: 1));
        }
        if (next.isBefore(now)) {
          next = next.add(const Duration(days: 7));
        }
        break;

      case 'monthly':
        if (dayOfMonth == null) return now;
        next = DateTime(now.year, now.month, dayOfMonth!, hour, minute);
        if (next.isBefore(now)) {
          // Move to next month
          if (now.month == 12) {
            next = DateTime(now.year + 1, 1, dayOfMonth!, hour, minute);
          } else {
            next = DateTime(now.year, now.month + 1, dayOfMonth!, hour, minute);
          }
        }
        break;

      default:
        next = now;
    }

    return next;
  }
}
