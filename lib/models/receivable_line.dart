class ReceivableLine {
  int? id;
  String projectName;
  String clientName;
  double requested;
  String billPeriod;
  double remaining;
  String lastBillDate;
  double weekExpected;
  double weekCollected;
  double ytdPlan;
  double ytdCollected;
  String residual;
  String stage;
  String responsible;

  ReceivableLine({
    this.id,
    this.projectName = '',
    this.clientName = '',
    this.requested = 0,
    this.billPeriod = '',
    this.remaining = 0,
    this.lastBillDate = '',
    this.weekExpected = 0,
    this.weekCollected = 0,
    this.ytdPlan = 0,
    this.ytdCollected = 0,
    this.residual = '',
    this.stage = '',
    this.responsible = '',
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'project_name': projectName,
    'client_name': clientName,
    'requested': requested,
    'bill_period': billPeriod,
    'remaining': remaining,
    'last_bill_date': lastBillDate,
    'week_expected': weekExpected,
    'week_collected': weekCollected,
    'ytd_plan': ytdPlan,
    'ytd_collected': ytdCollected,
    'residual': residual,
    'stage': stage,
    'responsible': responsible,
  };

  factory ReceivableLine.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse('$v'.replaceAll(',', '')) ?? 0;
    }

    return ReceivableLine(
      id: j['id'] is int ? j['id'] : int.tryParse('${j['id'] ?? ''}'),
      projectName: '${j['project_name'] ?? j['project'] ?? ''}',
      clientName: '${j['client_name'] ?? j['client'] ?? ''}',
      requested: d(j['requested']),
      billPeriod: '${j['bill_period'] ?? ''}',
      remaining: d(j['remaining']),
      lastBillDate: '${j['last_bill_date'] ?? ''}',
      weekExpected: d(j['week_expected']),
      weekCollected: d(j['week_collected']),
      ytdPlan: d(j['ytd_plan']),
      ytdCollected: d(j['ytd_collected']),
      residual: '${j['residual'] ?? ''}',
      stage: '${j['stage'] ?? ''}',
      responsible: '${j['responsible'] ?? ''}',
    );
  }
}