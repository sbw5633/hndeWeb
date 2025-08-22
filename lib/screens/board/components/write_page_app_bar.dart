import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/page_state_provider.dart';

class WritePageAppBar extends AppBar {
  WritePageAppBar({
    super.key,
    required String type,
  }) : super(
          title: Text(type == 'dataRequest' ? '자료요청' : '게시글 작성'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            Consumer<PageStateProvider>(
              builder: (context, pageState, _) {
                final submitCallback = pageState.executeSubmitFormCallback;
                final hasContent = pageState.hasUnsavedChanges;
                
                return TextButton(
                  onPressed: hasContent ? submitCallback : null,
                  child: Text(
                    '등록',
                    style: TextStyle(
                      color: hasContent 
                          ? Colors.blue 
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        );
}

