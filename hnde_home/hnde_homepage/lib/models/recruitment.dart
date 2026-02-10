import 'package:cloud_firestore/cloud_firestore.dart';

// 인재채용 모델
class Recruitment {
  final String id;
  final String? topImageUrl; // 상단 이미지
  final RecruitmentSection? jobOpenings; // 채용공고 섹션
  final RecruitmentSection? applicationMethod; // 지원방법
  final RecruitmentSection? process; // 전형절차

  Recruitment({
    required this.id,
    this.topImageUrl,
    this.jobOpenings,
    this.applicationMethod,
    this.process,
  });

  factory Recruitment.fromJson(Map<String, dynamic> json) {
    return Recruitment(
      id: json['id'] as String,
      topImageUrl: json['topImageUrl'] as String?,
      jobOpenings: json['jobOpenings'] != null
          ? RecruitmentSection.fromJson(
              json['jobOpenings'] as Map<String, dynamic>)
          : null,
      applicationMethod: json['applicationMethod'] != null
          ? RecruitmentSection.fromJson(
              json['applicationMethod'] as Map<String, dynamic>)
          : null,
      process: json['process'] != null
          ? RecruitmentSection.fromJson(
              json['process'] as Map<String, dynamic>)
          : null,
    );
  }

  factory Recruitment.fromFirestore(Map<String, dynamic> data, String id) {
    return Recruitment(
      id: id,
      topImageUrl: data['topImageUrl'] as String?,
      jobOpenings: data['jobOpenings'] != null
          ? RecruitmentSection.fromFirestore(
              data['jobOpenings'] as Map<String, dynamic>)
          : null,
      applicationMethod: data['applicationMethod'] != null
          ? RecruitmentSection.fromFirestore(
              data['applicationMethod'] as Map<String, dynamic>)
          : null,
      process: data['process'] != null
          ? RecruitmentSection.fromFirestore(
              data['process'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topImageUrl': topImageUrl,
      'jobOpenings': jobOpenings?.toJson(),
      'applicationMethod': applicationMethod?.toJson(),
      'process': process?.toJson(),
    };
  }

  static Recruitment getDummyData() {
    return Recruitment(
      id: 'recruitment_main',
      topImageUrl: null,
      jobOpenings: null,
      applicationMethod: null,
      process: null,
    );
  }
}

class JobOpening {
  final String id;
  final String title;
  final String department;
  final String location;
  final DateTime deadline;

  JobOpening({
    required this.id,
    required this.title,
    required this.department,
    required this.location,
    required this.deadline,
  });

  factory JobOpening.fromJson(Map<String, dynamic> json) {
    return JobOpening(
      id: json['id'] as String,
      title: json['title'] as String,
      department: json['department'] as String,
      location: json['location'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
    );
  }

  factory JobOpening.fromFirestore(Map<String, dynamic> data) {
    return JobOpening(
      id: data['id'] as String? ?? '',
      title: data['title'] as String,
      department: data['department'] as String,
      location: data['location'] as String,
      deadline: (data['deadline'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'department': department,
      'location': location,
      'deadline': deadline.toIso8601String(),
    };
  }
}

class RecruitmentSection {
  final String title;
  final String? imageUrl; // 이미지 (선택사항)
  final String? content; // 텍스트 내용 (선택사항)

  RecruitmentSection({
    required this.title,
    this.imageUrl,
    this.content,
  });

  factory RecruitmentSection.fromJson(Map<String, dynamic> json) {
    return RecruitmentSection(
      title: json['title'] as String,
      imageUrl: json['imageUrl'] as String?,
      content: json['content'] as String?,
    );
  }

  factory RecruitmentSection.fromFirestore(Map<String, dynamic> data) {
    return RecruitmentSection(
      title: data['title'] as String,
      imageUrl: data['imageUrl'] as String?,
      content: data['content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'content': content,
    };
  }
}
