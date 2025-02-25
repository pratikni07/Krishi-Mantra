// models/company.dart
import 'product.dart';
import 'address.dart';

class Company {
  final String id;
  final String name;
  final String email;
  final Address address;
  final String phone;
  final String website;
  final String description;
  final String logo;
  final double rating;
  final List<Product> products;

  Company({
    required this.id,
    required this.name,
    required this.email,
    required this.address,
    required this.phone,
    required this.website,
    required this.description,
    required this.logo,
    required this.rating,
    required this.products,
  });
}