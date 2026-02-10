# 백엔드 API 준비 상태 검토 보고서

## ✅ 완료된 모델 (toJson/fromJson 포함)

### 회사소개 (Company)
1. **CEO 인사말** (`ceo_greeting.dart`) ✅
   - CEOGreeting 모델
   - 필드: id, imageUrl?, title, content

2. **연혁** (`history.dart`) ✅
   - HistoryItem 모델
   - 필드: id, year (String), content

3. **경영이념 및 비전** (`vision.dart`) ✅
   - VisionContent 모델
   - 필드: id, imageUrl?, title, content

4. **찾아오시는 길** (`location.dart`) ✅
   - LocationInfo 모델
   - 필드: id, address, mapAddress, phone, busInfo, subwayInfo

### 사업소개 (Business)
5. **휴게소 사업** (`rest_area.dart`) ✅
   - RestArea 모델 (중첩 구조)
   - RestAreaDetail, StoreInfo, FoodInfo, FacilityInfo 포함
   - 모든 하위 모델에 toJson/fromJson 구현됨

### 홍보센터 (PR)
6. **CI 소개** (`ci_info.dart`) ✅
   - CIInfo 모델 (중첩 구조)
   - CIMeaning, CIDefinition 포함
   - CIDefinitionType enum 포함

7. **보도자료** (`press_release.dart`) ✅
   - PressRelease 모델
   - 필드: id, title, content, date (DateTime), imageUrl?, author?

8. **고객이벤트** (`customer_event.dart`) ✅
   - CustomerEvent 모델
   - 필드: id, title, content, startDate (DateTime), endDate (DateTime), imageUrl?, isActive

### 커뮤니티 (Community)
9. **공지사항** (`notice.dart`) ✅
   - Notice 모델
   - 필드: id, title, content, date (DateTime), author?, isImportant

10. **고객의 이야기 제출** (`customer_story_submission.dart`) ✅
    - CustomerStorySubmission 모델
    - 필드: name, email, phone?, title, content

11. **사업제안 제출** (`business_proposal_submission.dart`) ✅
    - BusinessProposalSubmission 모델
    - 필드: companyName, representative, email, phone, businessType, proposalTitle, proposalContent

### 인재채용 (Recruitment)
12. **인재채용** (`recruitment.dart`) ✅
    - Recruitment 모델 (중첩 구조)
    - JobOpening, RecruitmentSection 포함
    - 모든 하위 모델에 toJson/fromJson 구현됨

## 📋 API 엔드포인트 요구사항

### GET 요청 (데이터 조회)
- `GET /api/company/ceo` → CEOGreeting
- `GET /api/company/history` → List<HistoryItem>
- `GET /api/company/vision` → VisionContent
- `GET /api/company/location` → LocationInfo
- `GET /api/business/rest-areas` → List<RestArea>
- `GET /api/pr/ci` → CIInfo
- `GET /api/pr/press-releases` → List<PressRelease>
- `GET /api/pr/events` → List<CustomerEvent>
- `GET /api/community/notices` → List<Notice>
- `GET /api/recruitment` → Recruitment

### POST 요청 (데이터 제출)
- `POST /api/community/customer-stories` → CustomerStorySubmission
- `POST /api/community/business-proposals` → BusinessProposalSubmission

## ✅ 검증 완료
- 모든 모델에 toJson/fromJson 메서드 구현됨
- DateTime 필드는 ISO8601 문자열로 직렬화
- Optional 필드는 null 허용 처리됨
- 중첩 구조 모델도 모두 직렬화 지원

## 🎯 다음 단계
백엔드 개발을 시작할 수 있습니다. 위의 API 엔드포인트를 구현하고, 각 모델의 JSON 형식에 맞춰 데이터를 반환하면 됩니다.


