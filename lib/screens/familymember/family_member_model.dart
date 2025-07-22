class FamilyMember {
  final String id;
  final String fullName;
  final String? nickname;
  final String? birthDate;
  final String gender;
  final String? fatherId;
  final String? motherId;
  final bool isInLaw;
  final String? spouseId;
  final String? profileImageUrl;


  FamilyMember({
    required this.id,
    required this.fullName,
    required this.gender,
    this.nickname,
    this.birthDate,
    this.fatherId,
    this.motherId,
    this.isInLaw = false,
    this.spouseId,
    this.profileImageUrl,
  });

  factory FamilyMember.fromMap(String id, Map<String, dynamic> data) {
    return FamilyMember(
      id: id,
      fullName: data['fullName'] ?? '',
      gender: data['gender'] ?? '',
      nickname: data['nickname'],
      birthDate: data['birthDate'],
      fatherId: data['fatherId'],
      motherId: data['motherId'],
      isInLaw: data['isInLaw'] ?? false,
      spouseId: data['spouseId'],
      profileImageUrl: data['profileImageUrl'],
    );
  }

  /// 👉 Method untuk buat objek kosong
  static FamilyMember empty() {
    return FamilyMember(
      id: '',
      fullName: '',
      gender: '',
      fatherId: '',
      motherId: '',
      isInLaw: false,
    );
  }

  String get initials {
    List<String> parts = fullName.split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0].toUpperCase()}${parts[parts.length - 1][0].toUpperCase()}';
  }
}
