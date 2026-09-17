import '../entities/face_registration_data.dart';

abstract class LoginRepository {
  Future<bool> loginFace(FaceRegistrationData data);
}

class LoginFaceUseCase {
  final LoginRepository repository;

  LoginFaceUseCase(this.repository);

  Future<bool> call(FaceRegistrationData data) async {
    if (data.embedding.length != 512) {
      throw Exception("Invalid embedding size. FaceNet requires 512 float values.");
    }
    return await repository.loginFace(data);
  }
}