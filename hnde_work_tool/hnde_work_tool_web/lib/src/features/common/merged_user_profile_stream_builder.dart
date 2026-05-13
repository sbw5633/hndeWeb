import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import '../../constants/firestore_paths.dart';

/// `artifacts/.../users/{uid}` 미러와 `profile/main` 스냅샷을 합쳐 권한·표시 필드를 구합니다.
class MergedUserProfileStreamBuilder extends StatelessWidget {
  const MergedUserProfileStreamBuilder({
    super.key,
    required this.uid,
    required this.builder,
  });

  final String uid;
  final Widget Function(
    BuildContext context,
    Map<String, dynamic> merged,
    bool streamsWaiting,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestorePaths.userMirrorDoc(uid).snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> mSnap,
      ) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirestorePaths.userProfileMainDoc(uid).snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> pSnap,
          ) {
            final Map<String, dynamic> merged =
                FirestorePaths.mergeUserMirrorAndProfileMain(
              mSnap.data?.data(),
              pSnap.data?.data(),
            );
            final bool streamsWaiting =
                mSnap.connectionState == ConnectionState.waiting ||
                    pSnap.connectionState == ConnectionState.waiting;
            return builder(context, merged, streamsWaiting);
          },
        );
      },
    );
  }
}
