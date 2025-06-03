class FamilyMember {
  final String id;
  final String fullName;
  final String gender;
  final String? fatherId;
  final String? motherId;
  final bool isInLaw;


  FamilyMember({
    required this.id,
    required this.fullName,
    required this.gender,
    this.fatherId,
    this.motherId,
    this.isInLaw = false,
  });

  factory FamilyMember.fromMap(String id, Map<String, dynamic> data) {
    return FamilyMember(
      id: id,
      fullName: data['fullName'] ?? '',
      gender: data['gender'] ?? '',
      fatherId: data['fatherId'],
      motherId: data['motherId'],
      isInLaw: data['isInLaw'] ?? false,
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
}
