// company_model.dart
import '../services/language_service.dart';

class CompanyModel {
  final String id;
  final String name;
  final String logo;
  final double rating;
  final String? email;
  final String? phone;
  final String? website;
  final String? description;
  final Address? address;
  final List<Review>? reviews;
  final List<Product>? products;

  // Cached translations
  String? _translatedName;
  String? _translatedDescription;

  CompanyModel({
    required this.id,
    required this.name,
    required this.logo,
    required this.rating,
    this.email,
    this.phone,
    this.website,
    this.description,
    this.address,
    this.reviews,
    this.products,
  });

  // Get translated name
  Future<String> getTranslatedName() async {
    if (_translatedName != null) return _translatedName!;
    
    final languageService = await LanguageService.getInstance();
    _translatedName = await languageService.translate(name);
    return _translatedName!;
  }

  // Get translated description
  Future<String?> getTranslatedDescription() async {
    if (description == null) return null;
    if (_translatedDescription != null) return _translatedDescription!;
    
    final languageService = await LanguageService.getInstance();
    _translatedDescription = await languageService.translate(description!);
    return _translatedDescription!;
  }

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['_id'],
      name: json['name'],
      logo: json['logo'],
      rating: json['rating']?.toDouble() ?? 0.0,
      email: json['email'],
      phone: json['phone'],
      website: json['website'],
      description: json['description'],
      address: json['address'] != null ? Address.fromJson(json['address']) : null,
      reviews: json['reviews'] != null
          ? List<Review>.from(json['reviews'].map((x) => Review.fromJson(x)))
          : null,
      products: json['products'] != null
          ? List<Product>.from(json['products'].map((x) => Product.fromJson(x)))
          : null,
    );
  }
}

class Address {
  final String street;
  final String city;
  final String state;
  final String zip;

  // Cached translations
  String? _translatedStreet;
  String? _translatedCity;
  String? _translatedState;

  Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
  });

  // Get translated street
  Future<String> getTranslatedStreet() async {
    if (_translatedStreet != null) return _translatedStreet!;
    
    final languageService = await LanguageService.getInstance();
    _translatedStreet = await languageService.translate(street);
    return _translatedStreet!;
  }

  // Get translated city
  Future<String> getTranslatedCity() async {
    if (_translatedCity != null) return _translatedCity!;
    
    final languageService = await LanguageService.getInstance();
    _translatedCity = await languageService.translate(city);
    return _translatedCity!;
  }

  // Get translated state
  Future<String> getTranslatedState() async {
    if (_translatedState != null) return _translatedState!;
    
    final languageService = await LanguageService.getInstance();
    _translatedState = await languageService.translate(state);
    return _translatedState!;
  }

  // Get full translated address
  Future<String> getTranslatedFullAddress() async {
    final translatedStreet = await getTranslatedStreet();
    final translatedCity = await getTranslatedCity();
    final translatedState = await getTranslatedState();
    
    return '$translatedStreet, $translatedCity, $translatedState, $zip';
  }

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'],
      city: json['city'],
      state: json['state'],
      zip: json['zip'],
    );
  }
}

class Review {
  final String id;
  final int rating;
  final String comment;
  final DateTime createdAt;

  // Cached translation
  String? _translatedComment;

  Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  // Get translated comment
  Future<String> getTranslatedComment() async {
    if (_translatedComment != null) return _translatedComment!;
    
    final languageService = await LanguageService.getInstance();
    _translatedComment = await languageService.translate(comment);
    return _translatedComment!;
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['_id'],
      rating: json['rating'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class Product {
  final String id;
  final String name;
  final String image;
  final String usage;
  final String company;
  final String usedFor;

  // Cached translations
  String? _translatedName;
  String? _translatedUsage;
  String? _translatedUsedFor;

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.usage,
    required this.company,
    required this.usedFor,
  });

  // Get translated name
  Future<String> getTranslatedName() async {
    if (_translatedName != null) return _translatedName!;
    
    final languageService = await LanguageService.getInstance();
    _translatedName = await languageService.translate(name);
    return _translatedName!;
  }

  // Get translated usage
  Future<String> getTranslatedUsage() async {
    if (_translatedUsage != null) return _translatedUsage!;
    
    final languageService = await LanguageService.getInstance();
    _translatedUsage = await languageService.translate(usage);
    return _translatedUsage!;
  }

  // Get translated usedFor
  Future<String> getTranslatedUsedFor() async {
    if (_translatedUsedFor != null) return _translatedUsedFor!;
    
    final languageService = await LanguageService.getInstance();
    _translatedUsedFor = await languageService.translate(usedFor);
    return _translatedUsedFor!;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'],
      name: json['name'],
      image: json['image'],
      usage: json['usage'],
      company: json['company'],
      usedFor: json['usedFor'],
    );
  }
}
