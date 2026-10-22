import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class SummaryReportGenerator {
  static Future<String> generate({
    required Map<String, dynamic> templateData,
    required String periodFrom,
    required String periodTo,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Collection Summary'];
    excel.delete('Sheet1');

    // Title
    sheet.appendRow([
      TextCellValue('የ4ቱ ዘርፎች ተሰብሳቢ ሂሳብ ዕቅድና የዕቅድ አፈፃፃፀም ሪፖርት'),
    ]);
    sheet.appendRow([
      TextCellValue(
        'ከሃምሌ 1 እስከ $periodTo በ4 ዘርፎች የተሰበሰበ ገንዘብ መጠን',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // Headers
    final headers = [
      'ተ.ቁ',
      'ዝርዝር መግለጫ',
      'Requested (from Jul 1)',
      'Week plan',
      'Week collected',
      'YTD plan',
      'YTD collected',
      'Remaining',
      '% total recv',
      'Week plan %',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (var c = 0; c < headers.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3))
          .cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#B8D4E8'),
      );
    }

    // Sectors from Senior Accountant payload
    final sections = (templateData['summary_sections'] as List?) ?? [];
    var no = 1;

    for (final section in sections) {
      final map = Map<String, dynamic>.from(section as Map);
      final sectorName = map['sector_name']?.toString() ?? 'Sector';
      final rows = (map['rows'] as List?) ?? [];

      sheet.appendRow([
        IntCellValue(no),
        TextCellValue(sectorName),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ]);
      no++;

      for (final row in rows) {
        final r = Map<String, dynamic>.from(row as Map);
        sheet.appendRow([
          TextCellValue(''),
          TextCellValue(r['label']?.toString() ?? ''),
          DoubleCellValue(_n(r['requested'])),
          DoubleCellValue(_n(r['week_plan'])),
          DoubleCellValue(_n(r['week_collected'])),
          DoubleCellValue(_n(r['ytd_plan'])),
          DoubleCellValue(_n(r['ytd_collected'])),
          DoubleCellValue(_n(r['remaining'])),
          DoubleCellValue(_n(r['percent_total_receivable'])),
          DoubleCellValue(_n(r['week_plan_percent'])),
        ]);
      }
    }

    // Consultancy total
    final consultancy = templateData['consultancy_sectors_total'];
    if (consultancy is Map) {
      final m = Map<String, dynamic>.from(consultancy);
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue(m['label']?.toString() ?? 'Consultancy Sectors Total'),
        DoubleCellValue(_n(m['requested'])),
        DoubleCellValue(_n(m['week_plan'])),
        DoubleCellValue(_n(m['week_collected'])),
        DoubleCellValue(_n(m['ytd_plan'])),
        DoubleCellValue(_n(m['ytd_collected'])),
        DoubleCellValue(_n(m['remaining'])),
        DoubleCellValue(_n(m['percent_total_receivable'])),
        DoubleCellValue(_n(m['week_plan_percent'])),
      ]);
    }

    // All sectors + grand total
    final all = (templateData['all_sectors_summary'] as List?) ?? [];
    if (all.isNotEmpty) {
      sheet.appendRow([
        IntCellValue(5),
        TextCellValue("All Sectors' Receivables and Collection Summary"),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ]);
      for (final row in all) {
        final r = Map<String, dynamic>.from(row as Map);
        sheet.appendRow([
          TextCellValue(''),
          TextCellValue(r['label']?.toString() ?? ''),
          DoubleCellValue(_n(r['requested'])),
          DoubleCellValue(_n(r['week_plan'])),
          DoubleCellValue(_n(r['week_collected'])),
          DoubleCellValue(_n(r['ytd_plan'])),
          DoubleCellValue(_n(r['ytd_collected'])),
          DoubleCellValue(_n(r['remaining'])),
          DoubleCellValue(_n(r['percent_total_receivable'])),
          DoubleCellValue(_n(r['week_plan_percent'])),
        ]);
      }
    }

    // Notes
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('ማስታወሻ')]);
    sheet.appendRow([
      TextCellValue(
        'Ø የ4ቱ ዘርፎች የተሰብሳቢ ሂሳብ ዕቅድ አፈፃፀም ከጠቅላላ ተሰብሳቢ ሂሳብ አንፃር እንደተሰበሰበ መረዳት ይቻላል።',
      ),
    ]);

    sheet.setColumnWidth(0, 8);
    sheet.setColumnWidth(1, 48);
    for (var i = 2; i < 10; i++) {
      sheet.setColumnWidth(i, 15);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel');

    final dir = await getTemporaryDirectory();
    final name =
        '4_Sectors_${periodFrom}_to_${periodTo}_Collection_summary_Report.xlsx';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static double _n(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }
}