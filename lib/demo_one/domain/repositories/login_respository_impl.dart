import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../data/entities/face_registration_data.dart';
import '../../data/usecase/login_face_usecase.dart';
import '../../utils/constant.dart';

class LoginRepositoryImpl implements LoginRepository {
  final Dio dio;
  LoginRepositoryImpl({
    Dio? dio,
  }) : dio = dio ??
      Dio(
        BaseOptions(
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
  Future<bool> loginFace(FaceRegistrationData data) async {
    try {
      print('================================');
      print('Login FACE REGISTRATION START');
      print('Login URL: ${dio.options.baseUrl}');

      final requestData = data.toJson();

      print('Login REQUEST DATA: $requestData');
      // Send JSON object
      final response = await dio.post(
        'face_login',
        data: {
          "userId" : data.userId,
          "userName" : data.userName,
          "embedding" : data.embedding,
          "faceJpgBase64" : data.faceJpgBase64
        },
      );

      print('=============Login===================');
      print('Login FACE REG API STATUS: ${response.statusCode}');
      print('Login FACE REG API RESPONSE: ${response.data}');
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
          print('Login RAW RESPONSE: $responseData');

          try {
            final decoded = jsonDecode(responseData);

            if (decoded is Map<String, dynamic>) {
              final status = decoded['status'];

              return status == 'success' || status == true;
            }
          } catch (e) {
            print('Login JSON DECODE ERROR: $e');
          }
        }
      }

      return false;
    } on DioException catch (e) {
      print('=============Login===================');
      print('Login FACE REG API ERROR');
      print('Login TYPE: ${e.type}');
      print('Login MESSAGE: ${e.message}');
      print('Login STATUS: ${e.response?.statusCode}');
      print('Login RESPONSE: ${e.response?.data}');
      print('Login ERROR: ${e.error}');
      print('==============Login==================');

      return false;
    } catch (e) {
      print('============Login====================');
      print('Login UNEXPECTED ERROR: $e');
      print('Login ERROR: $e');
      print('============Login====================');

      return false;
    }
  }
}