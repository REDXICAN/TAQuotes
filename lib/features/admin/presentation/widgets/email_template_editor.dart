// lib/features/admin/presentation/widgets/email_template_editor.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/app_logger.dart';

// Provider for email template
final emailTemplateProvider = StateNotifierProvider<EmailTemplateNotifier, EmailTemplate>((ref) {
  return EmailTemplateNotifier();
});

class EmailTemplate {
  final String headerColor;
  final String headerText;
  final String greeting;
  final String body;
  final String footer;
  final String attachmentNote;
  final bool showQuoteTable;
  final bool showLogo;

  const EmailTemplate({
    this.headerColor = '#0066cc',
    this.headerText = 'TurboAir Quote',
    this.greeting = 'Dear {{customerName}},',
    this.body = 'Please find attached your TurboAir quote. If you have any questions or need modifications, please don\'t hesitate to contact your sales representative.',
    this.footer = 'Thank you for choosing TurboAir!',
    this.attachmentNote = '📎 Attachment: The detailed quote with all items and pricing is attached as a PDF document.',
    this.showQuoteTable = true,
    this.showLogo = true,
  });

  EmailTemplate copyWith({
    String? headerColor,
    String? headerText,
    String? greeting,
    String? body,
    String? footer,
    String? attachmentNote,
    bool? showQuoteTable,
    bool? showLogo,
  }) {
    return EmailTemplate(
      headerColor: headerColor ?? this.headerColor,
      headerText: headerText ?? this.headerText,
      greeting: greeting ?? this.greeting,
      body: body ?? this.body,
      footer: footer ?? this.footer,
      attachmentNote: attachmentNote ?? this.attachmentNote,
      showQuoteTable: showQuoteTable ?? this.showQuoteTable,
      showLogo: showLogo ?? this.showLogo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'headerColor': headerColor,
      'headerText': headerText,
      'greeting': greeting,
      'body': body,
      'footer': footer,
      'attachmentNote': attachmentNote,
      'showQuoteTable': showQuoteTable,
      'showLogo': showLogo,
    };
  }

  factory EmailTemplate.fromJson(Map<String, dynamic> json) {
    return EmailTemplate(
      headerColor: json['headerColor'] ?? '#0066cc',
      headerText: json['headerText'] ?? 'TurboAir Quote',
      greeting: json['greeting'] ?? 'Dear {{customerName}},',
      body: json['body'] ?? 'Please find attached your TurboAir quote.',
      footer: json['footer'] ?? 'Thank you for choosing TurboAir!',
      attachmentNote: json['attachmentNote'] ?? '📎 Attachment: The detailed quote is attached.',
      showQuoteTable: json['showQuoteTable'] ?? true,
      showLogo: json['showLogo'] ?? true,
    );
  }
}

class EmailTemplateNotifier extends StateNotifier<EmailTemplate> {
  EmailTemplateNotifier() : super(const EmailTemplate()) {
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final template = EmailTemplate(
        headerColor: prefs.getString('email_header_color') ?? '#0066cc',
        headerText: prefs.getString('email_header_text') ?? 'TurboAir Quote',
        greeting: prefs.getString('email_greeting') ?? 'Dear {{customerName}},',
        body: prefs.getString('email_body') ?? state.body,
        footer: prefs.getString('email_footer') ?? 'Thank you for choosing TurboAir!',
        attachmentNote: prefs.getString('email_attachment_note') ?? state.attachmentNote,
        showQuoteTable: prefs.getBool('email_show_quote_table') ?? true,
        showLogo: prefs.getBool('email_show_logo') ?? true,
      );

      state = template;
    } catch (e) {
      AppLogger.error('Error loading email template', error: e);
    }
  }

  Future<void> saveTemplate(EmailTemplate template) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('email_header_color', template.headerColor);
      await prefs.setString('email_header_text', template.headerText);
      await prefs.setString('email_greeting', template.greeting);
      await prefs.setString('email_body', template.body);
      await prefs.setString('email_footer', template.footer);
      await prefs.setString('email_attachment_note', template.attachmentNote);
      await prefs.setBool('email_show_quote_table', template.showQuoteTable);
      await prefs.setBool('email_show_logo', template.showLogo);

      state = template;

      AppLogger.info('Email template saved successfully');
    } catch (e) {
      AppLogger.error('Error saving email template', error: e);
      rethrow;
    }
  }

  void resetToDefault() {
    state = const EmailTemplate();
  }
}

