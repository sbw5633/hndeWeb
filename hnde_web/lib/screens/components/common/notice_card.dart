import 'package:flutter/material.dart';

class NoticeCard extends StatelessWidget {
  final String title;
  final String summary;
  final VoidCallback? onDetail;
  final VoidCallback? onTap;
  final bool isDataRequest;
  
  const NoticeCard({
    required this.title, 
    required this.summary, 
    this.onDetail,
    this.onTap,
    this.isDataRequest = false,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDataRequest 
                  ? [Colors.green.shade50, Colors.green.shade100]
                  : [Colors.blue.shade50, Colors.blue.shade100],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    isDataRequest ? Icons.file_present : Icons.announcement,
                    color: isDataRequest ? Colors.green.shade600 : Colors.blue.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title.length > 10 
                          ? '${title.substring(0, 10)}...' 
                          : title, 
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        color: isDataRequest ? Colors.green.shade800 : Colors.blue.shade800
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary, 
                style: TextStyle(
                  fontSize: 14, 
                  color: isDataRequest ? Colors.green.shade700 : Colors.blue.shade700,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
             
            ],
          ),
        ),
      ),
    );
  }
} 