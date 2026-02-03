/// Subscription Models for Krishi Mantra
/// Designed for Indian farmers with affordable pricing in INR
/// Includes IoT Add-on support for Water Pump and Crop Sensors

class SubscriptionPlan {
  final String id;
  final String name;
  final String displayName;
  final String displayNameHindi;
  final String description;
  final String descriptionHindi;
  final PlanPricing pricing;
  final PlanFeatures features;
  final int order;
  final bool isActive;
  final bool isDefault;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.displayName,
    required this.displayNameHindi,
    required this.description,
    required this.descriptionHindi,
    required this.pricing,
    required this.features,
    required this.order,
    required this.isActive,
    required this.isDefault,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? '',
      displayNameHindi: json['displayNameHindi'] ?? '',
      description: json['description'] ?? '',
      descriptionHindi: json['descriptionHindi'] ?? '',
      pricing: PlanPricing.fromJson(json['pricing'] ?? {}),
      features: PlanFeatures.fromJson(json['features'] ?? {}),
      order: json['order'] ?? 0,
      isActive: json['isActive'] ?? true,
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'displayName': displayName,
      'displayNameHindi': displayNameHindi,
      'description': description,
      'descriptionHindi': descriptionHindi,
      'pricing': pricing.toJson(),
      'features': features.toJson(),
      'order': order,
      'isActive': isActive,
      'isDefault': isDefault,
    };
  }

  /// Get monthly price in rupees
  double get monthlyPriceInRupees => pricing.monthly.amount / 100;

  /// Get yearly price in rupees
  double get yearlyPriceInRupees => pricing.yearly.amount / 100;

  /// Get monthly price formatted
  String get formattedMonthlyPrice {
    if (pricing.monthly.amount == 0) return 'Free';
    return '₹${monthlyPriceInRupees.toStringAsFixed(0)}/month';
  }

  /// Get yearly price formatted
  String get formattedYearlyPrice {
    if (pricing.yearly.amount == 0) return 'Free';
    return '₹${yearlyPriceInRupees.toStringAsFixed(0)}/year';
  }

  /// Check if plan is free
  bool get isFree => pricing.monthly.amount == 0;

  /// Check if feature is unlimited
  bool isFeatureUnlimited(String feature) {
    switch (feature) {
      case 'aiMessages':
        return features.aiMessagesPerDay == -1;
      case 'imageAnalysis':
        return features.imageAnalysisPerDay == -1;
      case 'consultantChats':
        return features.consultantChatsPerDay == -1;
      case 'videoConsultations':
        return features.videoConsultationsPerMonth == -1;
      case 'marketplaceListings':
        return features.marketplaceListings == -1;
      default:
        return false;
    }
  }
}

class PlanPricing {
  final PriceInfo monthly;
  final PriceInfo yearly;

  PlanPricing({
    required this.monthly,
    required this.yearly,
  });

