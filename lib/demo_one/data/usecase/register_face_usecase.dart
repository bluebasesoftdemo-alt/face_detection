
import '../entities/face_registration_data.dart';
abstract class RegistrationRepository {
  Future<bool> registerFace(FaceRegistrationData data);
}

class RegisterFaceUseCase {
  final RegistrationRepository repository;

  RegisterFaceUseCase(this.repository);

  Future<bool> call(FaceRegistrationData data) async {
    if (data.embedding.length != 512) {
      throw Exception("Invalid embedding size. FaceNet requires 512 float values.");
    }
    return await repository.registerFace(data);
  }
}
