import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/board_post_model.dart';
import write_notice_page.dart';

class NoticePage extends StatelessWidget {
  const NoticePage({super.key});

  Future<List<BoardPost>> fetchNoticeList() async {
    try {
      print('[DEBUG] 공지사항 Firestore 쿼리 시작');
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: 'notice')
          .orderBy('createdAt', descending: true)
          .get();
      print('[DEBUG] 쿼리 결과 docs 개수: ${snapshot.docs.length}');
      return snapshot.docs
          .map((doc) => BoardPost.fromJson(doc.data(), id: doc.id))
          .toList();
    } catch (e, s) {
      print('[ERROR] 공지사항 불러오기 실패: ${e.toString()}');
      print(s);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '공지사항 쓰기',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WriteNoticePage()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<BoardPost>>(
        future: fetchNoticeList(),
        builder: (context, snapshot) {
          print('[DEBUG] FutureBuilder snapshot: hasError=${snapshot.hasError}, hasData=${snapshot.hasData}, connectionState=${snapshot.connectionState}');
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('[ERROR] FutureBuilder error: ${snapshot.error}');
            return Center(child: Text('공지사항을 불러오지 못했습니다.'));
          }
          final notices = snapshot.data ?? <BoardPost>[];
          print('[DEBUG] notices length: ${notices.length}');
          if (notices.isEmpty) {
            return const Center(child: Text('등록된 공지사항이 없습니다.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24.0),
            itemCount: notices.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, idx) {
              final notice = notices[idx];
              final createdAt = notice.createdAt;
              final targetGroup = notice.targetGroup;
              
              String formatDate(DateTime date) {
                return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
              }
              
              String formatTime(DateTime date) {
                return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
              }
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 태그
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: targetGroup == BusinessLocation.all ? Colors.blue.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: targetGroup == BusinessLocation.all ? Colors.blue.shade300 : Colors.green.shade300,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        '[${targetGroup.displayName}]',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: targetGroup == BusinessLocation.all ? Colors.blue.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    // 제목과 작성자 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 제목
                          Text(
                            notice.title,
                            style: const TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8.0),
                          // 작성자명과 시간
                          Row(
                            children: [
                              Text(
                                notice.authorName,
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                '${formatDate(createdAt)} ${formatTime(createdAt)}',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                onTap: () {
                  // TODO: 상세페이지 이동 구현 예정
                  // Navigator.push(...)
                },
              );
            },
          );
        },
      ),
    );
  }
} 