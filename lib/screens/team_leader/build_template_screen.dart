import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/collection_data.dart';
import '../../models/workflow_report.dart';
import '../../services/workflow_report_service.dart';
import '../../widgets/role_scaffold.dart';

class BuildTemplateScreen extends StatefulWidget {
  final List<CollectionData> collections;
  final WorkflowReport? workflowReport;
  final String stage;

  const BuildTemplateScreen({
    super.key,
    required this.collections,
    this.workflowReport,
    required this.stage,
  });

  @override
  State<BuildTemplateScreen> createState() => _BuildTemplateScreenState();
}

class _BuildTemplateScreenState extends State<BuildTemplateScreen> {
  static const Color _primary = Color(0xFF0D7377);

  final _reportNameCtrl = TextEditingController();
  final _referenceNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String _voucherType = 'Milestone';

  String? _filePath;
  String? _fileName;

  bool _generating = false;
  bool _sending = false;
  bool _rejecting = false;

  final _dateFormat = DateFormat('MM/dd/yyyy');
  final _numberFormat = NumberFormat('#,##0.00');

  final List<String> _sectorOrder = const [
    'Transport Sector',
    'Water and Energy Sector',
    'Building and Urban Sector',
    'Construction Sector',
  ];

  final Map<String, _SectorSummary> _sectors = {};

  @override
  void initState() {
    super.initState();
    _aggregateCollectorReports();
  }

