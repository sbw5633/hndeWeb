class News {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String imageUrl;
  final String category;

  News({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.imageUrl,
    required this.category,
  });

  static List<News> getDummyData() {
    return [
      News(
        id: '1',
        title: '2024년 신규 프로젝트 착수',
        content: '2024년 상반기 주요 프로젝트가 순차적으로 착수되었습니다.',
        date: DateTime(2024, 7, 15),
        imageUrl: '',
        category: '공지사항',
      ),
      News(
        id: '2',
        title: '신규 사업장 개설 안내',
        content: '더 나은 서비스를 위해 신규 사업장을 개설하였습니다.',
        date: DateTime(2024, 7, 1),
        imageUrl: '',
        category: '공지사항',
      ),
      News(
        id: '3',
        title: '건축 디자인 어워드 수상',
        content: '올해 우수 건축 디자인 어워드에서 대상을 수상하였습니다.',
        date: DateTime(2024, 6, 20),
        imageUrl: '',
        category: '뉴스',
      ),
      News(
        id: '4',
        title: '신입 직원 채용 공고',
        content: '건축 설계 및 인테리어 디자인 분야 신입 직원을 채용합니다.',
        date: DateTime(2024, 6, 10),
        imageUrl: '',
        category: '채용',
      ),
    ];
  }
}
