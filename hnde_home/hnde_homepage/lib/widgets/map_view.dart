import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class MapView extends StatefulWidget {
  final String address;

  const MapView({
    super.key,
    required this.address,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static int _viewIdCounter = 0;
  
  late String _viewId;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'google-map-${DateTime.now().millisecondsSinceEpoch}-${_viewIdCounter++}';
    _initializeMap();
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 주소가 변경되었으면 지도 재초기화
    if (oldWidget.address != widget.address) {
      _viewId = 'google-map-${DateTime.now().millisecondsSinceEpoch}-${_viewIdCounter++}';
      _initializeMap();
    }
  }

  void _initializeMap() {
    if (widget.address.isEmpty) {
      setState(() {
        _isInitialized = true;
      });
      return;
    }

    try {
      // 구글 지도 iframe 생성 (안정적이고 깔끔)
      final encodedAddress = Uri.encodeComponent(widget.address);
      
      final iframe = html.IFrameElement()
        ..src = 'https://maps.google.com/maps?q=$encodedAddress&t=&z=15&ie=UTF8&iwloc=&output=embed'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.overflow = 'hidden'
        ..allowFullscreen = false
        ..setAttribute('loading', 'lazy');

      final container = html.DivElement()
        ..id = _viewId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.overflow = 'hidden'
        ..style.position = 'relative'
        ..append(iframe);
      
      // 플랫폼 뷰로 등록 (중복 등록 방지)
      try {
        ui_web.platformViewRegistry.registerViewFactory(
          _viewId,
          (int viewId) => container,
        );
      } catch (e) {
        // 이미 등록된 경우 무시
      }
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('지도 초기화 오류: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (widget.address.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Text(
            '주소 정보가 없습니다.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    // 구글 지도 표시 (AspectRatio는 부모에서 처리)
    return HtmlElementView(viewType: _viewId);
  }
}




