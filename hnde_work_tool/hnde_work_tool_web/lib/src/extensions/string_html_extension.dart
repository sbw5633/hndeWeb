/// TourAPI 등에서 내려오는 HTML 조각 제거
extension StringHtmlExtension on String {
  static final RegExp _htmlTag = RegExp(r'<[^>]*>');

  String stripHtml() {
    return replaceAll(_htmlTag, '').replaceAll('&nbsp;', ' ').trim();
  }
}
