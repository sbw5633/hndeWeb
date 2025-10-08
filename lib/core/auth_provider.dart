import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firebase/admin_setup_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _firebaseUser;
  AppUser? _appUser;
  bool _isLoading = false;

  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _firebaseUser != null && _appUser != null;
  bool get isAdmin => _appUser?.isMainAdmin == true;

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _firebaseUser = user;
      if (user != null) {
        _loadUserData(user.email!);
      } else {
        _appUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      print('사용자 데이터 로드 시작: $email');
      _appUser = await AdminSetupService.getUserByEmail(email);
      if (_appUser != null) {
        print('사용자 데이터 로드 성공:');
        print('- 이름: ${_appUser!.name}');
        print('- 이메일: ${_appUser!.email}');
        print('- 소속: ${_appUser!.affiliation}');
        print('- 직책: ${_appUser!.role}');
        print('- 권한 레벨: ${_appUser!.permissionLevel.level} (${_appUser!.permissionLevel.description})');
        print('- 승인 상태: ${_appUser!.approved}');
      } else {
        print('사용자 데이터를 찾을 수 없습니다: $email');
      }
    } catch (e) {
      print('사용자 데이터 로드 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        print('Firebase 로그인 성공: ${userCredential.user!.email}');
        await _loadUserData(email);
        
        // 사용자 데이터가 로드되지 않았거나 승인되지 않은 경우
        if (_appUser == null) {
          print('사용자 정보를 찾을 수 없습니다.');
          return false;
        }
        
        print('사용자 데이터 로드 성공: ${_appUser!.name}, 승인상태: ${_appUser!.approved}');
        
        if (!_appUser!.approved) {
          print('계정이 승인되지 않았습니다. (임시로 승인 우회)');
          // 임시로 승인 체크를 우회 - 개발용
          // return false;
        }
        
        print('로그인 완료 성공');
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = '등록되지 않은 이메일입니다.';
          break;
        case 'wrong-password':
          errorMessage = '비밀번호가 올바르지 않습니다.';
          break;
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일 형식입니다.';
          break;
        case 'user-disabled':
          errorMessage = '비활성화된 계정입니다.';
          break;
        case 'too-many-requests':
          errorMessage = '너무 많은 로그인 시도가 있었습니다. 잠시 후 다시 시도해주세요.';
          break;
        default:
          errorMessage = '로그인 중 오류가 발생했습니다: ${e.message}';
      }
      print('로그인 실패: $errorMessage');
      return false;
    } catch (e) {
      print('로그인 실패: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    _firebaseUser = null;
    _appUser = null;
    notifyListeners();
  }

  /// 임시 관리자 계정 생성 (개발용)
  Future<void> createTemporaryAdmin() async {
    await AdminSetupService.createTemporaryAdmin();
  }
} 