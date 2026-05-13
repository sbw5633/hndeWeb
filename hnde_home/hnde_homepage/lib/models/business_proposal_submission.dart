// 사업제안 제출 모델
class BusinessProposalSubmission {
  final String companyName;
  final String representative;
  final String email;
  final String phone;
  final String businessType;
  final String proposalTitle;
  final String proposalContent;

  BusinessProposalSubmission({
    required this.companyName,
    required this.representative,
    required this.email,
    required this.phone,
    required this.businessType,
    required this.proposalTitle,
    required this.proposalContent,
  });

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'representative': representative,
      'email': email,
      'phone': phone,
      'businessType': businessType,
      'proposalTitle': proposalTitle,
      'proposalContent': proposalContent,
    };
  }

  factory BusinessProposalSubmission.fromJson(Map<String, dynamic> json) {
    return BusinessProposalSubmission(
      companyName: json['companyName'] as String,
      representative: json['representative'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      businessType: json['businessType'] as String,
      proposalTitle: json['proposalTitle'] as String,
      proposalContent: json['proposalContent'] as String,
    );
  }
}

