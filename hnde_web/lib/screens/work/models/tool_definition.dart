import 'package:flutter/material.dart';

/// 도구 타입 정의
enum ToolType {
  pdfMerge,
  pdfSplit,
  pdfCompress,
  imgMerge,
  imgCompress,
  imgResize,
  // PDF 구성
  pdfRemovePages,
  pdfExtractPages,
  pdfReorder,
  pdfScan,
  // PDF 최적화
  pdfRepair,
  pdfToPdfA,
  // PDF로 변환
  jpgToPdf,
  wordToPdf,
  hwpToPdf,
  pptToPdf,
  excelToPdf,
  htmlToPdf,
  // PDF에서 변환
  pdfToJpg,
  pdfToWord,
  pdfToPpt,
  pdfToExcel,
  pdfToTxt,
  pdfOcr,
  // PDF 편집
  pdfRotate,
  pdfAddPageNumbers,
  pdfWatermark,
  pdfCrop,
  pdfEdit,
  pdfAddText,
  // PDF 보안
  pdfUnlock,
  pdfProtect,
  pdfSign,
  pdfRedact,
  pdfCompare,
  // AI 기능
  pdfSummarize,
  pdfQnA,
  pdfTranslate,
  // 이미지 압축/리사이즈
  imgCrop,
  imgResizeMaintain,
  // 이미지 변환
  imgJpgToPng,
  imgPngToJpg,
  imgToWebp,
  imgToGif,
  imgToPdf,
  imgBatchConvert,
  // 이미지 편집
  imgRotate,
  imgFlip,
  imgAdjustBrightness,
  imgFilter,
  imgAdjustColor,
  imgBlur,
  // 이미지 합성
  imgWatermark,
  imgFrame,
  imgBorder,
  imgGrid,
  // 이미지 고급 편집
  imgRemoveBg,
  imgColorize,
  imgMosaic,
  imgAddText,
  imgAddShape,
  // AI 기능
  imgDescribe,
  imgGenerate,
  imgConvert,
  imgImprove,
}

/// 도구 설정 정의
class ToolConfig {
  final ToolType type;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> acceptedTypes;
  final int? minFiles;
  final int? maxFiles;
  final bool isNew;

  const ToolConfig({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.acceptedTypes,
    this.minFiles,
    this.maxFiles,
    this.isNew = false,
  });
}