  @override
  void dispose() {
    _reportNameCtrl.dispose();
    _referenceNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _aggregateCollectorReports() {
    for (final sectorName in _sectorOrder) {
      _sectors[sectorName] = _SectorSummary(name: sectorName);
    }

    if (widget.collections.isEmpty) {
      _reportNameCtrl.text = 'Receivables and Collection Report';
      return;
    }

    final first = widget.collections.first;
    _startDate = first.periodFrom;
    _endDate = first.periodTo;

    final periodLabel = first.period.trim().isNotEmpty
        ? first.period
        : DateFormat('MMM yyyy').format(DateTime.now());

    _reportNameCtrl.text = 'Receivables and Collection Report — $periodLabel';

    for (final collection in widget.collections) {
      try {
        final sectorName = _resolveSectorName(collection.sectorName);
        _sectors.putIfAbsent(sectorName, () => _SectorSummary(name: sectorName));
        final sector = _sectors[sectorName]!;
        final raw = collection.rows;

        if (raw == null || raw is! Map) continue;

        final payload = Map<String, dynamic>.from(raw as Map);

        final reportName = payload['report_name']?.toString().trim();
        if (_referenceNumberCtrl.text.isEmpty && payload['reference_number'] != null) {
          _referenceNumberCtrl.text = payload['reference_number'].toString();
        }
        if (reportName != null && reportName.isNotEmpty &&
            _reportNameCtrl.text.contains('Receivables and Collection Report')) {
          _reportNameCtrl.text = reportName;
        }

        final voucherType = payload['voucher_type']?.toString();
        if (voucherType != null &&
            ['Milestone', 'Percentage', 'IPC', 'Lump Sum'].contains(voucherType)) {
          _voucherType = voucherType;
        }

        final submittedRows = payload['rows'];
        if (submittedRows is! Map) continue;

        final rowMap = Map<String, dynamic>.from(submittedRows as Map);

        sector.currentPeriod.addFrom(_mapValue(rowMap['current_period']));
        sector.advancePayment.addFrom(_mapValue(rowMap['advance_current_year']));
        sector.advancePayment.addFrom(_mapValue(rowMap['advance_previous_year']));
        sector.previousYears.addFrom(_mapValue(rowMap['previous_years']));
      } catch (e) {
        debugPrint('Skipping broken collection: $e');
      }
    }
  }

  String _resolveSectorName(String? sourceName) {
    final normalized = (sourceName ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'\s+'), ' ');

    if (normalized.contains('transport')) return 'Transport Sector';
    if (normalized.contains('water') || normalized.contains('energy')) {
      return 'Water and Energy Sector';
    }
    if (normalized.contains('building') || normalized.contains('urban')) {
      return 'Building and Urban Sector';
    }
    if (normalized.contains('construction')) return 'Construction Sector';

    return sourceName == null || sourceName.trim().isEmpty
        ? 'Other Sector'
        : sourceName.trim();
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  bool _isConsultancySector(String sectorName) {
    return sectorName == 'Transport Sector' ||
        sectorName == 'Water and Energy Sector' ||
        sectorName == 'Building and Urban Sector';
  }

  _Totals _consultancyTotal() {
    final total = _Totals();
    for (final sector in _sectors.values) {
      if (_isConsultancySector(sector.name)) {
        total.add(sector.currentPeriod);
        total.add(sector.previousYears);
      }
    }
    return total;
  }

  _Totals _allCurrentPeriod() {
    final total = _Totals();
    for (final sector in _sectors.values) {
      total.add(sector.currentPeriod);
    }
    return total;
  }

  _Totals _allAdvancePayment() {
    final total = _Totals();
    for (final sector in _sectors.values) {
      total.add(sector.advancePayment);
    }
    return total;
  }

  _Totals _allPreviousYears() {
    final total = _Totals();
    for (final sector in _sectors.values) {
      total.add(sector.previousYears);
    }
    return total;
  }

  _Totals _grandTotal() {
    final total = _Totals();
    total.add(_allCurrentPeriod());
    total.add(_allAdvancePayment());
    total.add(_allPreviousYears());
    return total;
  }

  double _percentOfTotalReceivable(_Totals row, _Totals grandTotal) {
    if (grandTotal.requested == 0) return 0;
    return row.ytdCollected / row.requested; // matches official formula
  }

  double _weekPlanPercent(_Totals row) {
    if (row.weekPlan == 0) return 0;
    return row.weekCollected / row.weekPlan; // matches official formula
  }

  // ────────────────────────────────────────────────
  // OFFICIAL 4-SECTORS EXCEL GENERATOR
  // ────────────────────────────────────────────────
  Future<String?> _generateOfficial4SectorsExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['4 Sectors Summary'];
    excel.delete('Sheet1');

    // Styles
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString('FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('0D7377'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString('FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('0D7377'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sectionStyle = CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: ExcelColor.fromHexString('B2DFDB'),
    );
    final totalStyle = CellStyle(
      bold: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('E0F2F1'),
    );
    final grandStyle = CellStyle(
      bold: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('80CBC4'),
    );
    final consultancyStyle = CellStyle(
      bold: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('B2EBF2'),
    );
    final noteStyle = CellStyle(
      italic: true,
      fontSize: 9,
      backgroundColorHex: ExcelColor.fromHexString('FFF8E1'),
    );

    // Title
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('J1'));
    sheet.cell(CellIndex.indexByString('A1')).value =
        TextCellValue('የ4ቱ  ዘርፎች ተሰብሳቢ ሂሳብ ዕቅድና የዕቅድ አፈፃፃፀም ሪፖርት');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;

    final periodText = _startDate != null && _endDate != null
        ? 'ከሃምሌ 1/2026 እስከ ነሃሴ 11/2026'
        : 'ከሃምሌ 1/2026 እስከ ነሃሴ 11/2026';

    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('J2'));
    sheet.cell(CellIndex.indexByString('A2')).value =
        TextCellValue('$periodText በ4 ዘርፎች የተሰበሰበ ገንዘብ  መጠን');
    sheet.cell(CellIndex.indexByString('A2')).cellStyle = titleStyle;

