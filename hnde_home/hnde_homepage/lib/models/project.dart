class Project {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String category;
  final String location;
  final DateTime completedDate;
  final List<String> tags;

  Project({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.location,
    required this.completedDate,
    required this.tags,
  });

  static List<Project> getDummyData() {
    return [
      Project(
        id: '1',
        title: '강남 오피스 리모델링',
        description: '모던한 오피스 공간으로 새롭게 재탄생',
        imageUrl: '',
        category: '리모델링',
        location: '서울시 강남구',
        completedDate: DateTime(2024, 1, 15),
        tags: ['오피스', '리모델링', '인테리어'],
      ),
      Project(
        id: '2',
        title: '주거 단지 설계',
        description: '편리하고 쾌적한 주거 환경을 제공하는 단지 설계',
        imageUrl: '',
        category: '건축 설계',
        location: '경기도 성남시',
        completedDate: DateTime(2024, 3, 20),
        tags: ['주거', '설계', '단지'],
      ),
      Project(
        id: '3',
        title: '상업시설 인테리어',
        description: '고객 경험을 극대화하는 상업 공간 디자인',
        imageUrl: '',
        category: '인테리어',
        location: '서울시 강동구',
        completedDate: DateTime(2024, 5, 10),
        tags: ['상업', '인테리어', '디자인'],
      ),
      Project(
        id: '4',
        title: '공공 건축 프로젝트',
        description: '지역사회를 위한 공공 건축 프로젝트',
        imageUrl: '',
        category: '공공 건축',
        location: '인천시 남동구',
        completedDate: DateTime(2024, 6, 30),
        tags: ['공공', '건축', '프로젝트'],
      ),
    ];
  }
}
