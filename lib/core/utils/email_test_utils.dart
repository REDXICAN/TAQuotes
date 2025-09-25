// lib/core/utils/email_test_utils.dart
// Cross-platform email testing utilities

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../services/email_service.dart';
import '../services/app_logger.dart';

class EmailTestUtils {
  /// Get comprehensive platform information
  static Map<String, dynamic> getPlatformInfo() {
    final info = <String, dynamic>{
      'isWeb': kIsWeb,
      'platformName': EmailService.getPlatformInfo(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (!kIsWeb) {
      try {
        info['operatingSystem'] = Platform.operatingSystem;
        info['operatingSystemVersion'] = Platform.operatingSystemVersion;
        info['localHostname'] = Platform.localHostname;
        info['numberOfProcessors'] = Platform.numberOfProcessors;
        info['pathSeparator'] = Platform.pathSeparator;
        info['localeName'] = Platform.localeName;
      } catch (e) {
        info['platformError'] = e.toString();
      }
    }

    return info;
  }

  /// Test email service configuration and return detailed results
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final emailService = EmailService();
    final platformInfo = getPlatformInfo();

    AppLogger.info('Running email service diagnostics',
        category: LogCategory.email,
        data: platformInfo);

    final diagnostics = await emailService.testConfiguration();
    diagnostics['platformDetails'] = platformInfo;

    return diagnostics;
  }

  /// Send test email and return result
  static Future<bool> sendTestEmail(String recipientEmail) async {
    try {
      final emailService = EmailService();
      return await emailService.sendTestEmail(
        testRecipientEmail: recipientEmail,
        testRecipientName: 'Platform Test Recipient',
      );
    } catch (e) {
      AppLogger.error('Email test failed',
          error: e,
          category: LogCategory.email,
          data: getPlatformInfo());
      return false;
    }
  }

  /// Send test email with attachments and return result
  static Future<bool> sendTestEmailWithAttachments(String recipientEmail) async {
    try {
      final emailService = EmailService();
      return await emailService.sendTestEmailWithAttachments(
        testRecipientEmail: recipientEmail,
        testRecipientName: 'Attachment Test Recipient',
      );
    } catch (e) {
      AppLogger.error('Email attachment test failed',
          error: e,
          category: LogCategory.email,
          data: getPlatformInfo());
      return false;
    }
  }
}

/// Widget for testing email functionality in admin panel
class EmailTestWidget extends StatefulWidget {
  const EmailTestWidget({Key? key}) : super(key: key);

  @override
  State<EmailTestWidget> createState() => _EmailTestWidgetState();
}

class _EmailTestWidgetState extends State<EmailTestWidget> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isAttachmentLoading = false;
  Map<String, dynamic>? _diagnostics;
  String? _testResult;
  String? _attachmentTestResult;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    try {
      final diagnostics = await EmailTestUtils.runDiagnostics();
      setState(() {
        _diagnostics = diagnostics;
      });
    } catch (e) {
      setState(() {
        _testResult = 'Diagnostics failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendTestEmail() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _testResult = 'Please enter a test email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    try {
      final success = await EmailTestUtils.sendTestEmail(_emailController.text.trim());
      setState(() {
        _testResult = success
            ? '✅ Test email sent successfully!'
            : '❌ Failed to send test email';
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Test email error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendAttachmentTest() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _attachmentTestResult = 'Please enter a test email address';
      });
      return;
    }

    setState(() {
      _isAttachmentLoading = true;
      _attachmentTestResult = null;
    });

    try {
      final success = await EmailTestUtils.sendTestEmailWithAttachments(_emailController.text.trim());
      setState(() {
        _attachmentTestResult = success
            ? '✅ Test email with attachments sent successfully!'
            : '❌ Failed to send test email with attachments';
      });
    } catch (e) {
      setState(() {
        _attachmentTestResult = '❌ Attachment test error: $e';
      });
    } finally {
      setState(() {
        _isAttachmentLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.email, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Cross-Platform Email Service Test',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Platform Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Platform: ${EmailService.getPlatformInfo()}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Icon(
                    EmailService.isAvailableOnPlatform
                        ? Icons.check_circle
                        : Icons.error,
                    color: EmailService.isAvailableOnPlatform
                        ? Colors.green
                        : Colors.red,
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Configuration Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EmailService.isGloballyConfigured
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: EmailService.isGloballyConfigured
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    EmailService.isGloballyConfigured
                        ? Icons.check_circle
                        : Icons.error,
                    color: EmailService.isGloballyConfigured
                        ? Colors.green
                        : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    EmailService.isGloballyConfigured
                        ? 'Email service is properly configured'
                        : 'Email service configuration missing',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Test Controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _runDiagnostics,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.settings_suggest),
                    label: const Text('Run Diagnostics'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'Enter test email address',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: (_isLoading || _isAttachmentLoading) ? null : _sendTestEmail,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Send Test'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Attachment Test Row
            Row(
              children: [
                const SizedBox(width: 200), // Align with email field
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || _isAttachmentLoading) ? null : _sendAttachmentTest,
                    icon: _isAttachmentLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file),
                    label: const Text('Test with Attachments'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Results Display
            if (_testResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testResult!.contains('✅')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testResult!.contains('✅')
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _testResult!,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),

            // Attachment Test Results Display
            if (_attachmentTestResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: _attachmentTestResult!.contains('✅')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _attachmentTestResult!.contains('✅')
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _attachmentTestResult!,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),

            if (_diagnostics != null) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Detailed Diagnostics'),
                leading: const Icon(Icons.analytics),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _formatDiagnostics(_diagnostics!),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'This test verifies that the email service works correctly on ${EmailService.getPlatformInfo()}. '
              'The service uses Gmail SMTP and works on all platforms: Web, Android, iOS, Windows, macOS, and Linux.\n\n'
              '• "Send Test": Basic email functionality\n'
              '• "Test with Attachments": PDF and text file attachment support\n'
              '• "Run Diagnostics": Configuration and connectivity check',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDiagnostics(Map<String, dynamic> diagnostics) {
    final buffer = StringBuffer();

    void writeValue(String key, dynamic value, int indent) {
      final spaces = '  ' * indent;
      if (value is Map) {
        buffer.writeln('$spaces$key:');
        value.forEach((k, v) => writeValue(k.toString(), v, indent + 1));
      } else if (value is List) {
        buffer.writeln('$spaces$key: [${value.join(', ')}]');
      } else {
        buffer.writeln('$spaces$key: $value');
      }
    }

    diagnostics.forEach((key, value) => writeValue(key, value, 0));
    return buffer.toString();
  }
}