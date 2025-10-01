// lib/features/admin/widgets/report_schedule_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/report_schedule.dart';
import '../../../core/services/app_logger.dart';

class ReportScheduleDialog extends StatefulWidget {
  final ReportSchedule? existingSchedule;

  const ReportScheduleDialog({
    super.key,
    this.existingSchedule,
  });

  @override
  State<ReportScheduleDialog> createState() => _ReportScheduleDialogState();
}

class _ReportScheduleDialogState extends State<ReportScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _recipientsController = TextEditingController();

  String _frequency = 'monthly';
  int _dayOfWeek = 1; // Monday
  int _dayOfMonth = 1;
  TimeOfDay _timeOfDay = const TimeOfDay(hour: 9, minute: 0);
  List<String> _recipientEmails = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingSchedule != null) {
      _frequency = widget.existingSchedule!.frequency;
      _dayOfWeek = widget.existingSchedule!.dayOfWeek ?? 1;
      _dayOfMonth = widget.existingSchedule!.dayOfMonth ?? 1;
      _recipientEmails = List.from(widget.existingSchedule!.recipientEmails);
      _recipientsController.text = _recipientEmails.join(', ');

      // Parse time of day
      final timeParts = widget.existingSchedule!.timeOfDay.split(':');
      _timeOfDay = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
    }
  }

  @override
  void dispose() {
    _recipientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.schedule_send, color: theme.primaryColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.existingSchedule != null
                            ? 'Edit Report Schedule'
                            : 'Schedule Performance Report',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Automatically send performance reports via email',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.disabledColor,
                  ),
                ),
                const Divider(height: 32),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Frequency selector
                        Text(
                          'Frequency',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'daily',
                              label: Text('Daily'),
                              icon: Icon(Icons.today),
                            ),
                            ButtonSegment(
                              value: 'weekly',
                              label: Text('Weekly'),
                              icon: Icon(Icons.calendar_view_week),
                            ),
                            ButtonSegment(
                              value: 'monthly',
                              label: Text('Monthly'),
                              icon: Icon(Icons.calendar_month),
                            ),
                          ],
                          selected: {_frequency},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _frequency = newSelection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 24),

                        // Day of week selector (for weekly)
                        if (_frequency == 'weekly') ...[
                          Text(
                            'Day of Week',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _dayOfWeek,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('Monday')),
                              DropdownMenuItem(value: 2, child: Text('Tuesday')),
                              DropdownMenuItem(value: 3, child: Text('Wednesday')),
                              DropdownMenuItem(value: 4, child: Text('Thursday')),
                              DropdownMenuItem(value: 5, child: Text('Friday')),
                              DropdownMenuItem(value: 6, child: Text('Saturday')),
                              DropdownMenuItem(value: 7, child: Text('Sunday')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _dayOfWeek = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Day of month selector (for monthly)
                        if (_frequency == 'monthly') ...[
                          Text(
                            'Day of Month',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _dayOfMonth,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            items: List.generate(
                              31,
                              (index) => DropdownMenuItem(
                                value: index + 1,
                                child: Text('Day ${index + 1}'),
                              ),
                            ),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _dayOfMonth = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Time of day selector
                        Text(
                          'Time of Day',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: theme.dividerColor),
                          ),
                          leading: const Icon(Icons.access_time),
                          title: Text(
                            _timeOfDay.format(context),
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: const Text('Tap to change time'),
                          trailing: const Icon(Icons.edit),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _timeOfDay,
                              builder: (context, child) {
                                return MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                    alwaysUse24HourFormat: false,
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                _timeOfDay = picked;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 24),

                        // Recipients
                        Text(
                          'Recipients',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _recipientsController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                            hintText: 'Enter email addresses separated by commas',
                            helperText: 'Example: user1@example.com, user2@example.com',
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter at least one email address';
                            }
                            final emails = value
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();

                            for (final email in emails) {
                              if (!_isValidEmail(email)) {
                                return 'Invalid email: $email';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Preview
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: theme.primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Schedule Summary',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getScheduleSummary(),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saveSchedule,
                      icon: const Icon(Icons.save),
                      label: Text(widget.existingSchedule != null
                          ? 'Update Schedule'
                          : 'Create Schedule'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getScheduleSummary() {
    final timeStr = _timeOfDay.format(context);
    final recipientCount = _recipientsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .length;

    switch (_frequency) {
      case 'daily':
        return 'Reports will be sent daily at $timeStr to $recipientCount recipient(s)';
      case 'weekly':
        final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        return 'Reports will be sent every ${days[_dayOfWeek - 1]} at $timeStr to $recipientCount recipient(s)';
      case 'monthly':
        return 'Reports will be sent on day $_dayOfMonth of each month at $timeStr to $recipientCount recipient(s)';
      default:
        return '';
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  void _saveSchedule() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Parse recipients
    final recipients = _recipientsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final timeStr = '${_timeOfDay.hour.toString().padLeft(2, '0')}:${_timeOfDay.minute.toString().padLeft(2, '0')}';

    final schedule = ReportSchedule(
      id: widget.existingSchedule?.id ?? '',
      userId: widget.existingSchedule?.userId ?? '',
      userEmail: widget.existingSchedule?.userEmail ?? '',
      frequency: _frequency,
      dayOfWeek: _frequency == 'weekly' ? _dayOfWeek : null,
      dayOfMonth: _frequency == 'monthly' ? _dayOfMonth : null,
      timeOfDay: timeStr,
      recipientEmails: recipients,
      isEnabled: widget.existingSchedule?.isEnabled ?? true,
      createdAt: widget.existingSchedule?.createdAt ?? DateTime.now(),
      lastSent: widget.existingSchedule?.lastSent,
      nextScheduled: widget.existingSchedule?.nextScheduled,
    );

    Navigator.of(context).pop(schedule);
  }
}
