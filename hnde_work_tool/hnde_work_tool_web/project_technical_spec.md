# **\[Technical Spec\] HQ-HUB Enterprise Admin System V4 (Comprehensive)**

## **1\. 프로젝트 개요**

* **프로젝트 명**: hnde-work-web  
* **프로젝트 번호**: 635135884573  
* **앱 ID**: 1:635135884573:web:b2be7111731802cefe75f4  
* **목적**: 본사-사업소 간 실시간 협업, 4대보험 자동화, 전사 소통 채널 통합.  
* **기술 스택**: Flutter (Web), Firebase (Auth, Firestore, Storage), SheetJS (Excel).  
* **디자인 가이드**: Deep Blue (\#1E3A8A) 테마, 12px+ 라운드 코너, 그림자 계층 구조.

## **2\. Firebase 설정 (Environment)**

const firebaseConfig \= {  
  apiKey: "AIzaSyAVOY6i-akAq5eGV4OwpfWpTPIdBNRatVU",  
  authDomain: "hnde-work-web.firebaseapp.com",  
  projectId: "hnde-work-web",  
  storageBucket: "hnde-work-web.firebasestorage.app",  
  messagingSenderId: "635135884573",  
  appId: "1:635135884573:web:b2be7111731802cefe75f4",  
  measurementId: "G-006FJCDLNL"  
};

## **3\. 핵심 아키텍처: 부드러운 화면 전환 (Smooth Interaction)**

* **SPA 메커니즘**: 브라우저 새로고침 없이 Flutter 내에서 State 전환을 통해 화면을 교체한다.  
* **전환 애니메이션**:  
  * 메인 탭 전환 시 FadeTransition 또는 AnimatedSwitcher를 사용하여 0.3초 내외의 부드러운 전환 효과를 적용한다.  
  * 리스트에서 상세 페이지 진입 시 오른쪽에서 왼쪽으로 미끄러지는 SlideTransition을 권장한다.  
  * 모든 모달(설정, 일정 추가)은 하단에서 위로 솟아오르거나 중앙에서 커지는 애니메이션을 적용한다.

## **4\. 화면별 상세 기능 및 레이아웃 명세**

### **\[A\] 4대보험 관리 (Social Insurance) \- 전 세부 화면**

1. **메인 대시보드**: 탭별(국민건강/고용산재) 취득자 수 요약 및 3대 버튼(현황, 검색, 일용직) 배치.  
2. **전체 현황보기 (Status View)**:  
   * 데이터 테이블: 성명, 주민번호(마스킹), 취득일자, 상태 태그.  
   * 기능: Download 버튼 클릭 시 현재 리스트를 엑셀로 추출.  
3. **직원 검색 (Search View)**:  
   * UI: 성명 및 주민번호 앞자리 입력 폼.  
   * 로직: Firestore insurance\_status 쿼리 후 결과 카드로 표시. 미존재 시 안내 문구 노출.  
4. **일용직 관리 (Daily Management)**:  
   * UI: 행 추가/삭제가 가능한 동적 테이블. 1\~31일 그리드 체크박스.  
   * 엑셀 자동화: '저장' 시 첨부된 '근로내용확인신고' 양식의 셀 위치에 맞춰 데이터를 매핑하여 파일 생성.

### **\[B\] 업무 캘린더 & 일정 추가 (Calendar & Modal)**

* **월간 뷰**: Firestore calendar\_events 실시간 연동.  
* **일정 추가 모달**:  
  * 필드: 일정명(String), 기간(DateTime Range), 공개범위(Enum: Private, Branch, HQ).  
  * UI: 중앙 레이어 팝업, DatePicker 및 TimePicker 사용.  
  * 부드러운 처리: 저장 즉시 캘린더 뷰에 반영되는 Stream 처리.

### **\[C\] 자료 송수신 (Material Exchange) \- 권한별 상세**

* **HQ View**: 전 사업소 리스트. 각 행별 [제출확인](https://www.google.com/search?q=Green), [재요청](https://www.google.com/search?q=Orange) 버튼. 재요청 시 반려 사유 입력 다이얼로그 오픈.  
* **Branch View**: 본인 제출물 리스트 및 드래그앤드롭 업로드 영역. 본사 가이드 문서(Markdown형태) 상시 노출.

### **\[D\] 투두리스트 (Todo List) \- 날짜 연동**

* **기능**: 상단 화살표로 날짜 이동. 캘린더 데이터 중 '내 일정'을 자동으로 리스트 상단에 로드.  
* **동기화**: '캘린더에 등록' 체크 시 투두 완료가 캘린더 완료 상태와 동기화됨.

### **\[E\] 게시판 상세 (Post Detail)**

* **UI**: 제목, 작성자, 날짜, 조회수가 포함된 고해상도 헤더. 본문 영역(Markdown 지원), 하단 첨부파일 다운로드 버튼 리스트.

## **5\. 데이터 구조 (Firestore)**

### **\[Path Rules\]**

* Public: /artifacts/{appId}/public/data/{collectionName}  
* Private: /artifacts/{appId}/users/{userId}/{collectionName}

### **\[Key Collections\]**

* calendar\_events: 전사/개인 일정 데이터.  
* daily\_workers: 월별 일용직 근로 체크 배열 데이터.  
* submissions: 자료 요청에 대한 사업소별 제출 이력.  
* messages: 앱바 쪽지함 데이터 (sender, receiver, content, isRead).

## **6\. 구현 가이드라인**

* **성능**: onSnapshot 리스너를 적절히 배치하여 실시간성을 확보하되, 불필요한 위젯 빌드를 최소화할 것.  
* **사용자 설정**: 중앙 모달을 통해 이름, 직책 등을 수정하며, 저장 시 Firebase Auth 프로필과 Firestore 유저 도큐먼트를 동시 업데이트한다.