    // Headers
    final headers = [
      'ተ.ቁ',
      'ዝርዝር መግለጫ',
      'ከደንበኛው ከሃምሌ 1፣2026 ጀምሮ የሚፈለግ ሂሳብ',
      'ከነሃሴ 5/2026 እስከ ነሃሴ 11/2026 የተሰብሳቢ ሂሳብ ዕቅድ',
      'ከነሃሴ 5/2026 እስከ ነሃሴ 11/2026 የተሰበሰበ ገንዘብ  መጠን (ብር)',
      'ከሃምሌ 1/2026 እስከ  ነሃሴ 11/2026በእቅድ የተያዘ መጠን  (ብር)',
      'ከሃምሌ 1/2026 እስከ  ነሃሴ 11/2026 የተሰበሰበ መጠን  (ብር)',
      'ከተጠየቀው የክፍያ መጠን (በብር) ያልተሰበሰበ ቀሪ',
      'የዕቅድ አፈፃፀም ከጠቅላላ ተሰብሳቢ ሂሳብ አንፃር',
      'የሳምንቱ የዕቅድ አፈፃፀም (ከነሃሴ 5/2026 እስከ ነሃሴ 11/2026)',
    ];

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    void writeRow(int row, List<dynamic> values, {CellStyle? style}) {
      for (var i = 0; i < values.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
        final v = values[i];
        if (v == null) {
          cell.value = TextCellValue('');
        } else if (v is num) {
          cell.value = DoubleCellValue(v.toDouble());
        } else {
          cell.value = TextCellValue(v.toString());
        }
        if (style != null) cell.cellStyle = style;
      }
    }

    // Get real totals
    final transport = _sectors['Transport Sector']!;
    final water = _sectors['Water and Energy Sector']!;
    final building = _sectors['Building and Urban Sector']!;
    final construction = _sectors['Construction Sector']!;

    final tCur = transport.currentPeriod;
    final tPrev = transport.previousYears;
    final tTotal = _Totals()..add(tCur)..add(tPrev);

    final wCur = water.currentPeriod;
    final wPrev = water.previousYears;
    final wTotal = _Totals()..add(wCur)..add(wPrev);

    final bCur = building.currentPeriod;
    final bPrev = building.previousYears;
    final bTotal = _Totals()..add(bCur)..add(bPrev);

    final cCur = construction.currentPeriod;
    final cAdv = construction.advancePayment;
    final cPrev = construction.previousYears;
    final cTotal = _Totals()..add(cCur)..add(cAdv)..add(cPrev);

    final consTotal = _consultancyTotal();
    final grand = _grandTotal();

    int r = 3;

    // 1. Transport
    writeRow(r++, ['1', 'Transport Sector', '', '', '', '', '', '', '', ''], style: sectionStyle);
    writeRow(r++, ['', 'Current Period Receivables  total July 1/2026    -  to date', tCur.requested, tCur.weekPlan, tCur.weekCollected, tCur.ytdPlan, tCur.ytdCollected, tCur.remaining, _percentOfTotalReceivable(tCur, grand), _weekPlanPercent(tCur)]);
    writeRow(r++, ['', 'Previous Years Receivables Sub Total before July 1, 2026', tPrev.requested, tPrev.weekPlan, tPrev.weekCollected, tPrev.ytdPlan, tPrev.ytdCollected, tPrev.remaining, _percentOfTotalReceivable(tPrev, grand), _weekPlanPercent(tPrev)]);
    writeRow(r++, ['', 'Sub Total', tTotal.requested, tTotal.weekPlan, tTotal.weekCollected, tTotal.ytdPlan, tTotal.ytdCollected, tTotal.remaining, _percentOfTotalReceivable(tTotal, grand), _weekPlanPercent(tTotal)], style: totalStyle);

