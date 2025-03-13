import 'package:json_annotation/json_annotation.dart';

class NotificationPreferencesModel {
  final String userId;
  final bool enabled;
  final NotificationChannels channels;
  final NotificationCategories categories;
  final QuietHours quietHours;
  final String updatedAt;

  NotificationPreferencesModel({
    required this.userId,
    this.enabled = true,
    required this.channels,
    required this.categories,
    required this.quietHours,
    required this.updatedAt,
  });

  // Manual fromJson implementation
  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      userId: json['userId'],
      enabled: json['enabled'] ?? true,
      channels: NotificationChannels.fromJson(json['channels']),
      categories: NotificationCategories.fromJson(json['categories']),
      quietHours: QuietHours.fromJson(json['quietHours']),
      updatedAt: json['updatedAt'],
    );
  }

  // Manual toJson implementation
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'enabled': enabled,
      'channels': channels.toJson(),
      'categories': categories.toJson(),
      'quietHours': quietHours.toJson(),
      'updatedAt': updatedAt,
    };
  }
}

class NotificationChannels {
  final ChannelSettings push;
  final ChannelSettings email;
  final ChannelSettings sms;
  final ChannelSettings inApp;

  NotificationChannels({
    required this.push,
    required this.email,
    required this.sms,
    required this.inApp,
  });

  factory NotificationChannels.fromJson(Map<String, dynamic> json) {
    return NotificationChannels(
      push: ChannelSettings.fromJson(json['push']),
      email: ChannelSettings.fromJson(json['email']),
      sms: ChannelSettings.fromJson(json['sms']),
      inApp: ChannelSettings.fromJson(json['inApp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push': push.toJson(),
      'email': email.toJson(),
      'sms': sms.toJson(),
      'inApp': inApp.toJson(),
    };
  }
}

class ChannelSettings {
  final bool enabled;
  final String? token;
  final String? address;
  final String? phoneNumber;

  ChannelSettings({
    this.enabled = true,
    this.token,
    this.address,
    this.phoneNumber,
  });

  factory ChannelSettings.fromJson(Map<String, dynamic> json) {
    return ChannelSettings(
      enabled: json['enabled'] ?? true,
      token: json['token'],
      address: json['address'],
      phoneNumber: json['phoneNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      if (token != null) 'token': token,
      if (address != null) 'address': address,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    };
  }
}

class NotificationCategories {
  final bool consultant_service;
  final bool new_post;
  final bool new_reel;
  final bool farm_videos;
  final bool crop_care_ai;
  final bool system;

  NotificationCategories({
    this.consultant_service = true,
    this.new_post = true,
    this.new_reel = true,
    this.farm_videos = true,
    this.crop_care_ai = true,
    this.system = true,
  });

  factory NotificationCategories.fromJson(Map<String, dynamic> json) {
    return NotificationCategories(
      consultant_service: json['consultant_service'] ?? true,
      new_post: json['new_post'] ?? true,
      new_reel: json['new_reel'] ?? true,
      farm_videos: json['farm_videos'] ?? true,
      crop_care_ai: json['crop_care_ai'] ?? true,
      system: json['system'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'consultant_service': consultant_service,
      'new_post': new_post,
      'new_reel': new_reel,
      'farm_videos': farm_videos,
      'crop_care_ai': crop_care_ai,
      'system': system,
    };
  }
}

class QuietHours {
  final bool enabled;
  final String start;
  final String end;
  final String timezone;

  QuietHours({
    this.enabled = false,
    this.start = "22:00",
    this.end = "07:00",
    this.timezone = "Asia/Kolkata",
  });

  factory QuietHours.fromJson(Map<String, dynamic> json) {
    return QuietHours(
      enabled: json['enabled'] ?? false,
      start: json['start'] ?? "22:00",
      end: json['end'] ?? "07:00",
      timezone: json['timezone'] ?? "Asia/Kolkata",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'start': start,
      'end': end,
      'timezone': timezone,
    };
  }
}
