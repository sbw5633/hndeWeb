import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/content_provider.dart';
import '../../core/file_upload_service.dart';
import '../../models/recruitment.dart';
import 'recruitment_edit_dialog.dart';

class RecruitmentPage extends ConsumerStatefulWidget {
  const RecruitmentPage({super.key});

  @override
  ConsumerState<RecruitmentPage> createState() => _RecruitmentPageState();
}

class _RecruitmentPageState extends ConsumerState<RecruitmentPage> {
  String? _topImageUrl;

  Future<void> _loadData() async {
    final asyncValue = ref.read(recruitmentProvider);
    asyncValue.whenData((recruitment) {
      if (recruitment != null) {
        _topImageUrl = recruitment.topImageUrl;
        setState(() {});
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          _topImageUrl = uploadService.getViewUrl(result['view_url']);
        });
        await _saveImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 업로드 실패: $e')),
        );
      }
    }
  }

  Future<void> _saveImage() async {
    final asyncRecruitment = ref.read(recruitmentProvider);
    final recruitment = await asyncRecruitment.value;
    
    final currentRecruitment = recruitment ?? Recruitment(
      id: 'main',
      topImageUrl: null,
      jobOpenings: null,
      applicationMethod: null,
      process: null,
    );

    final updated = Recruitment(
      id: currentRecruitment.id,
      topImageUrl: _topImageUrl,
      jobOpenings: currentRecruitment.jobOpenings,
      applicationMethod: currentRecruitment.applicationMethod,
      process: currentRecruitment.process,
    );
    await ref.read(recruitmentControllerProvider).save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final asyncRecruitment = ref.watch(recruitmentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('인재채용 관리')),
      body: asyncRecruitment.when(
        data: (recruitment) {
          // 데이터가 없으면 기본값 생성
          final displayRecruitment = recruitment ?? Recruitment(
            id: 'main',
            topImageUrl: null,
            jobOpenings: null,
            applicationMethod: null,
            process: null,
          );
          
          if (_topImageUrl == null && displayRecruitment.topImageUrl != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('상단 이미지', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: (_topImageUrl ?? displayRecruitment.topImageUrl) != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _topImageUrl ?? displayRecruitment.topImageUrl!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white),
                                  onPressed: () async {
                                    setState(() => _topImageUrl = null);
                                    await _saveImage();
                                  },
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 48),
                                SizedBox(height: 8),
                                Text('이미지 선택'),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('채용공고', style: TextStyle(fontSize: 18)),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showSectionDialog(
                                context,
                                ref,
                                displayRecruitment,
                                displayRecruitment.jobOpenings ??
                                    RecruitmentSection(title: '채용공고'),
                                '채용공고',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (displayRecruitment.jobOpenings == null ||
                            (displayRecruitment.jobOpenings!.content == null ||
                                displayRecruitment.jobOpenings!.content!.isEmpty) &&
                                (displayRecruitment.jobOpenings!.imageUrl == null ||
                                    displayRecruitment.jobOpenings!.imageUrl!.isEmpty))
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('등록된 채용공고가 없습니다.'),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (displayRecruitment.jobOpenings!.imageUrl != null &&
                                  displayRecruitment.jobOpenings!.imageUrl!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Image.network(
                                    displayRecruitment.jobOpenings!.imageUrl!,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              if (displayRecruitment.jobOpenings!.content != null &&
                                  displayRecruitment.jobOpenings!.content!.isNotEmpty)
                                Text(displayRecruitment.jobOpenings!.content!),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('지원방법',
                                style: TextStyle(fontSize: 18)),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showSectionDialog(
                                context,
                                ref,
                                displayRecruitment,
                                displayRecruitment.applicationMethod ??
                                    RecruitmentSection(title: '지원방법'),
                                '지원방법',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (displayRecruitment.applicationMethod == null ||
                            ((displayRecruitment.applicationMethod!.content == null ||
                                displayRecruitment.applicationMethod!.content!.isEmpty) &&
                                (displayRecruitment.applicationMethod!.imageUrl == null ||
                                    displayRecruitment.applicationMethod!.imageUrl!.isEmpty)))
                          const Text('등록된 내용이 없습니다.')
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (displayRecruitment.applicationMethod!.imageUrl != null &&
                                  displayRecruitment.applicationMethod!.imageUrl!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Image.network(
                                    displayRecruitment.applicationMethod!.imageUrl!,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              if (displayRecruitment.applicationMethod!.content != null &&
                                  displayRecruitment.applicationMethod!.content!.isNotEmpty)
                                Text(displayRecruitment.applicationMethod!.content!),
                            ],
                          ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('전형절차',
                                      style: TextStyle(fontSize: 18)),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showSectionDialog(
                                      context,
                                      ref,
                                      displayRecruitment,
                                      displayRecruitment.process ??
                                          RecruitmentSection(title: '전형절차'),
                                      '전형절차',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (displayRecruitment.process == null ||
                                  ((displayRecruitment.process!.content == null ||
                                      displayRecruitment.process!.content!.isEmpty) &&
                                      (displayRecruitment.process!.imageUrl == null ||
                                          displayRecruitment.process!.imageUrl!.isEmpty)))
                                const Text('등록된 내용이 없습니다.')
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (displayRecruitment.process!.imageUrl != null &&
                                        displayRecruitment.process!.imageUrl!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Image.network(
                                          displayRecruitment.process!.imageUrl!,
                                          height: 150,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    if (displayRecruitment.process!.content != null &&
                                        displayRecruitment.process!.content!.isNotEmpty)
                                      Text(displayRecruitment.process!.content!),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류: $err')),
      ),
    );
  }

  void _showSectionDialog(BuildContext context, WidgetRef ref,
      Recruitment recruitment, RecruitmentSection section, String title) {
    showDialog(
      context: context,
      builder: (_) => RecruitmentSectionEditDialog(
        title: title,
        initialSection: section,
        onSave: (newSection) async {
          final updated = Recruitment(
            id: recruitment.id,
            topImageUrl: recruitment.topImageUrl,
            jobOpenings:
                title == '채용공고' ? newSection : recruitment.jobOpenings,
            applicationMethod:
                title == '지원방법' ? newSection : recruitment.applicationMethod,
            process: title == '전형절차' ? newSection : recruitment.process,
          );
          await ref.read(recruitmentControllerProvider).save(updated);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

