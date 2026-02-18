import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/firestore_service.dart';
// import '../core/migration_service.dart'; // 마이그레이션 완료로 주석처리

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final Function(double opacity)? onHomePageOpacity;
  final Function(double opacity)? onSplashOpacity;

  const SplashScreen({
    super.key,
    required this.onComplete,
    this.onHomePageOpacity,
    this.onSplashOpacity,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fillController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _homePageOpacity;
  String? _logoUrl;
  bool _logoLoaded = false;
  bool _animationStarted = false;
  // bool _isMigrating = false;
  // String? _migrationMessage;
  
  static const double _splashLogoSize = 200.0;

  // 개발 환경 확인 (마이그레이션용 - 주석처리)
  // bool get _isDevEnv {
  //   const firebaseEnv = String.fromEnvironment('FIREBASE_ENV', defaultValue: 'dev');
  //   return firebaseEnv.toLowerCase() != 'prod';
  // }

  @override
  void initState() {
    super.initState();
    
    // 채우기 애니메이션 컨트롤러 초기화 (0→1로 부드럽게)
    _fillController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    // 페이드아웃 및 홈페이지 페이드인 애니메이션 컨트롤러 초기화
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    // 스플래시 화면 페이드아웃 애니메이션
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // 홈페이지 페이드인 애니메이션
    _homePageOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // 홈페이지 페이드인 콜백 리스너
    _homePageOpacity.addListener(() {
      if (mounted) {
        widget.onHomePageOpacity?.call(_homePageOpacity.value);
      }
    });

    // 스플래시 페이드아웃 콜백 리스너
    _fadeAnimation.addListener(() {
      if (mounted) {
        widget.onSplashOpacity?.call(_fadeAnimation.value);
      }
    });
    
    // 첫 프레임 후 로고 로드 (context 사용 가능)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLogo();
      }
    });
  }

  Future<void> _loadLogo() async {
    try {
      // Firestore에서 직접 topLogoUrl 필드만 빠르게 가져오기
      final firestoreService = FirestoreService();
      final doc = await firestoreService.getDocument(
        FirestoreCollections.homePage,
        'main',
        forceRefresh: false,
      );
      
      if (!mounted) return;
      
      final logoUrl = doc?['topLogoUrl'] as String?;
      
      // 이미지가 있는 경우 완전히 로딩될 때까지 대기
      if (logoUrl != null && logoUrl.isNotEmpty) {
        try {
          // 이미지를 메모리에 완전히 로딩
          final imageProvider = CachedNetworkImageProvider(logoUrl);
          await precacheImage(imageProvider, context);
        } catch (e) {
          // 프리캐시 실패 시에도 애니메이션은 진행 (텍스트 로고 fallback 가능)
        }
      }
      
      // 로고 URL이 없어도 로딩 완료로 표시
      if (mounted) {
        setState(() {
          _logoUrl = logoUrl;
          _logoLoaded = true;
        });
        // 로고 로딩이 끝나면 즉시 애니메이션 시작
        _startAnimation();
      }
    } catch (e) {
      // 오류가 발생해도 로딩 완료로 표시
      if (mounted) {
        setState(() {
          _logoLoaded = true;
        });
        // 로딩 실패해도 텍스트 로고로 애니메이션 진행
        _startAnimation();
      }
    }
  }

  // 마이그레이션 실행 (주석처리)
  // Future<void> _runMigration() async {
  //   if (_isMigrating) return;
  //   
  //   setState(() {
  //     _isMigrating = true;
  //     _migrationMessage = '마이그레이션 시작...';
  //   });

  //   try {
  //     await migrateHistoryData();
  //     
  //     if (mounted) {
  //       setState(() {
  //         _migrationMessage = '✅ 마이그레이션 완료!';
  //         _isMigrating = false;
  //       });
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() {
  //         _migrationMessage = '❌ 마이그레이션 실패: $e';
  //         _isMigrating = false;
  //       });
  //     }
  //   }
  // }


  void _startFillAnimation() {
    if (!mounted) return;
    
    // 채우기 애니메이션 리셋 후 시작
    _fillController.reset();
    _fillController.forward().then((_) {
      if (!mounted) return;
      
      // 채우기 완료 후 약간의 딜레이
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        
        // 홈페이지를 먼저 표시 시작 (opacity 0으로, 페이드아웃과 동시에 페이드인)
        widget.onHomePageOpacity?.call(0.0);
        
        // 페이드아웃과 홈페이지 페이드인 동시에 시작
        _fadeController.reset();
        _fadeController.forward().then((_) {
          if (!mounted) return;
          
          // 페이드아웃 완료 후 홈페이지 표시
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              widget.onComplete();
            }
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _fillController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startAnimation() {
    if (_animationStarted) return;
    setState(() {
      _animationStarted = true;
    });
    _startFillAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 로고 애니메이션
          AnimatedBuilder(
            animation: _fillController,
            builder: (context, child) {
              final widthFactor = _fillController.value;
              
              // 애니메이션 시작 전에는 아무것도 표시하지 않음
              if (!_animationStarted) {
                return const SizedBox.shrink();
              }
              
              return Center(
                child: _buildLogo(widthFactor),
              );
            },
          ),
          // 로딩 중일 때 인디케이터 표시
          if (!_logoLoaded)
            const Center(
              child: CircularProgressIndicator(),
            ),
          
          // 개발 환경일 때 마이그레이션 버튼 (주석처리)
          // if (_isDevEnv && _logoLoaded && !_animationStarted)
          //   Positioned(
          //     bottom: 100,
          //     left: 0,
          //     right: 0,
          //     child: Column(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         if (_migrationMessage != null)
          //           Padding(
          //             padding: const EdgeInsets.only(bottom: 16),
          //             child: Text(
          //               _migrationMessage!,
          //               style: TextStyle(
          //                 fontSize: 16,
          //                 fontWeight: FontWeight.bold,
          //                 color: _migrationMessage!.startsWith('✅')
          //                     ? Colors.green
          //                     : _migrationMessage!.startsWith('❌')
          //                         ? Colors.red
          //                         : Colors.blue[900],
          //               ),
          //             ),
          //           ),
          //         ElevatedButton(
          //           onPressed: _isMigrating ? null : _runMigration,
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Colors.orange,
          //             foregroundColor: Colors.white,
          //             padding: const EdgeInsets.symmetric(
          //               horizontal: 32,
          //               vertical: 16,
          //             ),
          //           ),
          //           child: _isMigrating
          //               ? const SizedBox(
          //                   width: 20,
          //                   height: 20,
          //                   child: CircularProgressIndicator(
          //                     strokeWidth: 2,
          //                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          //                   ),
          //                 )
          //               : const Text(
          //                   '마이그레이션',
          //                   style: TextStyle(
          //                     fontSize: 18,
          //                     fontWeight: FontWeight.bold,
          //                   ),
          //                 ),
          //         ),
          //         const SizedBox(height: 16),
          //         ElevatedButton(
          //           onPressed: _startAnimation,
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Colors.blue[900],
          //             foregroundColor: Colors.white,
          //             padding: const EdgeInsets.symmetric(
          //               horizontal: 32,
          //               vertical: 16,
          //             ),
          //           ),
          //           child: const Text(
          //             '홈페이지로 이동',
          //             style: TextStyle(
          //               fontSize: 18,
          //               fontWeight: FontWeight.bold,
          //             ),
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
        ],
      ),
    );
  }

  Widget _buildLogo(double widthFactor) {
    if (!_logoLoaded) {
      return const SizedBox(
        width: _splashLogoSize,
        height: _splashLogoSize,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_logoUrl == null || _logoUrl!.isEmpty) {
      return _buildTextLogo(widthFactor);
    }

    // widthFactor가 0이면 아예 그리지 않음 (초기 "띡" 방지)
    if (widthFactor <= 0.001) {
      return const SizedBox(
        width: _splashLogoSize,
        height: _splashLogoSize,
      );
    }

    // 좌→우 펼치기 애니메이션
    return Container(
      width: _splashLogoSize,
      height: _splashLogoSize,
      alignment: Alignment.centerLeft,
      child: ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor.clamp(0.0, 1.0),
          child: SizedBox(
            width: _splashLogoSize,
            height: _splashLogoSize,
            child: Image(
              image: CachedNetworkImageProvider(_logoUrl!),
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) =>
                  _buildTextLogo(widthFactor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextLogo(double widthFactor) {
    const textStyle = TextStyle(
      fontSize: 72,
      fontWeight: FontWeight.bold,
      letterSpacing: 4,
    );

    // widthFactor가 0이면 빈 공간 반환
    if (widthFactor <= 0.001) {
      return const SizedBox(
        width: _splashLogoSize,
        height: _splashLogoSize,
      );
    }

    return SizedBox(
      width: _splashLogoSize,
      height: _splashLogoSize,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 1. 회색 배경 텍스트 (고정)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'H&DE',
                style: textStyle.copyWith(color: Colors.grey[300]),
              ),
            ),
          ),
          // 2. 좌→우 채워지는 컬러 텍스트
          Positioned.fill(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: widthFactor.clamp(0.0, 1.0),
                child: SizedBox(
                  width: _splashLogoSize,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'H&DE',
                      style: textStyle.copyWith(color: Colors.blue[900]),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
