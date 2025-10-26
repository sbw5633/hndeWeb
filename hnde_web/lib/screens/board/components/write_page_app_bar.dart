import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/page_state_provider.dart';

class WritePageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String type;
  
  const WritePageAppBar({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                type == 'dataRequest' 
                    ? Icons.file_present
                    : type == 'notice'
                        ? Icons.campaign
                        : type == 'anonymousBoard'
                            ? Icons.visibility_off
                            : Icons.article,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    type == 'dataRequest' 
                        ? '자료요청 작성'
                        : type == 'notice'
                            ? '공지사항 작성'
                            : type == 'anonymousBoard'
                                ? '익명 게시글 작성'
                                : '게시글 작성',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '내용을 작성하고 등록해주세요',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<PageStateProvider>(
            builder: (context, pageState, _) {
              final submitCallback = pageState.executeSubmitFormCallback;
              final hasContent = pageState.hasUnsavedChanges;
              
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: ElevatedButton(
                  onPressed: hasContent ? submitCallback : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasContent ? Colors.white : Colors.white.withOpacity(0.3),
                    foregroundColor: hasContent ? Colors.blue.shade600 : Colors.white.withOpacity(0.7),
                    elevation: hasContent ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: Text(
                    '등록',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: hasContent ? Colors.blue.shade600 : Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