    // 2. Water
    writeRow(r++, ['2', 'Water and Energy Sector', '', '', '', '', '', '', '', ''], style: sectionStyle);
    writeRow(r++, ['', 'Current Period Receivables  total July 1/2026    -  to date', wCur.requested, wCur.weekPlan, wCur.weekCollected, wCur.ytdPlan, wCur.ytdCollected, wCur.remaining, _percentOfTotalReceivable(wCur, grand), _weekPlanPercent(wCur)]);
    writeRow(r++, ['', 'Previous Years Receivables Sub Total before July 1, 2026', wPrev.requested, wPrev.weekPlan, wPrev.weekCollected, wPrev.ytdPlan, wPrev.ytdCollected, wPrev.remaining, _percentOfTotalReceivable(wPrev, grand), _weekPlanPercent(wPrev)]);
    writeRow(r++, ['', 'Sub Total', wTotal.requested, wTotal.weekPlan, wTotal.weekCollected, wTotal.ytdPlan, wTotal.ytdCollected, wTotal.remaining, _percentOfTotalReceivable(wTotal, grand), _weekPlanPercent(wTotal)], style: totalStyle);

    // 3. Building
    writeRow(r++, ['3', 'Building and Urban Sector', '', '', '', '', '', '', '', ''], style: sectionStyle);
    writeRow(r++, ['', 'Current Period Receivables  total July 1/2026    -  to date', bCur.requested, bCur.weekPlan, bCur.weekCollected, bCur.ytdPlan, bCur.ytdCollected, bCur.remaining, _percentOfTotalReceivable(bCur, grand), _weekPlanPercent(bCur)]);
    writeRow(r++, ['', 'Previous Years Receivables Sub Total before July 1, 2026', bPrev.requested, bPrev.weekPlan, bPrev.weekCollected, bPrev.ytdPlan, bPrev.ytdCollected, bPrev.remaining, _percentOfTotalReceivable(bPrev, grand), _weekPlanPercent(bPrev)]);
    writeRow(r++, ['', 'Sub Total', bTotal.requested, bTotal.weekPlan, bTotal.weekCollected, bTotal.ytdPlan, bTotal.ytdCollected, bTotal.remaining, _percentOfTotalReceivable(bTotal, grand), _weekPlanPercent(bTotal)], style: totalStyle);

    // Consultancy
    final consCur = _Totals()..add(tCur)..add(wCur)..add(bCur);
    final consPrev = _Totals()..add(tPrev)..add(wPrev)..add(bPrev);
    writeRow(r++, ['', 'Current Period Receivables  total July 1/2026    -  to date', consCur.requested, consCur.weekPlan, consCur.weekCollected, consCur.ytdPlan, consCur.ytdCollected, consCur.remaining, _percentOfTotalReceivable(consCur, grand), _weekPlanPercent(consCur)], style: consultancyStyle);
    writeRow(r++, ['', 'Previous Years Receivables Sub Total before July 1, 2026', consPrev.requested, consPrev.weekPlan, consPrev.weekCollected, consPrev.ytdPlan, consPrev.ytdCollected, consPrev.remaining, _percentOfTotalReceivable(consPrev, grand), _weekPlanPercent(consPrev)], style: consultancyStyle);
    writeRow(r++, ['', 'Consultancy Sectors  Total', consTotal.requested, consTotal.weekPlan, consTotal.weekCollected, consTotal.ytdPlan, consTotal.ytdCollected, consTotal.remaining, _percentOfTotalReceivable(consTotal, grand), _weekPlanPercent(consTotal)], style: consultancyStyle);

    // 4. Construction
    writeRow(r++, ['4', 'Construction Sector', '', '', '', '', '', '', '', ''], style: sectionStyle);
    writeRow(r++, ['', 'Current Period Receivables  total July 1/2026    -  to date', cCur.requested, cCur.weekPlan, cCur.weekCollected, cCur.ytdPlan, cCur.ytdCollected, cCur.remaining, _percentOfTotalReceivable(cCur, grand), _weekPlanPercent(cCur)]);
    writeRow(r++, ['', 'Advance payment Received', cAdv.requested, cAdv.weekPlan, cAdv.weekCollected, cAdv.ytdPlan, cAdv.ytdCollected, cAdv.remaining, cAdv.requested > 0 ? 1.0 : 0, null]);
    writeRow(r++, ['', 'Previous Years Receivables Sub Total before July 1, 2026', cPrev.requested, cPrev.weekPlan, cPrev.weekCollected, cPrev.ytdPlan, cPrev.ytdCollected, cPrev.remaining, _percentOfTotalReceivable(cPrev, grand), _weekPlanPercent(cPrev)]);
    writeRow(r++, ['', 'Construction Sector Total', cTotal.requested, cTotal.weekPlan, cTotal.weekCollected, cTotal.ytdPlan, cTotal.ytdCollected, cTotal.remaining, _percentOfTotalReceivable(cTotal, grand), _weekPlanPercent(cTotal)], style: totalStyle);

