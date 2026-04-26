class CropEntry {
  final String? id;
  final String cropId;
  final String cropName;
  final String? variety;
  final double area;
  final String areaUnit;
  final DateTime sowingDate;
  final DateTime? expectedHarvestDate;
  final String growthStage;
  final String? plantingMethod;
  final String? irrigationMethod;
  final String? notes;
  final bool isActive;

  const CropEntry({
    this.id,
    required this.cropId,
    required this.cropName,
    this.variety,
    required this.area,
    this.areaUnit = 'acre',
    required this.sowingDate,
    this.expectedHarvestDate,
    this.growthStage = 'vegetative',
    this.plantingMethod,
    this.irrigationMethod,
    this.notes,
    this.isActive = true,
  });

  factory CropEntry.fromJson(Map<String, dynamic> json) => CropEntry(
        id: json['_id']?.toString(),
        cropId: json['cropId']?.toString() ?? '',
        cropName: json['cropName']?.toString() ?? '',
        variety: json['variety']?.toString(),
        area: (json['area'] as num?)?.toDouble() ?? 0,
        areaUnit: json['areaUnit']?.toString() ?? 'acre',
        sowingDate: DateTime.parse(
          json['sowingDate']?.toString() ?? DateTime.now().toIso8601String(),
        ),
        expectedHarvestDate: json['expectedHarvestDate'] != null
            ? DateTime.parse(json['expectedHarvestDate'].toString())
            : null,
        growthStage: json['growthStage']?.toString() ?? 'vegetative',
        plantingMethod: json['plantingMethod']?.toString(),
        irrigationMethod: json['irrigationMethod']?.toString(),
        notes: json['notes']?.toString(),
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) '_id': id,
        'cropId': cropId,
        'cropName': cropName,
        if (variety != null) 'variety': variety,
        'area': area,
        'areaUnit': areaUnit,
        'sowingDate': sowingDate.toIso8601String(),
        if (expectedHarvestDate != null)
          'expectedHarvestDate': expectedHarvestDate!.toIso8601String(),
        'growthStage': growthStage,
        if (plantingMethod != null) 'plantingMethod': plantingMethod,
        if (irrigationMethod != null) 'irrigationMethod': irrigationMethod,
        if (notes != null) 'notes': notes,
        'isActive': isActive,
      };

  CropEntry copyWith({
    String? id,
    String? cropId,
    String? cropName,
    String? variety,
    double? area,
    String? areaUnit,
    DateTime? sowingDate,
    DateTime? expectedHarvestDate,
    String? growthStage,
    String? plantingMethod,
    String? irrigationMethod,
    String? notes,
    bool? isActive,
  }) =>
      CropEntry(
        id: id ?? this.id,
        cropId: cropId ?? this.cropId,
        cropName: cropName ?? this.cropName,
        variety: variety ?? this.variety,
        area: area ?? this.area,
        areaUnit: areaUnit ?? this.areaUnit,
        sowingDate: sowingDate ?? this.sowingDate,
        expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
        growthStage: growthStage ?? this.growthStage,
        plantingMethod: plantingMethod ?? this.plantingMethod,
        irrigationMethod: irrigationMethod ?? this.irrigationMethod,
        notes: notes ?? this.notes,
        isActive: isActive ?? this.isActive,
      );
}

class FarmAddress {
  final String? village;
  final String? taluka;
  final String? district;
  final String? state;
  final String country;
  final String? pincode;

  const FarmAddress({
    this.village,
    this.taluka,
    this.district,
    this.state,
    this.country = 'India',
    this.pincode,
  });

  factory FarmAddress.fromJson(Map<String, dynamic> json) => FarmAddress(
        village: json['village']?.toString(),
        taluka: json['taluka']?.toString(),
        district: json['district']?.toString(),
        state: json['state']?.toString(),
        country: json['country']?.toString() ?? 'India',
        pincode: json['pincode']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        if (village != null) 'village': village,
        if (taluka != null) 'taluka': taluka,
        if (district != null) 'district': district,
        if (state != null) 'state': state,
        'country': country,
        if (pincode != null) 'pincode': pincode,
      };

  FarmAddress copyWith({
    String? village,
    String? taluka,
    String? district,
    String? state,
    String? country,
    String? pincode,
  }) =>
      FarmAddress(
        village: village ?? this.village,
        taluka: taluka ?? this.taluka,
        district: district ?? this.district,
        state: state ?? this.state,
        country: country ?? this.country,
        pincode: pincode ?? this.pincode,
      );
}

class FarmProfile {
  final String? id;
  final String? userId;
  final int? age;
  final String? gender;
  final String preferredLanguage;
  final double? latitude;
  final double? longitude;
  final FarmAddress? address;
  final double? totalArea;
  final String totalAreaUnit;
  final String? ownership;
  final List<String> soilTypes;
  final List<String> irrigationSources;
  final int experienceYears;
  final List<CropEntry> crops;
  final String onboardingStatus;
  final int profileVersion;

  const FarmProfile({
    this.id,
    this.userId,
    this.age,
    this.gender,
    this.preferredLanguage = 'en',
    this.latitude,
    this.longitude,
    this.address,
    this.totalArea,
    this.totalAreaUnit = 'acre',
    this.ownership,
    this.soilTypes = const [],
    this.irrigationSources = const [],
    this.experienceYears = 0,
    this.crops = const [],
    this.onboardingStatus = 'not_started',
    this.profileVersion = 1,
  });