class EmailTemplateEditor extends ConsumerStatefulWidget {
  const EmailTemplateEditor({super.key});

  @override
  ConsumerState<EmailTemplateEditor> createState() => _EmailTemplateEditorState();
}

class _EmailTemplateEditorState extends ConsumerState<EmailTemplateEditor> {
  late TextEditingController _headerColorController;
  late TextEditingController _headerTextController;
  late TextEditingController _greetingController;
  late TextEditingController _bodyController;
  late TextEditingController _footerController;
  late TextEditingController _attachmentNoteController;
  bool _showQuoteTable = true;
  bool _showLogo = true;
  bool _isPreviewVisible = false;

  @override
  void initState() {
    super.initState();
    final template = ref.read(emailTemplateProvider);
    _headerColorController = TextEditingController(text: template.headerColor);
    _headerTextController = TextEditingController(text: template.headerText);
    _greetingController = TextEditingController(text: template.greeting);
    _bodyController = TextEditingController(text: template.body);
    _footerController = TextEditingController(text: template.footer);
    _attachmentNoteController = TextEditingController(text: template.attachmentNote);
    _showQuoteTable = template.showQuoteTable;
    _showLogo = template.showLogo;
  }

  @override
  void dispose() {
    _headerColorController.dispose();
    _headerTextController.dispose();
    _greetingController.dispose();
    _bodyController.dispose();
    _footerController.dispose();
    _attachmentNoteController.dispose();
    super.dispose();
  }

