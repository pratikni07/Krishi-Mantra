class ActionItem {
  final String itemId;
  final String cropEntryId;
  final String cropName;
  final String? cropVariety;
  final String? templateId;
  final String source; // template | ai | weather_alert | manual
  final String verb;
  final String title;
  final String? detail;
  final String? chemical;
  final String? dose;
  final String? safetyNote;
  final String urgency; // low | normal | high | urgent
  final List<String> rationaleTags;
  final String status;  // pending | done | skipped | snoozed
  final DateTime? statusUpdatedAt;
  final DateTime? snoozeUntil;
  final String? skipReason;

  const ActionItem({
    required this.itemId,
    required this.cropEntryId,
    required this.cropName,
    this.cropVariety,
    this.templateId,
    this.source = 'template',
    required this.verb,
    required this.title,
    this.detail,
    this.chemical,
    this.dose,
    this.safetyNote,
    this.urgency = 'normal',
    this.rationaleTags = const [],
    this.status = 'pending',
    this.statusUpdatedAt,
    this.snoozeUntil,
    this.skipReason,
  });

  factory ActionItem.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }
    return ActionItem(
      itemId: j['itemId']?.toString() ?? '',
      cropEntryId: j['cropEntryId']?.toString() ?? '',
      cropName: j['cropName']?.toString() ?? '',
      cropVariety: j['cropVariety']?.toString(),
      templateId: j['templateId']?.toString(),
      source: j['source']?.toString() ?? 'template',
      verb: j['verb']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      detail: j['detail']?.toString(),
      chemical: j['chemical']?.toString(),
      dose: j['dose']?.toString(),
      safetyNote: j['safetyNote']?.toString(),
      urgency: j['urgency']?.toString() ?? 'normal',
      rationaleTags: (j['rationaleTags'] as List?)?.cast<String>() ?? const [],
      status: j['status']?.toString() ?? 'pending',
      statusUpdatedAt: parseDate(j['statusUpdatedAt']),
      snoozeUntil: parseDate(j['snoozeUntil']),
      skipReason: j['skipReason']?.toString(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isUrgent => urgency == 'urgent' || urgency == 'high';

  ActionItem copyWith({
    String? status,
    DateTime? statusUpdatedAt,
    DateTime? snoozeUntil,
    String? skipReason,
  }) =>
      ActionItem(
        itemId: itemId,
        cropEntryId: cropEntryId,
        cropName: cropName,
        cropVariety: cropVariety,
        templateId: templateId,
        source: source,
        verb: verb,
        title: title,
        detail: detail,
        chemical: chemical,
        dose: dose,
        safetyNote: safetyNote,
        urgency: urgency,
        rationaleTags: rationaleTags,
        status: status ?? this.status,
        statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
        snoozeUntil: snoozeUntil ?? this.snoozeUntil,
        skipReason: skipReason ?? this.skipReason,
      );
}

class FarmerInput {
  final String? text;
  final List<String> imageUrls;
  final String? voiceUrl;
  final DateTime? submittedAt;
  final bool acknowledged;

  const FarmerInput({
    this.text,
    this.imageUrls = const [],
    this.voiceUrl,
    this.submittedAt,
    this.acknowledged = false,
  });

  factory FarmerInput.fromJson(Map<String, dynamic> j) => FarmerInput(
        text: j['text']?.toString(),
        imageUrls: (j['imageUrls'] as List?)?.cast<String>() ?? const [],
        voiceUrl: j['voiceUrl']?.toString(),
        submittedAt: j['submittedAt'] != null
            ? DateTime.tryParse(j['submittedAt'].toString())
            : null,
        acknowledged: j['acknowledged'] == true,
      );

  bool get isEmpty => (text == null || text!.isEmpty) && imageUrls.isEmpty;
}

class ActionCard {
  final String? cardId;
  final String localDate;
  final List<ActionItem> items;
  final FarmerInput? farmerInput;
  final bool cached;
  final bool empty;
  final String? emptyReason;

  const ActionCard({
    this.cardId,
    required this.localDate,
    this.items = const [],
    this.farmerInput,
    this.cached = false,
    this.empty = false,
    this.emptyReason,
  });

  factory ActionCard.fromJson(Map<String, dynamic> j) => ActionCard(
        cardId: j['cardId']?.toString(),
        localDate: j['localDate']?.toString() ?? '',
        items: (j['items'] as List?)
                ?.map((it) => ActionItem.fromJson(Map<String, dynamic>.from(it)))
                .toList() ??
            const [],
        farmerInput: j['farmerInput'] is Map
            ? FarmerInput.fromJson(Map<String, dynamic>.from(j['farmerInput']))
            : null,
        cached: j['cached'] == true,
        empty: j['empty'] == true,
        emptyReason: j['reason']?.toString(),
      );

  int get pendingCount => items.where((i) => i.isPending).length;
  bool get hasUrgent => items.any((i) => i.isPending && i.isUrgent);
}
