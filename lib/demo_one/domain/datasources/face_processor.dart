
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceProcessor {
  late final FaceDetector _faceDetector;

  Interpreter? _interpreter;

  late final Future<void> _modelReady;

  // ============================================================
// FACE SETTINGS
// ============================================================

  /// Padding around ML Kit face bounding box.
  static const double facePadding = 0.30;

  /// Minimum acceptable face size in the image.
  static const double minimumFaceSize = 80.0;

  /// Maximum allowed left/right rotation.
  static const double maxYawAngle = 10.0;

  /// Maximum allowed up/down rotation.
  static const double maxPitchAngle = 10.0;

  /// Maximum allowed head tilt.
  static const double maxRollAngle = 10.0;

  FaceProcessor() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15,
      ),
    );

    _modelReady = _loadModel();
  }

  // ============================================================
  // LOAD MODEL
  // ============================================================

  Future<void> _loadModel() async {
    try {
      print('================================');
      print('Loading FaceNet model...');

      _interpreter = await Interpreter.fromAsset(
        'assets/facenet_512.tflite',
      );

      final inputTensor =
      _interpreter!.getInputTensor(0);

      final outputTensor =
      _interpreter!.getOutputTensor(0);

      print('TFLITE MODEL LOADED');
      print('Input shape  : ${inputTensor.shape}');
      print('Input type   : ${inputTensor.type}');
      print('Output shape : ${outputTensor.shape}');
      print('Output type  : ${outputTensor.type}');
      print('================================');

      // ----------------------------------------------------------
      // VALIDATE MODEL
      // ----------------------------------------------------------

      final inputShape =
          inputTensor.shape;

      final outputShape =
          outputTensor.shape;

      if (inputShape.length != 4 ||
          inputShape[0] != 1 ||
          inputShape[1] != 160 ||
          inputShape[2] != 160 ||
          inputShape[3] != 3) {
        throw Exception(
          'Unexpected FaceNet input shape: $inputShape',
        );
      }

      if (outputShape.length != 2 ||
          outputShape[0] != 1 ||
          outputShape[1] != 512) {
        throw Exception(
          'Unexpected FaceNet output shape: $outputShape',
        );
      }

      if (inputTensor.type != TensorType.float32) {
        throw Exception(
          'Expected float32 input but got '
              '${inputTensor.type}',
        );
      }

      if (outputTensor.type != TensorType.float32) {
        throw Exception(
          'Expected float32 output but got '
              '${outputTensor.type}',
        );
      }

      print('✅ FaceNet model validation passed.');
    } catch (e, stackTrace) {
      print('================================');
      print('❌ FAILED TO LOAD FACENET MODEL');
      print('Error: $e');
      print('StackTrace: $stackTrace');
      print('================================');

      _interpreter = null;

      rethrow;
    }
  }

  // ============================================================
  // PROCESS FACE
  // ============================================================

  Future<List<double>?> processFace(
      String imagePath,
      ) async {
    try {
      // ----------------------------------------------------------
      // WAIT FOR MODEL
      // ----------------------------------------------------------

      await _modelReady;

      final interpreter = _interpreter;

      if (interpreter == null) {
        print(
          '❌ TFLite interpreter is not loaded.',
        );
        return null;
      }

      // ----------------------------------------------------------
      // CHECK IMAGE
      // ----------------------------------------------------------

      final file = File(imagePath);

      if (!await file.exists()) {
        print(
          '❌ Image does not exist: $imagePath',
        );
        return null;
      }

      // ----------------------------------------------------------
      // ML KIT INPUT
      // ----------------------------------------------------------

      final inputImage =
      InputImage.fromFilePath(imagePath);

      // ----------------------------------------------------------
      // DETECT FACES
      // ----------------------------------------------------------

      final faces =
      await _faceDetector.processImage(
        inputImage,
      );

      print('================================');
      print('Image path: $imagePath');
      print('Faces detected: ${faces.length}');

      for (final face in faces) {
        print(
          'Face bounding box: '
              '${face.boundingBox}',
        );

        print(
          'Head Euler X: '
              '${face.headEulerAngleX}',
        );

        print(
          'Head Euler Y: '
              '${face.headEulerAngleY}',
        );

        print(
          'Head Euler Z: '
              '${face.headEulerAngleZ}',
        );
      }

      print('================================');

      // ----------------------------------------------------------
      // NO FACE
      // ----------------------------------------------------------

      if (faces.isEmpty) {
        print(
          '❌ No face detected.',
        );
        return null;
      }

      // ----------------------------------------------------------
      // SELECT LARGEST FACE
      // ----------------------------------------------------------

      final Face largestFace =
      faces.reduce(
            (a, b) {
          final areaA =
              a.boundingBox.width *
                  a.boundingBox.height;

          final areaB =
              b.boundingBox.width *
                  b.boundingBox.height;

          return areaA > areaB ? a : b;
        },
      );

      // ----------------------------------------------------------
      // CHECK FACE SIZE
      // ----------------------------------------------------------

      if (largestFace.boundingBox.width <
          minimumFaceSize ||
          largestFace.boundingBox.height <
              minimumFaceSize) {
        print(
          '❌ Face is too small.',
        );

        return null;
      }
      // ----------------------------------------------------------
// CHECK FACE DIRECTION
// ----------------------------------------------------------

      if (!isFaceLookingStraight(largestFace)) {
        print('❌ Please look straight at the camera.');
        return null;
      }
      // ----------------------------------------------------------
      // EXTRACT EMBEDDING
      // ----------------------------------------------------------

      return _extractEmbedding(
        imagePath,
        largestFace.boundingBox,
      );
    } catch (e, stackTrace) {
      print('================================');
      print('❌ Face processing error');
      print('Error: $e');
      print('StackTrace: $stackTrace');
      print('================================');

      return null;
    }
  }

  // ============================================================
  // EXTRACT EMBEDDING
  // ============================================================

  List<double>? _extractEmbedding(
      String imagePath,
      Rect boundingBox,
      ) {
    final interpreter = _interpreter;

    if (interpreter == null) {
      print(
        '❌ Interpreter is null.',
      );
      return null;
    }

    try {
      // ----------------------------------------------------------
      // READ IMAGE
      // ----------------------------------------------------------

      final fileBytes =
      File(imagePath).readAsBytesSync();

      final img.Image? originalImage =
      img.decodeImage(fileBytes);

      if (originalImage == null) {
        print(
          '❌ Could not decode image.',
        );
        return null;
      }

      print(
        'Original image size: '
            '${originalImage.width} x '
            '${originalImage.height}',
      );

      // ----------------------------------------------------------
      // GET MODEL INPUT
      // ----------------------------------------------------------

      final inputTensor =
      interpreter.getInputTensor(0);

      final inputShape =
          inputTensor.shape;

      print(
        'Model input shape: $inputShape',
      );

      print(
        'Model input type : '
            '${inputTensor.type}',
      );

      final int inputHeight =
      inputShape[1];

      final int inputWidth =
      inputShape[2];

      final int inputChannels =
      inputShape[3];

      if (inputHeight != 160 ||
          inputWidth != 160 ||
          inputChannels != 3) {
        print(
          '❌ Unexpected input shape: '
              '$inputShape',
        );

        return null;
      }

      // ----------------------------------------------------------
      // ML KIT FACE BOX
      // ----------------------------------------------------------

      int faceX =
      boundingBox.left.floor();

      int faceY =
      boundingBox.top.floor();

      int faceWidth =
      boundingBox.width.ceil();

      int faceHeight =
      boundingBox.height.ceil();

      print(
        'Detected face: '
            'x=$faceX '
            'y=$faceY '
            'width=$faceWidth '
            'height=$faceHeight',
      );

      if (faceWidth <= 0 ||
          faceHeight <= 0) {
        print(
          '❌ Invalid face bounding box.',
        );

        return null;
      }

      // ----------------------------------------------------------
      // MAKE SQUARE CROP
      // ----------------------------------------------------------

      final int maxDimension =
      max(
        faceWidth,
        faceHeight,
      );

      // Add padding around face.
      final int padding =
      (maxDimension *
          facePadding)
          .round();

      int squareSize =
          maxDimension +
              (padding * 2);

      // ----------------------------------------------------------
      // FACE CENTER
      // ----------------------------------------------------------

      final double centerX =
          faceX +
              faceWidth / 2.0;

      final double centerY =
          faceY +
              faceHeight / 2.0;

      // ----------------------------------------------------------
      // SQUARE CROP POSITION
      // ----------------------------------------------------------

      int cropX =
      (centerX -
          squareSize / 2)
          .round();

      int cropY =
      (centerY -
          squareSize / 2)
          .round();

      // ----------------------------------------------------------
      // KEEP CROP INSIDE IMAGE
      // ----------------------------------------------------------

      if (cropX < 0) {
        cropX = 0;
      }

      if (cropY < 0) {
        cropY = 0;
      }

      // ----------------------------------------------------------
      // ADJUST IF RIGHT/BOTTOM EXCEEDS IMAGE
      // ----------------------------------------------------------

      if (cropX + squareSize >
          originalImage.width) {
        cropX =
            originalImage.width -
                squareSize;
      }

      if (cropY + squareSize >
          originalImage.height) {
        cropY =
            originalImage.height -
                squareSize;
      }

      // ----------------------------------------------------------
      // FINAL CLAMP
      // ----------------------------------------------------------

      cropX =
          max(0, cropX);

      cropY =
          max(0, cropY);

      // ----------------------------------------------------------
      // CALCULATE AVAILABLE SIZE
      // ----------------------------------------------------------

      final int availableWidth =
          originalImage.width -
              cropX;

      final int availableHeight =
          originalImage.height -
              cropY;

      squareSize =
          min(
            squareSize,
            min(
              availableWidth,
              availableHeight,
            ),
          );

      if (squareSize <= 0) {
        print(
          '❌ Invalid square crop size.',
        );

        return null;
      }

      print(
        'Square face crop: '
            'x=$cropX '
            'y=$cropY '
            'size=$squareSize',
      );

      // ----------------------------------------------------------
      // CROP
      // ----------------------------------------------------------

      final img.Image faceCrop =
      img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: squareSize,
        height: squareSize,
      );

      print(
        'Face crop size: '
            '${faceCrop.width} x '
            '${faceCrop.height}',
      );

      // ----------------------------------------------------------
      // RESIZE
      // ----------------------------------------------------------

      final img.Image resizedFace =
      img.copyResize(
        faceCrop,
        width: inputWidth,
        height: inputHeight,
        interpolation:
        img.Interpolation.linear,
      );

      print(
        'Resized face: '
            '${resizedFace.width} x '
            '${resizedFace.height}',
      );

      // ----------------------------------------------------------
      // CREATE FLOAT32 INPUT
      // ----------------------------------------------------------

      final input =
      List.generate(
        inputHeight,
            (y) {
          return List.generate(
            inputWidth,
                (x) {
              final pixel =
              resizedFace.getPixel(
                x,
                y,
              );

              final double r =
              pixel.r.toDouble();

              final double g =
              pixel.g.toDouble();

              final double b =
              pixel.b.toDouble();

              // --------------------------------------------------
              // FACENET NORMALIZATION
              //
              // IMPORTANT:
              // Registration and attendance MUST use
              // exactly the same preprocessing.
              // --------------------------------------------------

              final double normalizedR =
                  (r - 127.5) / 128.0;

              final double normalizedG =
                  (g - 127.5) / 128.0;

              final double normalizedB =
                  (b - 127.5) / 128.0;

              return [
                normalizedR,
                normalizedG,
                normalizedB,
              ];
            },
          );
        },
      );

      final inputTensorData = [
        input,
      ];

      // ----------------------------------------------------------
      // OUTPUT
      // ----------------------------------------------------------

      final outputTensor =
      interpreter.getOutputTensor(0);

      final outputShape =
          outputTensor.shape;

      print(
        'Model output shape: '
            '$outputShape',
      );

      print(
        'Model output type : '
            '${outputTensor.type}',
      );

      if (outputShape.length != 2 ||
          outputShape[0] != 1 ||
          outputShape[1] != 512) {
        print(
          '❌ Unexpected output shape: '
              '$outputShape',
        );

        return null;
      }

      const int embeddingSize = 512;

      // ----------------------------------------------------------
      // OUTPUT BUFFER
      // ----------------------------------------------------------

      final output = [
        List<double>.filled(
          embeddingSize,
          0.0,
        ),
      ];

      // ----------------------------------------------------------
      // INFERENCE
      // ----------------------------------------------------------

      print(
        'Running TFLite inference...',
      );

      interpreter.run(
        inputTensorData,
        output,
      );

      print(
        'TFLite inference completed.',
      );

      // ----------------------------------------------------------
      // GET EMBEDDING
      // ----------------------------------------------------------

      final List<double> embedding =
      List<double>.from(
        output[0],
      );

      print(
        'Embedding length: '
            '${embedding.length}',
      );

      if (embedding.length != 512) {
        print(
          '❌ Invalid embedding size.',
        );

        return null;
      }

      // ----------------------------------------------------------
      // L2 NORMALIZATION
      // ----------------------------------------------------------

      final List<double>
      normalizedEmbedding =
      _l2Normalize(
        embedding,
      );

      print(
        'Normalized embedding length: '
            '${normalizedEmbedding.length}',
      );

      // ----------------------------------------------------------
      // VERIFY VECTOR NORM
      // ----------------------------------------------------------

      double squaredSum = 0.0;

      for (final value
      in normalizedEmbedding) {
        squaredSum +=
            value * value;
      }

      final double vectorNorm =
      sqrt(squaredSum);

      print(
        'Normalized vector magnitude: '
            '$vectorNorm',
      );

      // ----------------------------------------------------------
      // EMBEDDING STATISTICS
      // ----------------------------------------------------------

      final double minValue =
      normalizedEmbedding.reduce(min);

      final double maxValue =
      normalizedEmbedding.reduce(max);

      final double meanValue =
          normalizedEmbedding.reduce(
                (a, b) => a + b,
          ) /
              normalizedEmbedding.length;

      print(
        'Embedding min : $minValue',
      );

      print(
        'Embedding max : $maxValue',
      );

      print(
        'Embedding mean: $meanValue',
      );

      // ----------------------------------------------------------
      // FIRST 10 VALUES
      // ----------------------------------------------------------

      print(
        'First 10 embedding values: '
            '${normalizedEmbedding.take(10).toList()}',
      );

      print('================================');

      return normalizedEmbedding;
    } catch (e, stackTrace) {
      print('================================');
      print(
        '❌ Embedding extraction error',
      );

      print(
        'Error: $e',
      );

      print(
        'StackTrace: $stackTrace',
      );

      print('================================');

      return null;
    }
  }

  // ============================================================
  // L2 NORMALIZATION
  // ============================================================

  List<double> _l2Normalize(
      List<double> embedding,
      ) {
    double sum = 0.0;

    for (final value
    in embedding) {
      sum += value * value;
    }

    final double magnitude =
    sqrt(sum);

    if (magnitude <= 0.0000001) {
      print(
        '⚠️ Embedding magnitude is zero.',
      );

      return embedding;
    }

    return embedding
        .map(
          (value) =>
      value / magnitude,
    )
        .toList();
  }

  // ============================================================
  // COSINE SIMILARITY
  // ============================================================

  double cosineSimilarity(
      List<double> a,
      List<double> b,
      ) {
    if (a.length != 512 ||
        b.length != 512) {
      throw ArgumentError(
        'Both embeddings must contain '
            '512 values.',
      );
    }

    double dotProduct = 0.0;

    for (int i = 0;
    i < 512;
    i++) {
      dotProduct +=
          a[i] * b[i];
    }

    return dotProduct;
  }

  // ============================================================
  // FACE MATCH
  // ============================================================

  bool isFaceMatch({
    required List<double> liveEmbedding,
    required List<double> storedEmbedding,
    double threshold = 0.60,
  }) {
    if (liveEmbedding.length != 512 ||
        storedEmbedding.length != 512) {
      return false;
    }

    final double similarity =
    cosineSimilarity(
      liveEmbedding,
      storedEmbedding,
    );

    print(
      'Face similarity: '
          '${similarity.toStringAsFixed(6)}',
    );

    print(
      'Face threshold: '
          '${threshold.toStringAsFixed(6)}',
    );

    final bool matched =
        similarity >= threshold;

    print(
      matched
          ? '✅ FACE MATCH'
          : '❌ FACE NOT MATCHED',
    );

    return matched;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _faceDetector.close();

    _interpreter?.close();

    _interpreter = null;
  }
  // ============================================================