  // ignore: unused_element
  String _generatePreviewHtml() {
    final greeting = _greetingController.text.replaceAll('{{customerName}}', 'John Smith');
    final headerColor = _headerColorController.text;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    @media only screen and (max-width: 600px) {
      .container { width: 100% !important; padding: 10px !important; }
      .quote-table { font-size: 12px !important; }
      .header-text { font-size: 20px !important; }
    }
  </style>
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background: #f5f5f5;">
  <div class="container" style="max-width: 600px; margin: 20px auto; padding: 20px; background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
    ${_showLogo ? '<div style="text-align: center; margin-bottom: 20px;"><img src="https://taquotes.web.app/assets/assets/images/logo.png" alt="TurboAir" style="height: 60px;"></div>' : ''}
    <h2 class="header-text" style="color: $headerColor; text-align: center;">${_headerTextController.text} #Q2025-0001</h2>

    <p>$greeting</p>

    <p>${_bodyController.text}</p>

    ${_showQuoteTable ? '''
    <table class="quote-table" style="width: 100%; border-collapse: collapse; margin: 20px 0; border: 1px solid #ddd;">
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Quote Number</td>
        <td style="padding: 12px; border: 1px solid #ddd;">Q2025-0001</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Date</td>
        <td style="padding: 12px; border: 1px solid #ddd;">${DateTime.now().toString().split(' ')[0]}</td>
      </tr>
      <tr style="background-color: #f2f2f2;">
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Customer</td>
        <td style="padding: 12px; border: 1px solid #ddd;">John Smith</td>
      </tr>
      <tr>
        <td style="padding: 12px; border: 1px solid #ddd; font-weight: bold;">Total</td>
        <td style="padding: 12px; border: 1px solid #ddd;">\$5,250.00</td>
      </tr>
    </table>
    ''' : ''}

    <div style="background-color: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0;">
      <p style="margin: 0; color: #0066cc;">
        <strong>${_attachmentNoteController.text}</strong>
      </p>
    </div>

    <p>${_footerController.text}</p>

    <hr style="margin-top: 30px; border: none; border-top: 1px solid #ddd;">
    <p style="text-align: center; color: #666; font-size: 12px;">
      This is an automated email from TurboAir Quotes System
    </p>
  </div>
</body>
</html>
    ''';
  }

  Future<void> _saveTemplate() async {
    try {
      final template = EmailTemplate(
        headerColor: _headerColorController.text,
        headerText: _headerTextController.text,
        greeting: _greetingController.text,
        body: _bodyController.text,
        footer: _footerController.text,
        attachmentNote: _attachmentNoteController.text,
        showQuoteTable: _showQuoteTable,
        showLogo: _showLogo,
      );

      await ref.read(emailTemplateProvider.notifier).saveTemplate(template);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email template saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetToDefault() {
    final defaultTemplate = const EmailTemplate();
    _headerColorController.text = defaultTemplate.headerColor;
    _headerTextController.text = defaultTemplate.headerText;
    _greetingController.text = defaultTemplate.greeting;
    _bodyController.text = defaultTemplate.body;
    _footerController.text = defaultTemplate.footer;
    _attachmentNoteController.text = defaultTemplate.attachmentNote;
    setState(() {
      _showQuoteTable = defaultTemplate.showQuoteTable;
      _showLogo = defaultTemplate.showLogo;
    });
    ref.read(emailTemplateProvider.notifier).resetToDefault();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.email, color: theme.primaryColor, size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Email Template Editor',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isPreviewVisible = !_isPreviewVisible;
                    });
                  },
                  icon: Icon(_isPreviewVisible ? Icons.visibility_off : Icons.visibility),
                  label: Text(_isPreviewVisible ? 'Hide Preview' : 'Show Preview'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Customize the email template used for sending quotes to customers.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Template Editor
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Editor Section
                Expanded(
                  flex: _isPreviewVisible ? 1 : 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Settings
                      const Text(
                        'Header Settings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _headerTextController,
                        decoration: const InputDecoration(
                          labelText: 'Header Text',
                          hintText: 'e.g., TurboAir Quote',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _headerColorController,
                              decoration: InputDecoration(
                                labelText: 'Header Color (HEX)',
                                hintText: '#0066cc',
                                border: const OutlineInputBorder(),
                                suffixIcon: Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _parseColor(_headerColorController.text),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Content Settings
                      const Text(
                        'Content Settings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _greetingController,
                        decoration: const InputDecoration(
                          labelText: 'Greeting',
                          hintText: 'Dear {{customerName}},',
                          helperText: 'Use {{customerName}} for customer name placeholder',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _bodyController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Email Body',
                          hintText: 'Main message content',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _footerController,
                        decoration: const InputDecoration(
                          labelText: 'Footer Text',
                          hintText: 'Thank you message',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _attachmentNoteController,
                        decoration: const InputDecoration(
                          labelText: 'Attachment Note',
                          hintText: 'Message about PDF attachment',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Display Options
                      const Text(
                        'Display Options',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      CheckboxListTile(
                        title: const Text('Show Quote Summary Table'),
                        value: _showQuoteTable,
                        onChanged: (value) {
                          setState(() {
                            _showQuoteTable = value ?? true;
                          });
                        },
                      ),

                      CheckboxListTile(
                        title: const Text('Show Company Logo'),
                        value: _showLogo,
                        onChanged: (value) {
                          setState(() {
                            _showLogo = value ?? true;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _saveTemplate,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Template'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: _resetToDefault,
                            icon: const Icon(Icons.restore),
                            label: const Text('Reset to Default'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Preview Section
                if (_isPreviewVisible) ...[
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preview',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 600,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[100],
                          ),
                          child: SingleChildScrollView(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _buildPreview(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // Help Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This template will be used for all quote emails sent from the system. Changes are saved per user.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final greeting = _greetingController.text.replaceAll('{{customerName}}', 'John Smith');
    final headerColor = _parseColor(_headerColorController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showLogo)
          Center(
            child: Container(
              height: 60,
              width: 150,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text(
                  'LOGO',
                  style: TextStyle(color: Colors.grey, fontSize: 20),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),

        Center(
          child: Text(
            '${_headerTextController.text} #Q2025-0001',
            style: TextStyle(
              color: headerColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(greeting),
        const SizedBox(height: 16),

        Text(_bodyController.text),
        const SizedBox(height: 20),

        if (_showQuoteTable)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                _buildTableRow('Quote Number', 'Q2025-0001', isEven: true),
                _buildTableRow('Date', DateTime.now().toString().split(' ')[0], isEven: false),
                _buildTableRow('Customer', 'John Smith', isEven: true),
                _buildTableRow('Total', '\$5,250.00', isEven: false),
              ],
            ),
          ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F3FF),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            _attachmentNoteController.text,
            style: const TextStyle(color: Color(0xFF0066CC)),
          ),
        ),
        const SizedBox(height: 20),

        Text(_footerController.text),
        const SizedBox(height: 30),

        const Divider(),
        const SizedBox(height: 10),

        const Center(
          child: Text(
            'This is an automated email from TurboAir Quotes System',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(String label, String value, {required bool isEven}) {
    return Container(
      color: isEven ? Colors.grey[100] : Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
    } catch (e) {
      // Return default color on error
    }
    return const Color(0xFF0066CC);
  }
}