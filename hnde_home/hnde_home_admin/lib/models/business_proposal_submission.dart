import 'package:cloud_firestore/cloud_firestore.dart';

// 사업제안 제출 모델 (조회용)
class BusinessProposalSubmission {
  final String id;
  final String companyName;
  final String representative;
  final String email;
  final String phone;
  final String businessType;
  final String proposalTitle;
  final String proposalContent;
  final DateTime createdAt;
  final String? restAreaId; // 사업소 ID

  BusinessProposalSubmission({
    required this.id,
    required this.companyName,
    required this.representative,
    required this.email,
    required this.phone,
    required this.businessType,
    required this.proposalTitle,
    required this.proposalContent,
    required this.createdAt,
    this.restAreaId,
  });

  factory BusinessProposalSubmission.fromFirestore(
      Map<String, dynamic> data, String id) {
    return BusinessProposalSubmission(
      id: id,
      companyName: data['companyName'] as String? ?? '',
      representative: data['representative'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      businessType: data['businessType'] as String? ?? '',
      proposalTitle: data['proposalTitle'] as String? ?? '',
      proposalContent: data['proposalContent'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      restAreaId: data['restAreaId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyName': companyName,
      'representative': representative,
      'email': email,
      'phone': phone,
      'businessType': businessType,
      'proposalTitle': proposalTitle,
      'proposalContent': proposalContent,
      'createdAt': Timestamp.fromDate(createdAt),
      'restAreaId': restAreaId,
    };
  }
}