    // 5. Grand Total
    writeRow(r++, ['5', "All Sectors' Recivables and Collection Summary", '', '', '', '', '', '', '', ''], style: sectionStyle);
    final allCur = _allCurrentPeriod();
    final allAdv = _allAdvancePayment();
    final allPrev = _allPreviousYears();
    writeRow(r++, ['', 'Current Period Receivables  total July 1/2026    -  to date', allCur.requested, allCur.weekPlan, allCur.weekCollected, allCur.ytdPlan, allCur.ytdCollected, allCur.remaining, _percentOfTotalReceivable(allCur, grand), _weekPlanPercent(allCur)]);
    writeRow(r++, ['', 'Advance payment Received', allAdv.requested, allAdv.weekPlan, allAdv.weekCollected, allAdv.ytdPlan, allAdv.ytdCollected, allAdv.remaining, allAdv.requested > 0 ? 1.0 : 0, null]);
    writeRow(r++, ['', 'Previous Years Receivables Sub Total before July 1, 2026', allPrev.requested, allPrev.weekPlan, allPrev.weekCollected, allPrev.ytdPlan, allPrev.ytdCollected, allPrev.remaining, _percentOfTotalReceivable(allPrev, grand), _weekPlanPercent(allPrev)]);
    writeRow(r++, ['', 'Grande Total of the 4 Sectors Receivables& Collection', grand.requested, grand.weekPlan, grand.weekCollected, grand.ytdPlan, grand.ytdCollected, grand.remaining, _percentOfTotalReceivable(grand, grand), _weekPlanPercent(grand)], style: grandStyle);