// STRAIGHT FACE / MOTION CHECK
// ============================================================

  bool isFaceLookingStraight(Face face) {
    final double yaw = face.headEulerAngleY ?? 0.0;
    final double pitch = face.headEulerAngleX ?? 0.0;
    final double roll = face.headEulerAngleZ ?? 0.0;

    print('--------------------------------');
    print('HEAD MOTION CHECK');
    print('Yaw   (Left/Right) : ${yaw.toStringAsFixed(2)}°');
    print('Pitch (Up/Down)    : ${pitch.toStringAsFixed(2)}°');
    print('Roll  (Tilt)       : ${roll.toStringAsFixed(2)}°');

    final bool yawOkay = yaw.abs() <= maxYawAngle;
    final bool pitchOkay = pitch.abs() <= maxPitchAngle;
    final bool rollOkay = roll.abs() <= maxRollAngle;

    if (!yawOkay) {
      print('❌ Face is looking LEFT/RIGHT');
    }

    if (!pitchOkay) {
      print('❌ Face is looking UP/DOWN');
    }

    if (!rollOkay) {
      print('❌ Face is tilted');
    }

    final bool straight = yawOkay && pitchOkay && rollOkay;

    if (straight) {
      print('✅ FACE IS STRAIGHT');
    } else {
      print('❌ FACE IS NOT STRAIGHT');
    }

    print('--------------------------------');

    return straight;
  }
}

