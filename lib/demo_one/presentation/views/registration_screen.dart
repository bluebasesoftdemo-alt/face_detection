
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:convert';
import '../../data/entities/face_registration_data.dart';
import '../../data/usecase/login_face_usecase.dart';
import '../../data/usecase/register_face_usecase.dart';
import '../../domain/datasources/face_processor.dart';
import '../../domain/repositories/login_respository_impl.dart';
import '../../domain/repositories/registration_repository_impl.dart';
class RegistrationScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const RegistrationScreen({
    Key? key,
    required this.cameras,
  }) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {

  CameraController? _cameraController;

  late FaceProcessor _faceProcessor;

  late RegisterFaceUseCase _registerFaceUseCase;

  late LoginFaceUseCase _loginFaceUseCase;

  final Dio _dio = Dio();

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _empIdController = TextEditingController();

  // ============================================================
  // SEPARATE PROCESSING VARIABLES
  // ============================================================

  bool _isLoginProcessing = false;

  bool _isRegisterProcessing = false;


  @override
  void initState() {
    super.initState();

    _faceProcessor = FaceProcessor();

    _registerFaceUseCase =
        RegisterFaceUseCase(
          RegistrationRepositoryImpl(),
        );

    _loginFaceUseCase =
        LoginFaceUseCase(
          LoginRepositoryImpl(),
        );

    _initializeCamera();
  }


  // ============================================================
  // CAMERA INITIALIZATION
  // ============================================================

  Future<void> _initializeCamera() async {

    try {

      final frontCamera =
      widget.cameras.firstWhere(
            (camera) =>
        camera.lensDirection ==
            CameraLensDirection.front,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {});
      }

    } catch (e) {

      _showSnackBar(
        "Camera initialization failed",
      );
    }
  }


  // ============================================================
  // REGISTER FACE
  // ============================================================

  Future<void> _captureAndRegister() async {

    // ----------------------------------------------------------
    // VALIDATE EMPLOYEE ID
    // ----------------------------------------------------------

    final empId =
    _empIdController.text.trim();

    if (empId.isEmpty) {

      _showSnackBar(
        "Please enter Employee ID",
      );

      return;
    }


    // ----------------------------------------------------------
    // CAMERA CHECK
    // ----------------------------------------------------------

    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isLoginProcessing ||
        _isRegisterProcessing) {

      return;
    }


    setState(() {
      _isRegisterProcessing = true;
    });


    try {

      // --------------------------------------------------------
      // CAPTURE IMAGE
      // --------------------------------------------------------

      final XFile photo =
      await _cameraController!.takePicture();


      // --------------------------------------------------------
      // FACE PROCESSING
      // --------------------------------------------------------

      final List<double>? embedding =
      await _faceProcessor.processFace(
        photo.path,
      );


      if (embedding == null) {

        _showSnackBar(
          "No face detected. Please try again.",
        );

        return;
      }


      // --------------------------------------------------------
      // IMAGE TO BASE64
      // --------------------------------------------------------

      final bytes =
      await File(photo.path).readAsBytes();

      final base64Image =
      base64Encode(bytes);


      // --------------------------------------------------------
      // REGISTRATION DATA
      // --------------------------------------------------------

      final registrationData =
      FaceRegistrationData(

        userId: empId,

        userName: empId,

        embedding: embedding,

        faceJpgBase64: base64Image,
      );


      // --------------------------------------------------------
      // CALL REGISTER API
      // --------------------------------------------------------

      final success =
      await _registerFaceUseCase(
        registrationData,
      );


      if (success) {

        _showSnackBar(
          "Face registration successful!",
        );

      } else {

        _showSnackBar(
          "Face registration failed.",
        );
      }

    } catch (e) {

      debugPrint(
        "REGISTER ERROR: $e",
      );

      _showSnackBar(
        "Registration error occurred.",
      );

    } finally {

      if (mounted) {

        setState(() {
          _isRegisterProcessing = false;
        });
      }
    }
  }


  // ============================================================
  // LOGIN USING FACE
  // ============================================================

  Future<void> _loginWithFace() async {

    // ----------------------------------------------------------
    // VALIDATE EMPLOYEE ID
    // ----------------------------------------------------------

    final empId =
    _empIdController.text.trim();
    // ----------------------------------------------------------
    // CAMERA CHECK
    // ----------------------------------------------------------

    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isLoginProcessing ||
        _isRegisterProcessing) {

      return;
    }


    setState(() {
      _isLoginProcessing = true;
    });


    try {

      // --------------------------------------------------------
      // CAPTURE IMAGE
      // --------------------------------------------------------

      final XFile photo =
      await _cameraController!.takePicture();


      // --------------------------------------------------------
      // GENERATE 512-D EMBEDDING
      // --------------------------------------------------------

      final List<double>? embedding =
      await _faceProcessor.processFace(
        photo.path,
      );


      if (embedding == null) {

        _showSnackBar(
          "No face detected. Please try again.",
        );

        return;
      }


      // --------------------------------------------------------
      // LOGIN DATA
      // --------------------------------------------------------

      final loginData =
      FaceRegistrationData(

        userId: "0000",

        userName: "000",

        embedding: embedding,

        // Login does NOT need Base64 image
        faceJpgBase64: "",
      );


      // --------------------------------------------------------
      // CALL LOGIN API
      // --------------------------------------------------------

      final success =
      await _loginFaceUseCase(
        loginData,
      );


      if (success) {

        _showSnackBar(
          "Face login successful!",
        );

        // Navigate to Home here
        //
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) => HomeScreen(),
        //   ),
        // );

      } else {

        _showSnackBar(
          "Face login failed.",
        );
      }

    } catch (e) {

      debugPrint(
        "LOGIN ERROR: $e",
      );

      _showSnackBar(
        "Login error occurred.",
      );

    } finally {

      if (mounted) {

        setState(() {
          _isLoginProcessing = false;
        });
      }
    }
  }


  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(String message,) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }


  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _empIdController.dispose();
    _cameraController?.dispose();
    _faceProcessor.dispose();
    super.dispose();
  }


  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context,) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      backgroundColor:
      const Color(0xFFDF7A2C),
      appBar: AppBar(
        title: const Text(
          "FaceID Connect",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor:
        const Color(0xFFDF7A2C),
      ),
      body: SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.all(20),
          child: Column(
            children: [
              // =================================================
              // EMPLOYEE ID
              // =================================================
              TextFormField(
                controller:
                _empIdController,
                textInputAction:
                TextInputAction.done,
                textCapitalization:
                TextCapitalization.characters,
                decoration:
                InputDecoration(
                  hintText:
                  "Enter Employee ID",
                  prefixIcon:
                  const Icon(
                    Icons.badge,
                  ),
                  filled: true,
                  fillColor:
                  Colors.white,
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),

                    borderSide:
                    BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              // =================================================
              // CAMERA
              // =================================================
              Expanded(
                child: Container(
                  width:
                  double.infinity,
                  padding:
                  const EdgeInsets.all(8),
                  decoration:
                  BoxDecoration(
                    color:
                    Colors.white,
                    borderRadius:
                    BorderRadius.circular(
                      24,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                        Colors.black
                            .withOpacity(
                          0.15,
                        ),
                        blurRadius:
                        12,
                        offset:
                        const Offset(
                          0,
                          5,
                        ),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                    BorderRadius.circular(
                      18,
                    ),
                    child:
                    CameraPreview(
                      controller,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              // =================================================
              // PROCESSING STATUS
              // =================================================
              if (_isLoginProcessing)
                const Padding(padding: EdgeInsets.only(bottom: 10,),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10,),
                      Text("Verifying face...", style: TextStyle(
                          color:
                          Colors.white,
                          fontWeight:
                          FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isRegisterProcessing)
                const Padding(padding:
                  EdgeInsets.only(bottom: 10,),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10,),
                      Text("Registering face...", style: TextStyle(
                          color:
                          Colors.white,
                          fontWeight:
                          FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              // =================================================
              // LOGIN + REGISTER BUTTONS
              // =================================================
              Row(
                children: [
                  // ---------------------------------------------
                  // LOGIN
                  // ---------------------------------------------
                  Expanded(child: SizedBox(
                      height: 52,
                      child:
                      ElevatedButton.icon(
                        onPressed:
                        (_isLoginProcessing ||
                            _isRegisterProcessing)
                            ? null
                            : _loginWithFace,
                        icon:
                        _isLoginProcessing
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(
                          Icons.login,
                        ),
                        label:
                        const Text(
                          "Login",
                          style:
                          TextStyle(
                            fontSize: 15,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                        style:
                        ElevatedButton.styleFrom(
                          backgroundColor:
                          Colors.white,
                          foregroundColor:
                          const Color(
                            0xFFDF7A2C,
                          ),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  // ---------------------------------------------
                  // REGISTER
                  // ---------------------------------------------
                  Expanded(
                    child:
                    SizedBox(

                      height: 52,

                      child:
                      ElevatedButton.icon(

                        onPressed:
                        (_isLoginProcessing ||
                            _isRegisterProcessing)
                            ? null
                            : _captureAndRegister,

                        icon:
                        _isRegisterProcessing
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(
                          Icons.face,
                        ),

                        label:
                        const Text(
                          "Register Face",
                          style:
                          TextStyle(
                            fontSize: 15,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),

                        style:
                        ElevatedButton.styleFrom(

                          backgroundColor:
                          Colors.white,

                          foregroundColor:
                          const Color(
                            0xFFDF7A2C,
                          ),

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),


              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/*
class RegistrationScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const RegistrationScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  CameraController? _cameraController;
  late FaceProcessor _faceProcessor;
  late RegisterFaceUseCase _registerFaceUseCase;
  late LoginFaceUseCase _loginFaceUseCase;
  late Dio _dio;
  bool _isProcessing = false;
  @override
  void initState() {
    super.initState();
    _faceProcessor = FaceProcessor();
    _registerFaceUseCase = RegisterFaceUseCase(RegistrationRepositoryImpl());
    _loginFaceUseCase = LoginFaceUseCase(LoginRepositoryImpl());
    _initializeCamera();
  }

  void _initializeCamera() async {
    // Select front camera for registration
    final frontCamera = widget.cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    _cameraController = CameraController(frontCamera, ResolutionPreset.high, enableAudio: false);
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _captureAndRegister() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final XFile photo = await _cameraController!.takePicture();
      final List<double>? embedding = await _faceProcessor.processFace(photo.path);

      if (embedding == null) {
        _showSnackBar("No face detected. Please try again.");
        return;
      }

      final bytes = await File(photo.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final registrationData = FaceRegistrationData(
        userId: "USER_12345", // Dynamically generated or passed from previous onboarding flow
        userName: "John Doe",
        embedding: embedding,
        faceJpgBase64: base64Image,
      );

      final success = await _registerFaceUseCase(registrationData);
      _showSnackBar(success ? "Registration Successful!" : "Server Registration Failed.");

    } catch (e) {
      _showSnackBar("An error occurred during processing.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  Future<void> _loginAndRegister() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final XFile photo = await _cameraController!.takePicture();
      final List<double>? embedding = await _faceProcessor.processFace(photo.path);

      if (embedding == null) {
        _showSnackBar("No face detected. Please try again.");
        return;
      }

      final bytes = await File(photo.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final registrationData = FaceRegistrationData(
        userId: "USER_12345", // Dynamically generated or passed from previous onboarding flow
        userName: "John Doe",
        embedding: embedding,
        faceJpgBase64: base64Image,
      );

      final success = await _loginFaceUseCase(registrationData);
      _showSnackBar(success ? "Login Successful!" : " Login Failed.");

    } catch (e) {
      _showSnackBar("An error occurred during processing.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceProcessor.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFDF7A2C),
      appBar: AppBar(
        title: const Text("FaceID Connect",style: TextStyle(color: Colors.white),),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFFDF7A2C),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // =========================
              // CAMERA
              // =========================
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CameraPreview(controller),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // =========================
              // PROCESSING TEXT
              // =========================
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Processing face...",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // =========================
              // LOGIN BUTTON
              // =========================
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : _loginAndRegister,
                  icon: const Icon(Icons.login),
                  label: const Text(
                    "Login",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // =========================
              // REGISTER BUTTON
              // =========================
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : _captureAndRegister,
                  icon: const Icon(Icons.face),
                  label: const Text(
                    "Register Face",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
*/
