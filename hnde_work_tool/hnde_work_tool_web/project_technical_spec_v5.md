[Technical Spec] HQ-HUB Enterprise Admin System V5 (Auth Integrated)

1. 프로젝트 개요

프로젝트 명: hnde-work-web

Firebase ID: hnde-work-web (Project #635135884573)

목적: 본사-사업소 간 실시간 협업, 4대보험 자동화, 전사 소통 채널 통합.

기술 스택: Flutter (Web), Firebase (Auth, Firestore, Storage), SheetJS (Excel).

디자인 가이드: Deep Blue (#1E3A8A), SPA 방식의 부드러운 화면 전환.

2. Firebase 설정 (Environment)

const firebaseConfig = {
  apiKey: "AIzaSyAVOY6i-akAq5eGV4OwpfWpTPIdBNRatVU",
  authDomain: "hnde-work-web.firebaseapp.com",
  projectId: "hnde-work-web",
  storageBucket: "hnde-work-web.firebasestorage.app",
  messagingSenderId: "635135884573",
  appId: "1:635135884573:web:b2be7111731802cefe75f4",
  measurementId: "G-006FJCDLNL"
};


3. 인증 및 계정 관리 아키텍처 (Hybrid Auth)

인증 (Authentication): Firebase Auth (Email/Password) 사용.

정보 저장 (Database): Firestore /artifacts/{appId}/users/{uid}/profile 경로에 저장.

회원가입 워크플로우:

Auth.createUserWithEmailAndPassword로 계정 생성.

생성된 uid를 기반으로 Firestore에 프로필(이름, 소속, 직책 등) 초기 데이터 생성.

가입 완료 후 메인 대시보드로 부드럽게 전환.

4. 인증 페이지 명세 (UI/UX)

[A] 로그인 페이지 (Login)

레이아웃: 중앙 집중형 카드 레이아웃. 배경에 기업 로고 워터마크.

필드: 이메일, 비밀번호, [로그인 상태 유지] 체크박스.

애니메이션: 로그인 버튼 클릭 시 CircularProgressIndicator 노출 및 성공 시 Fade-out 효과.

[B] 회원가입 및 프로필 설정 (Signup & Profile Setup)

레이아웃: 2단계 스텝퍼(Stepper) 또는 통합 긴 폼 양식.

필드:

계정 정보: 이메일, 비밀번호, 비밀번호 확인.

프로필 정보: 성명, 사업소(드롭다운), 직책, 생일(MM/DD), 연락처(010-0000-0000).

입사일자: 회원가입 시에는 선택 불가(관리자 부여용 필드로 기본값 세팅).

5. 화면 전환 기술 (SPA)

브라우저 새로고침 없이 State 값에 따라 AuthScreen ↔ MainAppShell을 교체.

AnimatedSwitcher를 활용하여 전환 시 0.4초의 Fade 애니메이션 적용.