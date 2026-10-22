/// One project row as in Receivables and Collection Template.xls
class CollectionLine {
  final String? projectName;
  final String? clientOwner; // የስራ ባለቤት e.g. ERA, AACRA
  final double? receivableFromJuly1; // ከደንበኛው ከሃምሌ 1 ጀምሮ የሚፈለግ ሂሳብ
  final String? billPeriod; // የቢል ወቅት
  final double? residualAmount; // ከተጠየቀው ጠቅላላ የክፍያ መጠን ቀሪ
  final String? lastBillDate;
  final double? weekPlanAmount; // በሳምንቱ ውስጥ ይሰበሰባል ተብሎ
  final double? weekCollected; // በዚህ ሳምንት የተሰበሰበው
  final double? periodPlanAmount; // ከጁላይ 1 እስከ ... በእቅድ
  final double? periodCollected; // ከጁላይ 1 እስከ ... የተሰበሰበ
  final double? unpaidResidual; // ቀሪ ያልተሰበሰበ
  final String? collectionStage; // ተሰብሳቢው ሂሳብ ያለበት ደረጃ
  final String? followUpUnit; // ስራውን የሚከታተለው አካል
  final String? remark;

  CollectionLine({
    this.projectName,
    this.clientOwner,
    this.receivableFromJuly1,
    this.billPeriod,
    this.residualAmount,
    this.lastBillDate,
    this.weekPlanAmount,
    this.weekCollected,
    this.periodPlanAmount,
    this.periodCollected,
    this.unpaidResidual,
    this.collectionStage,
    this.followUpUnit,
    this.remark,
  });

  factory CollectionLine.fromJson(Map<String, dynamic> json) {
    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', ''));
    }

    return CollectionLine(
      projectName: json['project_name']?.toString() ?? json['client']?.toString(),
      clientOwner: json['client_owner']?.toString() ?? json['client']?.toString(),
      receivableFromJuly1: d(json['receivable_from_july1'] ?? json['receivable']),
      billPeriod: json['bill_period']?.toString() ?? json['invoice_no']?.toString(),
      residualAmount: d(json['residual_amount'] ?? json['balance']),
      lastBillDate: json['last_bill_date']?.toString(),
      weekPlanAmount: d(json['week_plan_amount']),
      weekCollected: d(json['week_collected'] ?? json['collected']),
      periodPlanAmount: d(json['period_plan_amount']),
      periodCollected: d(json['period_collected']),
      unpaidResidual: d(json['unpaid_residual'] ?? json['balance']),
      collectionStage: json['collection_stage']?.toString(),
      followUpUnit: json['follow_up_unit']?.toString(),
      remark: json['remark']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'project_name': projectName,
        'client_owner': clientOwner,
        'receivable_from_july1': receivableFromJuly1,
        'bill_period': billPeriod,
        'residual_amount': residualAmount,
        'last_bill_date': lastBillDate,
        'week_plan_amount': weekPlanAmount,
        'week_collected': weekCollected,
        'period_plan_amount': periodPlanAmount,
        'period_collected': periodCollected,
        'unpaid_residual': unpaidResidual,
        'collection_stage': collectionStage,
        'follow_up_unit': followUpUnit,
        'remark': remark,
      };
}