  factory PlanPricing.fromJson(Map<String, dynamic> json) {
    return PlanPricing(
      monthly: PriceInfo.fromJson(json['monthly'] ?? {}),
      yearly: PriceInfo.fromJson(json['yearly'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monthly': monthly.toJson(),
      'yearly': yearly.toJson(),
    };
  }
}

class PriceInfo {
  final int amount; // In paise (100 paise = 1 INR)
  final String currency;
  final String? stripePriceId;
  final int savings; // Percentage savings for yearly

  PriceInfo({
    required this.amount,
    this.currency = 'inr',
    this.stripePriceId,
    this.savings = 0,
  });

  factory PriceInfo.fromJson(Map<String, dynamic> json) {
    return PriceInfo(
      amount: json['amount'] ?? 0,
      currency: json['currency'] ?? 'inr',
      stripePriceId: json['stripePriceId'],
      savings: json['savings'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'stripePriceId': stripePriceId,
      'savings': savings,
    };
  }
}

class PlanFeatures {
  final int aiMessagesPerDay;
  final int imageAnalysisPerDay;
  final int consultantChatsPerDay;
  final int videoConsultationsPerMonth;
  final bool canCreatePosts;
  final bool canCreateReels;
  final int marketplaceListings;
  final bool featuredListings;
  final bool pushNotifications;
  final bool smsNotifications;
  final bool emailNotifications;
  final bool adFree;
  final int reducedAds;
  final bool prioritySupport;
  final String analyticsAccess;
  final bool offlineCropCalendar;
  final bool priorityFeedRecommendations;

  PlanFeatures({
    required this.aiMessagesPerDay,
    required this.imageAnalysisPerDay,
    required this.consultantChatsPerDay,
    required this.videoConsultationsPerMonth,
    required this.canCreatePosts,
    required this.canCreateReels,
    required this.marketplaceListings,
    required this.featuredListings,
    required this.pushNotifications,
    required this.smsNotifications,
    required this.emailNotifications,
    required this.adFree,
    required this.reducedAds,
    required this.prioritySupport,
    required this.analyticsAccess,
    required this.offlineCropCalendar,
    required this.priorityFeedRecommendations,
  });

  factory PlanFeatures.fromJson(Map<String, dynamic> json) {
    return PlanFeatures(
      aiMessagesPerDay: json['aiMessagesPerDay'] ?? 5,
      imageAnalysisPerDay: json['imageAnalysisPerDay'] ?? 2,
      consultantChatsPerDay: json['consultantChatsPerDay'] ?? 10,
      videoConsultationsPerMonth: json['videoConsultationsPerMonth'] ?? 0,
      canCreatePosts: json['canCreatePosts'] ?? false,
      canCreateReels: json['canCreateReels'] ?? false,
      marketplaceListings: json['marketplaceListings'] ?? 0,
      featuredListings: json['featuredListings'] ?? false,
      pushNotifications: json['pushNotifications'] ?? true,
      smsNotifications: json['smsNotifications'] ?? false,
      emailNotifications: json['emailNotifications'] ?? false,
      adFree: json['adFree'] ?? false,
      reducedAds: json['reducedAds'] ?? 0,
      prioritySupport: json['prioritySupport'] ?? false,
      analyticsAccess: json['analyticsAccess'] ?? 'none',
      offlineCropCalendar: json['offlineCropCalendar'] ?? false,
      priorityFeedRecommendations: json['priorityFeedRecommendations'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aiMessagesPerDay': aiMessagesPerDay,
      'imageAnalysisPerDay': imageAnalysisPerDay,
      'consultantChatsPerDay': consultantChatsPerDay,
      'videoConsultationsPerMonth': videoConsultationsPerMonth,
      'canCreatePosts': canCreatePosts,
      'canCreateReels': canCreateReels,
      'marketplaceListings': marketplaceListings,
      'featuredListings': featuredListings,
      'pushNotifications': pushNotifications,
      'smsNotifications': smsNotifications,
      'emailNotifications': emailNotifications,
      'adFree': adFree,
      'reducedAds': reducedAds,
      'prioritySupport': prioritySupport,
      'analyticsAccess': analyticsAccess,
      'offlineCropCalendar': offlineCropCalendar,
      'priorityFeedRecommendations': priorityFeedRecommendations,
    };
  }

  /// Get feature display value
  String getFeatureDisplay(String feature) {
    switch (feature) {
      case 'aiMessagesPerDay':
        return aiMessagesPerDay == -1 ? 'Unlimited' : '$aiMessagesPerDay/day';
      case 'imageAnalysisPerDay':
        return imageAnalysisPerDay == -1 ? 'Unlimited' : '$imageAnalysisPerDay/day';
      case 'consultantChatsPerDay':
        return consultantChatsPerDay == -1 ? 'Unlimited' : '$consultantChatsPerDay/day';
      case 'videoConsultationsPerMonth':
        return videoConsultationsPerMonth == -1
            ? 'Unlimited'
            : videoConsultationsPerMonth == 0
                ? 'Not included'
                : '$videoConsultationsPerMonth/month';
      case 'marketplaceListings':
        return marketplaceListings == -1
            ? 'Unlimited'
            : marketplaceListings == 0
                ? 'Not included'
                : '$marketplaceListings listings';
      default:
        return '';
    }
  }
}

class UserSubscription {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String billingCycle;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? cancelledAt;
  final int? lastPaymentAmount;
  final DateTime? lastPaymentDate;
  final DateTime? nextPaymentDate;
  final bool autoRenew;
  final String? cancellationReason;

  UserSubscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    required this.billingCycle,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.cancelledAt,
    this.lastPaymentAmount,
    this.lastPaymentDate,
    this.nextPaymentDate,
    required this.autoRenew,
    this.cancellationReason,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      planId: json['planId'] is Map ? json['planId']['_id'] ?? '' : json['planId'] ?? '',
      planName: json['planName'] ?? 'KISAN',
      stripeCustomerId: json['stripeCustomerId'],
      stripeSubscriptionId: json['stripeSubscriptionId'],
      billingCycle: json['billingCycle'] ?? 'monthly',
      status: json['status'] ?? 'pending',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'])
          : DateTime.now().add(const Duration(days: 30)),
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
      lastPaymentAmount: json['lastPaymentAmount'],
      lastPaymentDate: json['lastPaymentDate'] != null
          ? DateTime.parse(json['lastPaymentDate'])
          : null,
      nextPaymentDate: json['nextPaymentDate'] != null
          ? DateTime.parse(json['nextPaymentDate'])
          : null,
      autoRenew: json['autoRenew'] ?? true,
      cancellationReason: json['cancellationReason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'planId': planId,
      'planName': planName,
      'stripeCustomerId': stripeCustomerId,
      'stripeSubscriptionId': stripeSubscriptionId,
      'billingCycle': billingCycle,
      'status': status,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'lastPaymentAmount': lastPaymentAmount,
      'lastPaymentDate': lastPaymentDate?.toIso8601String(),
      'nextPaymentDate': nextPaymentDate?.toIso8601String(),
      'autoRenew': autoRenew,
      'cancellationReason': cancellationReason,
    };
  }

  /// Check if subscription is active
  bool get isActive => status == 'active' && endDate.isAfter(DateTime.now());

  /// Check if subscription is cancelled but still active
  bool get isCancelledButActive =>
      cancelledAt != null && endDate.isAfter(DateTime.now());

  /// Days remaining in subscription
  int get daysRemaining {
    final now = DateTime.now();
    if (endDate.isBefore(now)) return 0;
    return endDate.difference(now).inDays;
  }

  /// Get status display text
  String get statusDisplay {
    switch (status) {
      case 'active':
        return isCancelledButActive ? 'Cancelling' : 'Active';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      case 'past_due':
        return 'Payment Due';
      case 'trialing':
        return 'Trial';
      default:
        return 'Pending';
    }
  }
}

class UsageStats {
  final UsageInfo aiMessages;
  final UsageInfo imageAnalysis;
  final UsageInfo consultantChats;
  final UsageInfo videoConsultations;
  final String planName;
  final DateTime resetsAt;

  UsageStats({
    required this.aiMessages,
    required this.imageAnalysis,
    required this.consultantChats,
    required this.videoConsultations,
    required this.planName,
    required this.resetsAt,
  });

  factory UsageStats.fromJson(Map<String, dynamic> json) {
    final usage = json['usage'] ?? {};
    final limits = json['limits'] ?? {};
    final remaining = json['remaining'] ?? {};

    return UsageStats(
      aiMessages: UsageInfo(
        used: usage['aiMessagesUsed'] ?? 0,
        limit: limits['aiMessagesPerDay'] ?? 5,
        remaining: remaining['aiMessages'] ?? 5,
      ),
      imageAnalysis: UsageInfo(
        used: usage['imageAnalysisUsed'] ?? 0,
        limit: limits['imageAnalysisPerDay'] ?? 2,
        remaining: remaining['imageAnalysis'] ?? 2,
      ),
      consultantChats: UsageInfo(
        used: usage['consultantChatsUsed'] ?? 0,
        limit: limits['consultantChatsPerDay'] ?? 10,
        remaining: remaining['consultantChats'] ?? 10,
      ),
      videoConsultations: UsageInfo(
        used: usage['videoConsultationsUsed'] ?? 0,
        limit: limits['videoConsultationsPerMonth'] ?? 0,
        remaining: remaining['videoConsultations'] ?? 0,
      ),
      planName: json['planName'] ?? 'KISAN',
      resetsAt: DateTime.now().add(const Duration(days: 1)).copyWith(
            hour: 0,
            minute: 0,
            second: 0,
            millisecond: 0,
          ),
    );
  }
}

class UsageInfo {
  final int used;
  final int limit;
  final int remaining;

  UsageInfo({
    required this.used,
    required this.limit,
    required this.remaining,
  });

  /// Check if unlimited
  bool get isUnlimited => limit == -1;

  /// Check if limit reached
  bool get isLimitReached => !isUnlimited && remaining <= 0;

  /// Get percentage used
  double get percentageUsed {
    if (isUnlimited) return 0;
    if (limit == 0) return 100;
    return (used / limit) * 100;
  }

  /// Get display string
  String get displayString {
    if (isUnlimited) return 'Unlimited';
    return '$remaining/$limit remaining';
  }
}

class PaymentHistory {
  final String id;
  final String userId;
  final String subscriptionId;
  final String? stripePaymentIntentId;
  final String? stripeInvoiceId;
  final int amount;
  final String currency;
  final String status;
  final String? description;
  final String? invoiceUrl;
  final String? receiptUrl;
  final DateTime createdAt;

  PaymentHistory({
    required this.id,
    required this.userId,
    required this.subscriptionId,
    this.stripePaymentIntentId,
    this.stripeInvoiceId,
    required this.amount,
    required this.currency,
    required this.status,
    this.description,
    this.invoiceUrl,
    this.receiptUrl,
    required this.createdAt,
  });

  factory PaymentHistory.fromJson(Map<String, dynamic> json) {
    return PaymentHistory(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      subscriptionId: json['subscriptionId'] ?? '',
      stripePaymentIntentId: json['stripePaymentIntentId'],
      stripeInvoiceId: json['stripeInvoiceId'],
      amount: json['amount'] ?? 0,
      currency: json['currency'] ?? 'inr',
      status: json['status'] ?? 'pending',
      description: json['description'],
      invoiceUrl: json['invoiceUrl'],
      receiptUrl: json['receiptUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  /// Get amount in rupees
  double get amountInRupees => amount / 100;

  /// Get formatted amount
  String get formattedAmount => '₹${amountInRupees.toStringAsFixed(2)}';

  /// Get status display
  String get statusDisplay {
    switch (status) {
      case 'succeeded':
        return 'Paid';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      case 'pending':
        return 'Processing';
      default:
        return status;
    }
  }
}

// ========== IoT ADD-ON MODELS ==========

/// IoT Add-on for Water Pump and Crop Monitoring
class IotAddon {
  final String id;
  final String name;
  final String displayName;
  final String displayNameHindi;
  final String description;
  final String descriptionHindi;
  final PlanPricing pricing;
  final IotAddonFeatures features;
  final int bundleSavings;
  final int order;
  final bool isActive;

  IotAddon({
    required this.id,
    required this.name,
    required this.displayName,
    required this.displayNameHindi,
    required this.description,
    required this.descriptionHindi,
    required this.pricing,
    required this.features,
    required this.bundleSavings,
    required this.order,
    required this.isActive,
  });

  factory IotAddon.fromJson(Map<String, dynamic> json) {
    return IotAddon(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? '',
      displayNameHindi: json['displayNameHindi'] ?? '',
      description: json['description'] ?? '',
      descriptionHindi: json['descriptionHindi'] ?? '',
      pricing: PlanPricing.fromJson(json['pricing'] ?? {}),
      features: IotAddonFeatures.fromJson(json['features'] ?? {}),
      bundleSavings: json['bundleSavings'] ?? 0,
      order: json['order'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'displayName': displayName,
      'displayNameHindi': displayNameHindi,
      'description': description,
      'descriptionHindi': descriptionHindi,
      'pricing': pricing.toJson(),
      'features': features.toJson(),
      'bundleSavings': bundleSavings,
      'order': order,
      'isActive': isActive,
    };
  }

  /// Get monthly price in rupees
  double get monthlyPriceInRupees => pricing.monthly.amount / 100;

  /// Get yearly price in rupees
  double get yearlyPriceInRupees => pricing.yearly.amount / 100;

  /// Get monthly price formatted
  String get formattedMonthlyPrice => '₹${monthlyPriceInRupees.toStringAsFixed(0)}/month';

  /// Get yearly price formatted
  String get formattedYearlyPrice => '₹${yearlyPriceInRupees.toStringAsFixed(0)}/year';

  /// Get bundle savings formatted
  String get formattedSavings => '₹${(bundleSavings / 100).toStringAsFixed(0)}/month';

  /// Check if this is a bundle
  bool get isBundle => name == 'IOT_BUNDLE';

  /// Check if this includes water pump
  bool get hasWaterPump => features.waterPump.enabled;

  /// Check if this includes crop monitoring
  bool get hasCropMonitoring => features.cropMonitoring.enabled;
}

class IotAddonFeatures {
  final WaterPumpFeatures waterPump;
  final CropMonitoringFeatures cropMonitoring;
  final WeatherStationFeatures weatherStation;

  IotAddonFeatures({
    required this.waterPump,
    required this.cropMonitoring,
    required this.weatherStation,
  });

  factory IotAddonFeatures.fromJson(Map<String, dynamic> json) {
    return IotAddonFeatures(
      waterPump: WaterPumpFeatures.fromJson(json['waterPump'] ?? {}),
      cropMonitoring: CropMonitoringFeatures.fromJson(json['cropMonitoring'] ?? {}),
      weatherStation: WeatherStationFeatures.fromJson(json['weatherStation'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'waterPump': waterPump.toJson(),
      'cropMonitoring': cropMonitoring.toJson(),
      'weatherStation': weatherStation.toJson(),
    };
  }
}

class WaterPumpFeatures {
  final bool enabled;
  final int maxDevices;
  final bool schedulingEnabled;
  final bool remoteControlEnabled;
  final int automationRulesLimit;
  final bool waterUsageAnalytics;
  final bool alertsEnabled;

  WaterPumpFeatures({
    required this.enabled,
    required this.maxDevices,
    required this.schedulingEnabled,
    required this.remoteControlEnabled,
    required this.automationRulesLimit,
    required this.waterUsageAnalytics,
    required this.alertsEnabled,
  });

  factory WaterPumpFeatures.fromJson(Map<String, dynamic> json) {
    return WaterPumpFeatures(
      enabled: json['enabled'] ?? false,
      maxDevices: json['maxDevices'] ?? 0,
      schedulingEnabled: json['schedulingEnabled'] ?? false,
      remoteControlEnabled: json['remoteControlEnabled'] ?? false,
      automationRulesLimit: json['automationRulesLimit'] ?? 0,
      waterUsageAnalytics: json['waterUsageAnalytics'] ?? false,
      alertsEnabled: json['alertsEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'maxDevices': maxDevices,
      'schedulingEnabled': schedulingEnabled,
      'remoteControlEnabled': remoteControlEnabled,
      'automationRulesLimit': automationRulesLimit,
      'waterUsageAnalytics': waterUsageAnalytics,
      'alertsEnabled': alertsEnabled,
    };
  }
}

class CropMonitoringFeatures {
  final bool enabled;
  final int maxSensors;
  final bool soilMoistureSensor;
  final bool temperatureSensor;
  final bool humiditySensor;
  final bool lightSensor;
  final bool phSensor;
  final bool nutrientSensor;
  final int dataRefreshRateMinutes;
  final int historicalDataDays;
  final bool alertsEnabled;
  final bool aiRecommendations;

  CropMonitoringFeatures({
    required this.enabled,
    required this.maxSensors,
    required this.soilMoistureSensor,
    required this.temperatureSensor,
    required this.humiditySensor,
    required this.lightSensor,
    required this.phSensor,
    required this.nutrientSensor,
    required this.dataRefreshRateMinutes,
    required this.historicalDataDays,
    required this.alertsEnabled,
    required this.aiRecommendations,
  });

  factory CropMonitoringFeatures.fromJson(Map<String, dynamic> json) {
    return CropMonitoringFeatures(
      enabled: json['enabled'] ?? false,
      maxSensors: json['maxSensors'] ?? 0,
      soilMoistureSensor: json['soilMoistureSensor'] ?? false,
      temperatureSensor: json['temperatureSensor'] ?? false,
      humiditySensor: json['humiditySensor'] ?? false,
      lightSensor: json['lightSensor'] ?? false,
      phSensor: json['phSensor'] ?? false,
      nutrientSensor: json['nutrientSensor'] ?? false,
      dataRefreshRateMinutes: json['dataRefreshRateMinutes'] ?? 60,
      historicalDataDays: json['historicalDataDays'] ?? 7,
      alertsEnabled: json['alertsEnabled'] ?? false,
      aiRecommendations: json['aiRecommendations'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'maxSensors': maxSensors,
      'soilMoistureSensor': soilMoistureSensor,
      'temperatureSensor': temperatureSensor,
      'humiditySensor': humiditySensor,
      'lightSensor': lightSensor,
      'phSensor': phSensor,
      'nutrientSensor': nutrientSensor,
      'dataRefreshRateMinutes': dataRefreshRateMinutes,
      'historicalDataDays': historicalDataDays,
      'alertsEnabled': alertsEnabled,
      'aiRecommendations': aiRecommendations,
    };
  }
}

class WeatherStationFeatures {
  final bool enabled;
  final bool localWeatherData;
  final int forecastDays;
  final bool rainPredictionAlerts;
  final bool frostAlerts;

  WeatherStationFeatures({
    required this.enabled,
    required this.localWeatherData,
    required this.forecastDays,
    required this.rainPredictionAlerts,
    required this.frostAlerts,
  });

  factory WeatherStationFeatures.fromJson(Map<String, dynamic> json) {
    return WeatherStationFeatures(
      enabled: json['enabled'] ?? false,
      localWeatherData: json['localWeatherData'] ?? false,
      forecastDays: json['forecastDays'] ?? 3,
      rainPredictionAlerts: json['rainPredictionAlerts'] ?? false,
      frostAlerts: json['frostAlerts'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'localWeatherData': localWeatherData,
      'forecastDays': forecastDays,
      'rainPredictionAlerts': rainPredictionAlerts,
      'frostAlerts': frostAlerts,
    };
  }
}

/// User's IoT Add-on Subscription
class UserIotAddon {
  final String id;
  final String userId;
  final String addonId;
  final String addonName;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String billingCycle;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? cancelledAt;
  final int? lastPaymentAmount;
  final DateTime? lastPaymentDate;
  final DateTime? nextPaymentDate;
  final bool autoRenew;
  final List<LinkedDevice> linkedDevices;
  final IotAddon? addon;

  UserIotAddon({
    required this.id,
    required this.userId,
    required this.addonId,
    required this.addonName,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    required this.billingCycle,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.cancelledAt,
    this.lastPaymentAmount,
    this.lastPaymentDate,
    this.nextPaymentDate,
    required this.autoRenew,
    required this.linkedDevices,
    this.addon,
  });

  factory UserIotAddon.fromJson(Map<String, dynamic> json) {
    return UserIotAddon(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      addonId: json['addonId'] is Map ? json['addonId']['_id'] ?? '' : json['addonId'] ?? '',
      addonName: json['addonName'] ?? '',
      stripeCustomerId: json['stripeCustomerId'],
      stripeSubscriptionId: json['stripeSubscriptionId'],
      billingCycle: json['billingCycle'] ?? 'monthly',
      status: json['status'] ?? 'pending',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'])
          : DateTime.now().add(const Duration(days: 30)),
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
      lastPaymentAmount: json['lastPaymentAmount'],
      lastPaymentDate: json['lastPaymentDate'] != null
          ? DateTime.parse(json['lastPaymentDate'])
          : null,
      nextPaymentDate: json['nextPaymentDate'] != null
          ? DateTime.parse(json['nextPaymentDate'])
          : null,
      autoRenew: json['autoRenew'] ?? true,
      linkedDevices: (json['linkedDevices'] as List<dynamic>?)
              ?.map((e) => LinkedDevice.fromJson(e))
              .toList() ??
          [],
      addon: json['addonId'] is Map ? IotAddon.fromJson(json['addonId']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'addonId': addonId,
      'addonName': addonName,
      'stripeCustomerId': stripeCustomerId,
      'stripeSubscriptionId': stripeSubscriptionId,
      'billingCycle': billingCycle,
      'status': status,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'lastPaymentAmount': lastPaymentAmount,
      'lastPaymentDate': lastPaymentDate?.toIso8601String(),
      'nextPaymentDate': nextPaymentDate?.toIso8601String(),
      'autoRenew': autoRenew,
      'linkedDevices': linkedDevices.map((e) => e.toJson()).toList(),
    };
  }

  /// Check if subscription is active
  bool get isActive => status == 'active' && endDate.isAfter(DateTime.now());

  /// Days remaining in subscription
  int get daysRemaining {
    final now = DateTime.now();
    if (endDate.isBefore(now)) return 0;
    return endDate.difference(now).inDays;
  }

  /// Get display name based on addon type
  String get displayName {
    switch (addonName) {
      case 'WATER_PUMP':
        return 'Smart Water Pump';
      case 'CROP_IOT':
        return 'Crop IoT Sensors';
      case 'IOT_BUNDLE':
        return 'IoT Complete Bundle';
      default:
        return addonName;
    }
  }

  /// Get display name in Hindi
  String get displayNameHindi {
    switch (addonName) {
      case 'WATER_PUMP':
        return 'स्मार्ट वाटर पंप';
      case 'CROP_IOT':
        return 'फसल IoT सेंसर';
      case 'IOT_BUNDLE':
        return 'IoT पूर्ण बंडल';
      default:
        return addonName;
    }
  }
}

class LinkedDevice {
  final String deviceId;
  final String deviceType;
  final String deviceName;
  final DateTime addedAt;
  final bool isActive;

  LinkedDevice({
    required this.deviceId,
    required this.deviceType,
    required this.deviceName,
    required this.addedAt,
    required this.isActive,
  });

  factory LinkedDevice.fromJson(Map<String, dynamic> json) {
    return LinkedDevice(
      deviceId: json['deviceId'] ?? '',
      deviceType: json['deviceType'] ?? '',
      deviceName: json['deviceName'] ?? '',
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceType': deviceType,
      'deviceName': deviceName,
      'addedAt': addedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Get device type display
  String get deviceTypeDisplay {
    switch (deviceType) {
      case 'water_pump':
        return 'Water Pump';
      case 'soil_sensor':
        return 'Soil Sensor';
      case 'weather_station':
        return 'Weather Station';
      default:
        return deviceType;
    }
  }
}
