class Service {
  final String id;
  final String title;
  final String description;
  final String icon;
  final List<String> features;

  Service({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.features,
  });

  static List<Service> getDummyData() {
    return [
      Service(
        id: '1',
        title: '인테리어 디자인',
        description: '혁신적인 디자인으로 공간의 가치를 높입니다.',
        icon: 'design',
        features: [
          '주거 공간 디자인',
          '상업 공간 디자인',
          '공공 건축 디자인',
        ],
      ),
      Service(
        id: '2',
        title: '건축 설계',
        description: '안전하고 효율적인 건축 설계 서비스를 제공합니다.',
        icon: 'architecture',
        features: [
          '주거 건축 설계',
          '상업 건축 설계',
          '리모델링 설계',
        ],
      ),
      Service(
        id: '3',
        title: '시공 관리',
        description: '전문적인 시공 관리로 완벽한 품질을 보장합니다.',
        icon: 'construction',
        features: [
          '프로젝트 관리',
          '품질 관리',
          '일정 관리',
        ],
      ),
      Service(
        id: '4',
        title: '컨설팅',
        description: '건축 및 인테리어 전문 컨설팅 서비스를 제공합니다.',
        icon: 'consulting',
        features: [
          '사전 컨설팅',
          '설계 검토',
          '시공 감리',
        ],
      ),
    ];
  }
}
