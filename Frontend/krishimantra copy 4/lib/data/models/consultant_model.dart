class Company {
  final String name;
  final String logo;

  Company({
    required this.name,
    required this.logo,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      name: json['name'] ?? '',
      logo: json['logo'] ?? '',
    );
  }
}

class Consultant {
  final String id;
  final String userName;
  final String profilePhotoId;
  final int experience;
  final double rating;
  final Company company;

  Consultant({
    required this.id,
    required this.userName,
    required this.profilePhotoId,
    required this.experience,
    required this.rating,
    required this.company,
  });

  factory Consultant.fromJson(Map<String, dynamic> json) {
    return Consultant(
      id: json['_id'] ?? '',
      userName: json['userName'] ?? '',
      profilePhotoId: json['profilePhotoId'] ?? '',
      experience: json['experience'] ?? 0,
      rating: json['rating']?.toDouble() ?? 0.0,
      company: Company.fromJson(json['company'] ?? {}),
    );
  }
}
