// lib/features/admin/services/performance_report_email_service.dart

import 'dart:typed_data';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import '../../../core/services/email_service.dart';
import '../../../core/services/app_logger.dart';
import '../../admin/presentation/screens/performance_dashboard_screen.dart';

class PerformanceReportEmailService {
  static final EmailService _emailService = EmailService();

  /// Send performance report via email with Excel attachment
  static Future<bool> sendPerformanceReport({
    required List<UserPerformanceMetrics> metrics,
    required List<String> recipientEmails,
    required String period,
    String? customPeriodText,
  }) async {
    try {
      AppLogger.info('Generating performance report email', data: {
        'recipients': recipientEmails.length,
        'period': period,
      });

      // Generate Excel report
      final excelBytes = await _generateExcelReport(metrics, period, customPeriodText);

      // Generate HTML email content
      final htmlContent = _generateEmailHtml(metrics, period, customPeriodText);

      // Create Excel attachment
      final attachment = StreamAttachment(
        Stream.value(excelBytes),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        fileName: 'Performance_Report_${_getPeriodFileName(period, customPeriodText)}.xlsx',
      );

      // Send to each recipient
      bool allSuccess = true;
      for (final recipientEmail in recipientEmails) {
        final success = await _emailService.sendQuoteEmail(
          recipientEmail: recipientEmail,
          recipientName: recipientEmail.split('@')[0],
          quoteNumber: 'PERFORMANCE_REPORT_${DateTime.now().millisecondsSinceEpoch}',
          htmlContent: htmlContent,
          userInfo: {
            'name': 'Performance Dashboard',
            'email': 'noreply@turboairmexico.com',
            'role': 'System Report',
          },
          attachments: [attachment],
        );

        if (!success) {
          allSuccess = false;
          AppLogger.error('Failed to send report to $recipientEmail');
        }
      }

      if (allSuccess) {
        AppLogger.info('Performance report sent successfully', data: {
          'recipients': recipientEmails.length,
        });
      }

      return allSuccess;
    } catch (e, stackTrace) {
      AppLogger.error('Error sending performance report',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Generate Excel report bytes
  static Future<Uint8List> _generateExcelReport(
    List<UserPerformanceMetrics> metrics,
    String period,
    String? customPeriodText,
  ) async {
    final excel = excel_pkg.Excel.createExcel();
    excel.delete('Sheet1');

    // Create Overview Sheet
    _createOverviewSheet(excel, metrics, period, customPeriodText);

    // Create User Details Sheet
    _createUserDetailsSheet(excel, metrics);

    // Create Analytics Sheet
    _createAnalyticsSheet(excel, metrics);

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file');
    }

    return Uint8List.fromList(bytes);
  }

  /// Generate HTML email content
  static String _generateEmailHtml(
    List<UserPerformanceMetrics> metrics,
    String period,
    String? customPeriodText,
  ) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final numberFormat = NumberFormat('#,###');

    // Calculate totals
    final totalRevenue = metrics.fold(0.0, (sum, m) => sum + m.totalRevenue);
    final totalQuotes = metrics.fold(0, (sum, m) => sum + m.totalQuotes);
    final totalClients = metrics.fold(0, (sum, m) => sum + m.totalClients);
    final avgConversion = metrics.isEmpty
        ? 0.0
        : metrics.fold(0.0, (sum, m) => sum + m.conversionRate) / metrics.length;

    // Get top performers
    final topByRevenue = [...metrics]
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    final periodDisplay = customPeriodText ?? _getPeriodDisplay(period);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #0066cc 0%, #004999 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background: #fff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; }
    .kpi-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; margin: 20px 0; }
    .kpi-card { background: #f5f5f5; padding: 15px; border-radius: 8px; text-align: center; }
    .kpi-value { font-size: 24px; font-weight: bold; color: #0066cc; margin: 5px 0; }
    .kpi-label { font-size: 12px; color: #666; text-transform: uppercase; }
    .top-performers { margin: 20px 0; }
    .performer { background: #f9f9f9; padding: 12px; margin: 8px 0; border-radius: 4px; display: flex; justify-content: space-between; align-items: center; }
    .rank { background: #0066cc; color: white; width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; border-top: 1px solid #e0e0e0; }
    .attachment-note { background: #e7f3ff; border-left: 4px solid #0066cc; padding: 15px; margin: 20px 0; border-radius: 4px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0;">📊 Performance Dashboard Report</h1>
      <p style="margin: 10px 0 0 0; opacity: 0.9;">$periodDisplay</p>
      <p style="margin: 5px 0 0 0; font-size: 14px;">Generated on ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}</p>
    </div>

    <div class="content">
      <h2 style="color: #0066cc; margin-top: 0;">Company Performance Overview</h2>

      <div class="kpi-grid">
        <div class="kpi-card">
          <div class="kpi-label">Total Revenue</div>
          <div class="kpi-value">${currencyFormat.format(totalRevenue)}</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-label">Total Quotes</div>
          <div class="kpi-value">${numberFormat.format(totalQuotes)}</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-label">Total Clients</div>
          <div class="kpi-value">${numberFormat.format(totalClients)}</div>
        </div>
        <div class="kpi-card">
          <div class="kpi-label">Avg Conversion</div>
          <div class="kpi-value">${avgConversion.toStringAsFixed(1)}%</div>
        </div>
      </div>

      <h3 style="color: #0066cc; margin-top: 30px;">🏆 Top 5 Performers</h3>
      <div class="top-performers">
        ${topByRevenue.take(5).toList().asMap().entries.map((entry) {
      final index = entry.key;
      final user = entry.value;
      return '''
        <div class="performer">
          <div style="display: flex; align-items: center; gap: 15px;">
            <div class="rank">${index + 1}</div>
            <div>
              <div style="font-weight: bold;">${user.displayName}</div>
              <div style="font-size: 12px; color: #666;">${user.email}</div>
            </div>
          </div>
          <div style="text-align: right;">
            <div style="font-weight: bold; color: #0066cc;">${currencyFormat.format(user.totalRevenue)}</div>
            <div style="font-size: 12px; color: #666;">${user.totalQuotes} quotes</div>
          </div>
        </div>
      ''';
    }).join()}
      </div>

      <div class="attachment-note">
        <strong>📎 Detailed Report Attached</strong>
        <p style="margin: 8px 0 0 0;">The attached Excel file contains comprehensive performance data including:</p>
        <ul style="margin: 8px 0 0 0; padding-left: 20px;">
          <li>Complete user performance metrics</li>
          <li>Revenue breakdown by category</li>
          <li>Top products sold</li>
          <li>Detailed analytics and trends</li>
        </ul>
      </div>

      <p style="margin-top: 30px;">
        This automated report provides insights into team performance and helps identify trends and opportunities for improvement.
      </p>
    </div>

    <div class="footer">
      <p>This is an automated report from the TurboAir Quotes Performance Dashboard</p>
      <p>© ${DateTime.now().year} TurboAir Mexico. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  static String _getPeriodDisplay(String period) {
    switch (period) {
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      case 'quarter':
        return 'This Quarter';
      case 'year':
        return 'This Year';
      case 'all':
        return 'All Time';
      default:
        return period;
    }
  }

  static String _getPeriodFileName(String period, String? customPeriodText) {
    if (customPeriodText != null) {
      return customPeriodText.replaceAll(' ', '_').replaceAll(',', '');
    }
    return _getPeriodDisplay(period).replaceAll(' ', '_');
  }

  // Excel sheet creation methods (reused from performance_dashboard_screen.dart)
  static void _createOverviewSheet(
    excel_pkg.Excel excel,
    List<UserPerformanceMetrics> metrics,
    String period,
    String? customPeriodText,
  ) {
    final sheet = excel['Overview'];
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final numberFormat = NumberFormat('#,###');

    final totalRevenue = metrics.fold(0.0, (sum, m) => sum + m.totalRevenue);
    final totalQuotes = metrics.fold(0, (sum, m) => sum + m.totalQuotes);
    final totalClients = metrics.fold(0, (sum, m) => sum + m.totalClients);
    final avgConversion = metrics.isEmpty
        ? 0.0
        : metrics.fold(0.0, (sum, m) => sum + m.conversionRate) / metrics.length;

    int row = 0;

    // Title
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue('PERFORMANCE DASHBOARD - OVERVIEW')
      ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 16);
    row += 2;

    // Period
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue('Period:')
      ..cellStyle = excel_pkg.CellStyle(bold: true);
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
        excel_pkg.TextCellValue(customPeriodText ?? _getPeriodDisplay(period));
    row += 1;

    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue('Generated:')
      ..cellStyle = excel_pkg.CellStyle(bold: true);
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
        excel_pkg.TextCellValue(DateFormat('MMMM dd, yyyy HH:mm').format(DateTime.now()));
    row += 2;

    // Company KPIs
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue('COMPANY PERFORMANCE')
      ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 14);
    row += 1;

    final kpiData = [
      ['Total Revenue', currencyFormat.format(totalRevenue)],
      ['Total Quotes', numberFormat.format(totalQuotes)],
      ['Total Clients', numberFormat.format(totalClients)],
      ['Average Conversion Rate', '${avgConversion.toStringAsFixed(1)}%'],
    ];

    for (final kpi in kpiData) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = excel_pkg.TextCellValue(kpi[0])
        ..cellStyle = excel_pkg.CellStyle(bold: true);
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          excel_pkg.TextCellValue(kpi[1]);
      row++;
    }

    row += 2;

    // Top Performers
    final topByRevenue = [...metrics]
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue('TOP PERFORMERS')
      ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 14);
    row += 1;

    final headers = ['Rank', 'Name', 'Email', 'Revenue', 'Quotes', 'Conversion Rate'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row))
        ..value = excel_pkg.TextCellValue(headers[i])
        ..cellStyle = excel_pkg.CellStyle(
            bold: true,
            backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
    }
    row++;

    for (int i = 0; i < 10 && i < topByRevenue.length; i++) {
      final user = topByRevenue[i];
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          excel_pkg.IntCellValue(i + 1);
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          excel_pkg.TextCellValue(user.displayName);
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          excel_pkg.TextCellValue(user.email);
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          excel_pkg.TextCellValue(currencyFormat.format(user.totalRevenue));
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          excel_pkg.IntCellValue(user.totalQuotes);
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          excel_pkg.TextCellValue('${user.conversionRate.toStringAsFixed(1)}%');
      row++;
    }

    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20);
    }
  }

  static void _createUserDetailsSheet(
      excel_pkg.Excel excel, List<UserPerformanceMetrics> metrics) {
    final sheet = excel['User Details'];
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final numberFormat = NumberFormat('#,###');

    final headers = [
      'User Name',
      'Email',
      'Total Revenue',
      'Total Quotes',
      'Accepted',
      'Pending',
      'Rejected',
      'Conversion Rate',
      'Avg Quote Value',
      'Total Clients',
      'New Clients This Month',
      'Quotes This Week',
      'Quotes This Month',
      'Revenue This Month',
      'Avg Response Time (hrs)',
      'Total Products Sold',
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = excel_pkg.TextCellValue(headers[i])
        ..cellStyle = excel_pkg.CellStyle(
          bold: true,
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#4CAF50'),
          fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
        );
    }

    for (int rowIndex = 0; rowIndex < metrics.length; rowIndex++) {
      final user = metrics[rowIndex];
      final row = rowIndex + 1;

      final rowData = [
        user.displayName,
        user.email,
        currencyFormat.format(user.totalRevenue),
        numberFormat.format(user.totalQuotes),
        numberFormat.format(user.acceptedQuotes),
        numberFormat.format(user.pendingQuotes),
        numberFormat.format(user.rejectedQuotes),
        '${user.conversionRate.toStringAsFixed(1)}%',
        currencyFormat.format(user.averageQuoteValue),
        numberFormat.format(user.totalClients),
        numberFormat.format(user.newClientsThisMonth),
        numberFormat.format(user.quotesThisWeek),
        numberFormat.format(user.quotesThisMonth),
        currencyFormat.format(user.revenueThisMonth),
        user.averageResponseTime.toStringAsFixed(1),
        numberFormat.format(user.totalProducts),
      ];

      for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: row))
            .value = excel_pkg.TextCellValue(rowData[colIndex]);
      }
    }

    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20);
    }
  }

  static void _createAnalyticsSheet(
      excel_pkg.Excel excel, List<UserPerformanceMetrics> metrics) {
    final sheet = excel['Analytics'];
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    int row = 0;

    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue('ANALYTICS SUMMARY')
      ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 16);
    row += 2;

    // Category Revenue
    final Map<String, double> categoryRevenue = {};
    for (final user in metrics) {
      user.categoryRevenue.forEach((category, revenue) {
        categoryRevenue[category] = (categoryRevenue[category] ?? 0) + revenue;
      });
    }

    if (categoryRevenue.isNotEmpty) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = excel_pkg.TextCellValue('REVENUE BY CATEGORY')
        ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 14);
      row += 1;

      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Category')
        ..cellStyle = excel_pkg.CellStyle(
            bold: true,
            backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Revenue')
        ..cellStyle = excel_pkg.CellStyle(
            bold: true,
            backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Percentage')
        ..cellStyle = excel_pkg.CellStyle(
            bold: true,
            backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      row++;

      final totalRevenue = categoryRevenue.values.fold(0.0, (sum, val) => sum + val);
      final sortedCategories = categoryRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedCategories) {
        final percentage = (entry.value / totalRevenue * 100).toStringAsFixed(1);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
            excel_pkg.TextCellValue(entry.key);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
            excel_pkg.TextCellValue(currencyFormat.format(entry.value));
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
            excel_pkg.TextCellValue('$percentage%');
        row++;
      }

      row += 2;
    }

    // Top Products
    final Map<String, int> productsSold = {};
    for (final user in metrics) {
      user.productsSold.forEach((product, quantity) {
        productsSold[product] = (productsSold[product] ?? 0) + quantity;
      });
    }

    if (productsSold.isNotEmpty) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = excel_pkg.TextCellValue('TOP PRODUCTS SOLD')
        ..cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 14);
      row += 1;

      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Rank')
        ..cellStyle = excel_pkg.CellStyle(
            bold: true,
            backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Product')
        ..cellStyle = excel_pkg.CellStyle(
            bold: true,
            backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        ..value = excel_pkg.TextCellValue('Units Sold')
        ..cellStyle = excel_pkg.CellStyle(
            bold: true,
            backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#E0E0E0'));
      row++;

      final sortedProducts = productsSold.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < sortedProducts.length && i < 20; i++) {
        final entry = sortedProducts[i];
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
            excel_pkg.IntCellValue(i + 1);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
            excel_pkg.TextCellValue(entry.key);
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
            excel_pkg.IntCellValue(entry.value);
        row++;
      }
    }

    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 20);
  }
}
