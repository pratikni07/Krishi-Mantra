class Consultant {
  final int id;
  final String name;
  final double rating;
  final int experience;
  final String photoUrl;
  final String companyLogo;

  Consultant({
    required this.id,
    required this.name,
    required this.rating,
    required this.experience,
    required this.photoUrl,
    required this.companyLogo,
  });

  // Factory constructor for creating a Consultant from JSON
  factory Consultant.fromJson(Map<String, dynamic> json) {
    return Consultant(
      id: json['id'] ?? 0,
      name: json['userName'] ?? '',
      rating: json['rating'].toDouble() ?? 0.0,
      experience: json['experience'] ?? 0,
      photoUrl: json['profilePhotoId'] ?? '',
      companyLogo: json['company']['logo'] ?? '',
    );
  }
}
