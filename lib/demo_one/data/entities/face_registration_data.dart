
class FaceRegistrationData {
  final String userId;
  final String userName;
  final List<double> embedding;
  final String faceJpgBase64;

  FaceRegistrationData({
    required this.userId,
    required this.userName,
    required this.embedding,
    required this.faceJpgBase64,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': userName,
    'embedding': embedding,
    'face_image': faceJpgBase64,
  };
}
