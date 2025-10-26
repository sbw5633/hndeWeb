// api/get-upload-url.js
const AWS = require('aws-sdk');

// AWS S3 설정
const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION
});

module.exports = async (req, res) => {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // OPTIONS 요청 처리
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // GET 요청만 허용
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { fileName, fileType, contentDisposition } = req.query;
    
    if (!fileName || !fileType) {
      return res.status(400).json({ error: 'fileName과 fileType이 필요합니다' });
    }
    
    const extension = fileName.split('.').pop().toLowerCase();
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 15);
    const key = `uploads/${timestamp}_${random}.${extension}`;
    
    // 🎯 중요: Content-Disposition 헤더 포함하여 Pre-signed URL 생성
    // api/get-upload-url.js
const uploadUrl = s3.getSignedUrl('putObject', {
    Bucket: process.env.AWS_BUCKET_NAME,
    Key: key,
    ContentType: fileType,
    // ContentDisposition: `attachment; filename="${fileName}"`, // ✅ 다운로드 강제
    Expires: 300
  });
    
    console.log('생성된 S3 키:', key);
    console.log('원본 파일명:', fileName);
    console.log('Content-Disposition:', contentDisposition || `attachment; filename="${fileName}"`);
    
    res.json({ uploadUrl, key });
  } catch (error) {
    console.error('Pre-signed URL 생성 실패:', error);
    res.status(500).json({ error: '서버 오류' });
  }
};