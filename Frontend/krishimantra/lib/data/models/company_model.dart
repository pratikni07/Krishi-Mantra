// company_model.dart
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

  Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
  });

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

  Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

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

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.usage,
    required this.company,
    required this.usedFor,
  });

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
