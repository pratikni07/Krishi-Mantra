class Company {
  final String id;
  final String name;
  final String logo;
  final double rating;

  Company({
    required this.id,
    required this.name,
    required this.logo,
    required this.rating,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['_id'],
      name: json['name'],
      logo: json['logo'],
      rating: json['rating'].toDouble(),
    );
  }
}

// models/modal.dart
class CompanyById {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String website;
  final String description;
  final String logo;
  final double rating;
  final List<Review> reviews;
  final List<Product> products;
  final Address address;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyById({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.website,
    required this.description,
    required this.logo,
    required this.rating,
    required this.reviews,
    required this.products,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyById.fromJson(Map<String, dynamic> json) {
    return CompanyById(
      id: json['_id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      website: json['website'],
      description: json['description'],
      logo: json['logo'],
      rating: json['rating'].toDouble(),
      reviews: (json['reviews'] as List)
          .map((review) => Review.fromJson(review))
          .toList(),
      products: (json['products'] as List)
          .map((product) => Product.fromJson(product))
          .toList(),
      address: Address.fromJson(json['address']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
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
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.usage,
    required this.company,
    required this.usedFor,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['_id'],
      name: json['name'],
      image: json['image'],
      usage: json['usage'],
      company: json['company'],
      usedFor: json['usedFor'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class Review {
  final String id;
  final double rating;
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
      rating: json['rating'].toDouble(),
      comment: json['comment'],
      createdAt: DateTime.parse(json['createdAt']),
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