  factory FarmProfile.empty() => const FarmProfile();

  factory FarmProfile.fromJson(Map<String, dynamic> json) {
    final coords = (json['location']?['coordinates'] as List?)?.cast<num>();
    return FarmProfile(
      id: json['_id']?.toString(),
      userId: json['userId']?.toString(),
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender']?.toString(),
      preferredLanguage: json['preferredLanguage']?.toString() ?? 'en',
      longitude: coords != null && coords.isNotEmpty ? coords[0].toDouble() : null,
      latitude: coords != null && coords.length > 1 ? coords[1].toDouble() : null,
      address: json['address'] != null
          ? FarmAddress.fromJson(Map<String, dynamic>.from(json['address']))
          : null,
      totalArea: (json['totalArea'] as num?)?.toDouble(),
      totalAreaUnit: json['totalAreaUnit']?.toString() ?? 'acre',
      ownership: json['ownership']?.toString(),
      soilTypes: (json['soilTypes'] as List?)?.cast<String>() ?? const [],
      irrigationSources:
          (json['irrigationSources'] as List?)?.cast<String>() ?? const [],
      experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
      crops: (json['crops'] as List?)
              ?.map((c) => CropEntry.fromJson(Map<String, dynamic>.from(c)))
              .toList() ??
          const [],
      onboardingStatus: json['onboardingStatus']?.toString() ?? 'not_started',
      profileVersion: (json['profileVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toServerPayload() => {
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        'preferredLanguage': preferredLanguage,
        if (longitude != null && latitude != null)
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
        if (address != null) 'address': address!.toJson(),
        if (totalArea != null) 'totalArea': totalArea,
        'totalAreaUnit': totalAreaUnit,
        if (ownership != null) 'ownership': ownership,
        if (soilTypes.isNotEmpty) 'soilTypes': soilTypes,
        if (irrigationSources.isNotEmpty) 'irrigationSources': irrigationSources,
        'experienceYears': experienceYears,
        'onboardingStatus': onboardingStatus,
      };

  Map<String, dynamic> toDraftJson() => {
        'age': age,
        'gender': gender,
        'preferredLanguage': preferredLanguage,
        'latitude': latitude,
        'longitude': longitude,
        'address': address?.toJson(),
        'totalArea': totalArea,
        'totalAreaUnit': totalAreaUnit,
        'ownership': ownership,
        'soilTypes': soilTypes,
        'irrigationSources': irrigationSources,
        'experienceYears': experienceYears,
        'crops': crops.map((c) => c.toJson()).toList(),
        'onboardingStatus': onboardingStatus,
      };

  factory FarmProfile.fromDraftJson(Map<String, dynamic> json) => FarmProfile(
        age: (json['age'] as num?)?.toInt(),
        gender: json['gender']?.toString(),
        preferredLanguage: json['preferredLanguage']?.toString() ?? 'en',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        address: json['address'] != null
            ? FarmAddress.fromJson(Map<String, dynamic>.from(json['address']))
            : null,
        totalArea: (json['totalArea'] as num?)?.toDouble(),
        totalAreaUnit: json['totalAreaUnit']?.toString() ?? 'acre',
        ownership: json['ownership']?.toString(),
        soilTypes: (json['soilTypes'] as List?)?.cast<String>() ?? const [],
        irrigationSources:
            (json['irrigationSources'] as List?)?.cast<String>() ?? const [],
        experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
        crops: (json['crops'] as List?)
                ?.map((c) => CropEntry.fromJson(Map<String, dynamic>.from(c)))
                .toList() ??
            const [],
        onboardingStatus: json['onboardingStatus']?.toString() ?? 'not_started',
      );

  FarmProfile copyWith({
    String? id,
    String? userId,
    int? age,
    String? gender,
    String? preferredLanguage,
    double? latitude,
    double? longitude,
    FarmAddress? address,
    double? totalArea,
    String? totalAreaUnit,
    String? ownership,
    List<String>? soilTypes,
    List<String>? irrigationSources,
    int? experienceYears,
    List<CropEntry>? crops,
    String? onboardingStatus,
    int? profileVersion,
  }) =>
      FarmProfile(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        address: address ?? this.address,
        totalArea: totalArea ?? this.totalArea,
        totalAreaUnit: totalAreaUnit ?? this.totalAreaUnit,
        ownership: ownership ?? this.ownership,
        soilTypes: soilTypes ?? this.soilTypes,
        irrigationSources: irrigationSources ?? this.irrigationSources,
        experienceYears: experienceYears ?? this.experienceYears,
        crops: crops ?? this.crops,
        onboardingStatus: onboardingStatus ?? this.onboardingStatus,
        profileVersion: profileVersion ?? this.profileVersion,
      );
}

class MasterCrop {
  final String id;
  final String name;
  final String? scientificName;
  final int? growingPeriod;
  final String? imageUrl;

  const MasterCrop({
    required this.id,
    required this.name,
    this.scientificName,
    this.growingPeriod,
    this.imageUrl,
  });

  factory MasterCrop.fromJson(Map<String, dynamic> json) => MasterCrop(
        id: json['_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        scientificName: json['scientificName']?.toString(),
        growingPeriod: (json['growingPeriod'] as num?)?.toInt(),
        imageUrl: json['imageUrl']?.toString(),
      );
}
