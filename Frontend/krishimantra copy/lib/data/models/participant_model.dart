class Participant {
  final String userId;
  final String userName;
  final String profilePhoto;
  final String id;

  Participant({
    required this.userId,
    required this.userName,
    required this.profilePhoto,
    required this.id,
  });

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        userId: json['userId'] ?? '',
        userName: json['userName'] ?? '',
        profilePhoto: json['profilePhoto'] ?? '',
        id: json['_id'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userName': userName,
        'profilePhoto': profilePhoto,
        '_id': id,
      };

  @override
  String toString() {
    return 'Participant(userId: $userId, userName: $userName, profilePhoto: $profilePhoto, id: $id)';
  }
}