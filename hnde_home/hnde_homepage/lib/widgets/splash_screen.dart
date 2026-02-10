import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/firestore_service.dart';

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
  
  static const double _splashLogoSize = 200.0;

  @override
  void initState() {
    super.initState();
    
    // 채우기 애니메이션 컨트롤러 초기화 (0→1로 부드럽게)
    _fillController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
      print('📥 로고 로딩 시작...');
      
      // Firestore에서 직접 topLogoUrl 필드만 빠르게 가져오기
      final firestoreService = FirestoreService();
      final doc = await firestoreService.getDocument(
        FirestoreCollections.homePage,
        'main',
        forceRefresh: false,
      );
      
      if (!mounted) return;
      
      final logoUrl = doc?['topLogoUrl'] as String?;
      print('📥 로고 URL: $logoUrl');
      
      // 이미지가 있는 경우 완전히 로딩될 때까지 대기
      if (logoUrl != null && logoUrl.isNotEmpty) {
        try {
          // 이미지를 메모리에 완전히 로딩
          final imageProvider = CachedNetworkImageProvider(logoUrl);
          await precacheImage(imageProvider, context);
          print('✅ 로고 이미지 로딩 완료: $logoUrl');
        } catch (e) {
          print('⚠️ 로고 이미지 프리캐시 오류: $e');
        }
      }
      
      // 로고 URL이 없어도 로딩 완료로 표시 (버튼이 나타나도록)
      if (mounted) {
        setState(() {
          _logoUrl = logoUrl;
          _logoLoaded = true;
        });
        print('✅ _logoLoaded = true로 설정됨 (로고 URL: $logoUrl)');
      }
    } catch (e, stackTrace) {
      print('❌ 로고 로드 오류: $e');
      print('스택 트레이스: $stackTrace');
      // 오류가 발생해도 로딩 완료로 표시 (버튼이 나타나도록)
      if (mounted) {
        setState(() {
          _logoLoaded = true;
        });
        print('✅ 오류 후에도 _logoLoaded = true로 설정됨');
      }
    }
  }


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

// AnimatedBuilder(
//   animation: _fillController, // 미리 선언된 컨트롤러
//   builder: (context, child) {
//     return ClipRect( // 1. 넘치는 부분을 잘라냄
//       child: Align(
//         alignment: Alignment.centerLeft, // 2. 왼쪽 고정
//         widthFactor: _fillController.value, // 3. 0.0 ~ 1.0 (핵심!)
//         child: SizedBox(
//           width: 200, // 원래 로고의 가로 크기
//           height: 200, // 원래 로고의 세로 크기
//           child: Image.network(
//             '로고주소',
//             fit: BoxFit.contain,
//             alignment: Alignment.centerLeft, // 4. 이미지 내용물도 왼쪽 고정
//           ),
//         ),
//       ),
//     );
//   },
// ),

          // 로고 애니메이션
          AnimatedBuilder(
            animation: _fillController,
            builder: (context, child) {
              final widthFactor = _fillController.value;
              print('🎨 widthFactor: $widthFactor, _animationStarted: $_animationStarted'); // 디버깅용
              
              // 애니메이션 시작 전에는 아무것도 표시하지 않음
              if (!_animationStarted) {
                return const SizedBox.shrink();
              }
              
              return Center(
                child: 
                _buildLogo(widthFactor),
              );
            },
          ),
          // 로딩 중일 때 인디케이터 표시
          if (!_logoLoaded)
            const Center(
              child: CircularProgressIndicator(),
            ),
          // 테스트용 버튼 (애니메이션 시작) - 로딩 완료 후 표시
          if (!_animationStarted && _logoLoaded)
            Center(
              child: ElevatedButton(
                onPressed: _startAnimation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text(
                  '애니메이션 시작',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogo(double widthFactor) {
    print('🖼️ _buildLogo called with widthFactor: $widthFactor');
    
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

    // 좌→우 펼치기 애니메이션
return Container( // 1. 무대: 화면 중앙에 자리를 잡고 있는 200x200 크기의 빈 박스
    width: _splashLogoSize,
    height: _splashLogoSize,
    alignment: Alignment.centerLeft, // [중요] 안쪽 자식을 왼쪽으로 붙임
    child: ClipRect( // 2. 가위: 영역 밖으로 나가는 이미지를 자름
      child: Align(
        alignment: Alignment.centerLeft, // 3. 기준: 왼쪽을 기점으로 창문을 염
        widthFactor: widthFactor, // 4. 비율: 0.0 -> 1.0 (애니메이션 값)
        child: SizedBox( // 5. 실제 내용물: 가위질을 당하는 녀석 (크기 고정 필수)
          width: _splashLogoSize,
          height: _splashLogoSize,
          child: Image(
            image: CachedNetworkImageProvider(_logoUrl!),
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft, // 이미지 내용물도 왼쪽 고정
            errorBuilder: (context, error, stackTrace) => _buildTextLogo(widthFactor),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildTextLogo(double widthFactor) {
    print('📝 _buildTextLogo called with widthFactor: $widthFactor');
    
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