    // Notes
    r += 1;
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
        CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: r));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value =
        TextCellValue('ማስታወሻ');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).cellStyle = noteStyle;

    r += 1;
    final overallPct = (grand.ytdCollected / (grand.requested == 0 ? 1 : grand.requested) * 100).toStringAsFixed(0);
    final weekPct = (grand.weekCollected / (grand.weekPlan == 0 ? 1 : grand.weekPlan) * 100).toStringAsFixed(0);

    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
        CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: r));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value = TextCellValue(
        'Ø  የ4ቱ ዘርፎች የተሰብሳቢ ሂሳብ ዕቅድ አፈፃፀም  ከጠቅላላ ተሰብሳቢ ሂሳብ  አንፃር  $overallPct % እንደተሰበሰበ፤እንዲሁም  ከነሃሴ 5/2026 እስከ ነሃሴ 11/2026 ለሳምንቱ በእቅድ ከተያዘ መጠን  አንፃር  ደግሞ $weekPct % እንደተሰበሰበ መረዳት ይቻላል።');

    r += 1;
    final remainingBillion = (grand.remaining / 1000000000).toStringAsFixed(1);
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
        CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: r));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value = TextCellValue(
        'Ø  በዚህ ሪፖርት ነሃሴ 11/2026 ላይ ከቀደሙ አመታት እና ከዘንድሮ ሂሳብ ያልተሰበሰበ ቀሪ ብር $remainingBillion ቢሊዮን ብር በላይ እንዳለ ያሳያል። ይህን ሂሳብ በፍጥነት ለመሰብሰብ ዕቅድ አውጥቶ ከፍተኛ ርብርብ ማድረግ ይጠበቅብናል።');

    // Column widths
    final widths = [6.0, 55.0, 16.0, 16.0, 16.0, 16.0, 16.0, 16.0, 12.0, 12.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }

    final bytes = excel.encode();
    if (bytes == null) return null;

    final fileName =
        '4_Sectors_Summary_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );

    return fileName;
  }

  // ────────────────────────────────────────────────
  // TEAM LEADER APPROVE → GENERATE → SEND
  // ────────────────────────────────────────────────
  Future<void> _teamLeaderApprove() async {
    final workflowReportId = widget.workflowReport?.id;

    if (workflowReportId == null) {
      Get.snackbar('Error', 'Workflow report ID is missing.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _sending = true);

    try {
      // 1. Approve
      final approvalResult = await WorkflowReportService.teamLeaderAction(
        workflowReportId: workflowReportId,
        action: 'approved',
        remark: null,
      );

      if (approvalResult['success'] != true) {
        throw Exception(approvalResult['message'] ?? 'Team Leader approval failed.');
      }

      // 2. Generate the official Excel
      final generated = await _generateOfficial4SectorsExcel();

      // 3. Send to Management + Finance
      final sendResult = await WorkflowReportService.sendToManagementAndFinance(
        workflowReportId: workflowReportId,
        summaryFilePath: generated,
      );

      if (!mounted) return;

      if (sendResult['success'] == true) {
        Get.snackbar(
          'Approved and sent',
          'Official 4-Sectors Summary generated and sent to Management & Finance.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText: Colors.white,
        );
        Get.back(result: true);
      } else {
        Get.snackbar(
          'Partially completed',
          'Report approved and Excel generated, but sending failed. Please retry.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(
        'Error',
        'Could not approve and send: $error',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ────────────────────────────────────────────────
  // The rest of the original methods (Reject, Management, UI…)
  // stay exactly the same as before.
  // I keep them short here for readability.
  // ────────────────────────────────────────────────

  Future<void> _teamLeaderReject() async {
    final remark = await _askForRemark(
      title: 'Reject to Collector',
      hintText: 'Explain why this report is rejected.',
    );
    if (remark == null || remark.trim().isEmpty) return;

    setState(() => _rejecting = true);
    try {
      final result = await WorkflowReportService.teamLeaderAction(
        workflowReportId: widget.workflowReport!.id,
        action: 'rejected',
        remark: remark.trim(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        Get.snackbar('Rejected', 'Returned to Collector.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white);
        Get.back(result: true);
      }
    } catch (e) {
      Get.snackbar('Error', '$e');
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  Future<String?> _askForRemark({required String title, required String hintText}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(hintText: hintText, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  // ─── Simple UI (you already have the full one) ───
  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Review: Team Leader',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Based on ${widget.collections.length} collector report(s).',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),

          // Big green button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _teamLeaderApprove,
              icon: const Icon(Icons.check_circle),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              label: _sending
                  ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text(
                'Approve → Generate Official 4-Sectors XLSX → Send',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Reject button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _rejecting ? null : _teamLeaderReject,
              icon: const Icon(Icons.close),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              label: const Text('Reject to Collector'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ───
class _SectorSummary {
  final String name;
  final _Totals currentPeriod = _Totals();
  final _Totals advancePayment = _Totals();
  final _Totals previousYears = _Totals();
  _SectorSummary({required this.name});
}

class _Totals {
  double requested = 0;
  double weekPlan = 0;
  double weekCollected = 0;
  double ytdPlan = 0;
  double ytdCollected = 0;

  double get remaining => requested - ytdCollected;

  void add(_Totals other) {
    requested += other.requested;
    weekPlan += other.weekPlan;
    weekCollected += other.weekCollected;
    ytdPlan += other.ytdPlan;
    ytdCollected += other.ytdCollected;
  }

  void addFrom(Map<String, dynamic> values) {
    requested += _asNumber(values['requested']);
    weekPlan += _asNumber(values['week_plan']);
    weekCollected += _asNumber(values['week_collected']);
    ytdPlan += _asNumber(values['ytd_plan']);
    ytdCollected += _asNumber(values['ytd_collected']);
  }

  static double _asNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}