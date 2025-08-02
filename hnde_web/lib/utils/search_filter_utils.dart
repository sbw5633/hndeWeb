import '../../models/board_post_model.dart';

class SearchFilterUtils {
  /// 게시글 목록을 검색어와 사업소로 필터링
  static List<BoardPost> filterPosts(
    List<BoardPost> posts, {
    required String searchQuery,
    required String selectedBranch,
  }) {
    return posts.where((post) {
      // 검색 필터 (제목에서 검색)
      final matchesSearch = searchQuery.isEmpty || 
          post.title.toLowerCase().contains(searchQuery.toLowerCase());
      
      // 사업소 필터
      bool matchesBranch;
      if (selectedBranch == '모든 사업소') {
        matchesBranch = true; // 모든 게시글 표시
      } else if (selectedBranch == '전체') {
        matchesBranch = post.targetGroup == '전체'; // "전체" 사업소로 설정된 것만
      } else {
        matchesBranch = post.targetGroup == selectedBranch; // 특정 사업소
      }
      
      return matchesSearch && matchesBranch;
    }).toList();
  }

  /// 일반적인 객체 리스트를 검색어와 필드로 필터링
  static List<T> filterList<T>(
    List<T> items, {
    required String searchQuery,
    required String selectedFilter,
    required String Function(T item) getSearchText,
    required String Function(T item) getFilterValue,
    String defaultFilterValue = '전체',
  }) {
    return items.where((item) {
      // 검색 필터
      final matchesSearch = searchQuery.isEmpty || 
          getSearchText(item).toLowerCase().contains(searchQuery.toLowerCase());
      
      // 필터
      final matchesFilter = selectedFilter == defaultFilterValue || 
          getFilterValue(item) == selectedFilter;
      
      return matchesSearch && matchesFilter;
    }).toList();
  }
} 