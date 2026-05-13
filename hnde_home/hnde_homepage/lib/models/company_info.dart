class CompanyInfo {
  final String name;
  final String logoUrl;
  final String description;
  final String vision;
  final String mission;
  final Map<String, String> contact;

  CompanyInfo({
    required this.name,
    required this.logoUrl,
    required this.description,
    required this.vision,
    required this.mission,
    required this.contact,
  });

  static CompanyInfo getDummyData() {
    return CompanyInfo(
      name: 'H&DE',
      logoUrl: '',
      description: '㈜에이치앤디이는 고객과 함께 성장하는 신뢰받는 기업입니다.',
      vision: '글로벌 시장에서 신뢰받는 선도 기업이 되겠습니다.',
      mission: '고객 가치 창조를 통해 지속가능한 성장을 실현합니다.',
      contact: {
        'address': '서울특별시 강남구 테헤란로 123',
        'phone': '02-1234-5678',
        'email': 'info@hnde.co.kr',
        'fax': '02-1234-5679',
      },
    );
  }
}
