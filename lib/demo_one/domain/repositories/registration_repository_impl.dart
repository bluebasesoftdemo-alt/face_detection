
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../data/entities/face_registration_data.dart';
import '../../data/usecase/register_face_usecase.dart';
import '../../utils/constant.dart';
class RegistrationRepositoryImpl implements RegistrationRepository {
  final Dio dio;
  RegistrationRepositoryImpl({
    Dio? dio,
  }) : dio = dio ??
      Dio(
        BaseOptions(//  baseUrl: 'https://${Constant.base_url}/face_login/',
          baseUrl: 'http://${Constant.base_url}/',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

  @override
  Future<bool> registerFace(FaceRegistrationData data) async {
    try {
      print('================================');
      print('FACE REGISTRATION START');
      print('URL: ${dio.options.baseUrl}');

      final requestData = data.toJson();

      print('REQUEST DATA: $requestData');
      // Send JSON object
      final response = await dio.post(
        'mobileregister',
        data: {
          "userId" : data.userId,
          "userName" : data.userName,
          "embedding" : data.embedding,
          "faceJpgBase64" : data.faceJpgBase64
        },
      );

      print('================================');
      print('FACE REG API STATUS: ${response.statusCode}');
      print('FACE REG API RESPONSE: ${response.data}');
      print('================================');

      if (response.statusCode == 200) {
        final responseData = response.data;

        // Dio already decoded JSON
        if (responseData is Map<String, dynamic>) {
          final status = responseData['status'];

          return status == 'success' || status == true;
        }

        // In case PHP returns JSON as String
        if (responseData is String) {
          print('RAW RESPONSE: $responseData');

          try {
            final decoded = jsonDecode(responseData);

            if (decoded is Map<String, dynamic>) {
              final status = decoded['status'];

              return status == 'success' || status == true;
            }
          } catch (e) {
            print('JSON DECODE ERROR: $e');
          }
        }
      }

      return false;
    } on DioException catch (e) {
      print('================================');
      print('FACE REG API ERROR');
      print('TYPE: ${e.type}');
      print('MESSAGE: ${e.message}');
      print('STATUS: ${e.response?.statusCode}');
      print('RESPONSE: ${e.response?.data}');
      print('ERROR: ${e.error}');
      print('================================');

      return false;
    } catch (e) {
      print('================================');
      print('UNEXPECTED ERROR: $e');
      print('ERROR: $e');
      print('================================');

      return false;
    }
  }
}