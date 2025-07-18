import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;

class StorageService {
  static const String cloudName = 'ddz9qncy4';
  static const String uploadPreset = 'hnde_data';
  static const String apiUrl = 'https://api.cloudinary.com/v1_1/$cloudName/auto/upload';

  /// XFile 또는 html.File을 Cloudinary에 업로드하고 다운로드 URL 반환
  static Future<String?> uploadFileToCloudinary(dynamic file) async {
    try {
      Uint8List bytes;
      String fileName;
      if (file is XFile) {
        bytes = await file.readAsBytes();
        fileName = file.name;
      } else if (file is html.File) {
        final reader = html.FileReader();
        final completer = Completer<Uint8List>();
        
        // 에러 핸들링 추가
        reader.onError.listen((error) {
          completer.completeError('파일 읽기 실패: $error');
        });
        
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((event) {
          if (reader.result != null) {
            completer.complete(reader.result as Uint8List);
          } else {
            completer.completeError('파일 읽기 실패');
          }
        });
        
        bytes = await completer.future;
        fileName = file.name;
      } else {
        throw Exception('지원하지 않는 파일 타입');
      }

      final request = http.MultipartRequest('POST', Uri.parse(apiUrl))
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['secure_url'] as String?;
      } else {
        throw Exception('Cloudinary 업로드 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // 예외를 다시 던지지 않고 null 반환
      print('StorageService 에러: $e');
      return null;
    }
  }
} 