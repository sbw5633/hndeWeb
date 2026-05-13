// 고객의 이야기 제출 모델
class CustomerStorySubmission {
  final String name;
  final String email;
  final String? phone;
  final String title;
  final String content;

  CustomerStorySubmission({
    required this.name,
    required this.email,
    this.phone,
    required this.title,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'title': title,
      'content': content,
    };
  }

  factory CustomerStorySubmission.fromJson(Map<String, dynamic> json) {
    return CustomerStorySubmission(
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      title: json['title'] as String,
      content: json['content'] as String,
    );
  }
}

