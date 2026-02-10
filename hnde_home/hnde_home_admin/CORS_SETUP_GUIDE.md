# CORS 설정 가이드

## 서버 측 설정 방법

서버에서 `https://files.whiteagent-w.kr/upload` 엔드포인트에 다음 CORS 헤더를 추가해야 합니다:

### Node.js/Express 예시:
```javascript
app.post('/upload', (req, res) => {
  // CORS 헤더 설정
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  
  // 파일 업로드 처리...
});
```

### Nginx 설정 (openresty인 경우):
```nginx
location /upload {
    # CORS 헤더 추가
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'POST, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Content-Type' always;
    
    # OPTIONS 요청 처리
    if ($request_method = 'OPTIONS') {
        return 204;
    }
    
    # 프록시 설정 등...
}
```

### Python/Flask 예시:
```python
@app.route('/upload', methods=['POST', 'OPTIONS'])
def upload():
    # CORS 헤더 설정
    response = make_response()
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    
    if request.method == 'OPTIONS':
        return response
    
    # 파일 업로드 처리...
```

## 개발 환경 우회 방법 (임시)

만약 서버를 수정할 수 없다면, 개발 환경에서만 사용할 수 있는 임시 방법:

### 1. Chrome 확장 프로그램 사용
- "CORS Unblock" 같은 확장 프로그램 사용 (개발용으로만)

### 2. 로컬 프록시 서버 사용
- CORS 프록시 서버를 별도로 운영

## 중요사항

- `Access-Control-Allow-Origin: *`는 모든 출처를 허용합니다
- 프로덕션에서는 특정 도메인만 허용하는 것이 좋습니다:
  ```
  Access-Control-Allow-Origin: https://your-admin-domain.com
  ```

