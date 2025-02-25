import 'crop.dart';

class Product {
  final String id;
  final String name;
  final String image;
  final String usage;
  final List<Crop> usedFor;

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.usage,
    required this.usedFor,
  });
}