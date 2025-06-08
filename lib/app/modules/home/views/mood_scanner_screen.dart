import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'dart:typed_data';

import '../controllers/home_controller.dart';

typedef FaceList = List<Face>;

class MoodScannerScreen extends StatefulWidget {
  const MoodScannerScreen({Key? key}) : super(key: key);

  @override
  State<MoodScannerScreen> createState() => _MoodScannerScreenState();
}

class _MoodScannerScreenState extends State<MoodScannerScreen>
    with TickerProviderStateMixin {
  late List<CameraDescription> _cameras;
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _scanRequested = false;
  int _currentCameraIndex = 0;

  String _mood = 'Ready to scan';
  String _music = 'Position your face in the frame';

  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  FaceList _detectedFaces = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCamera();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      await _startController(_cameras[_currentCameraIndex]);
    }
  }

  Future<void> _startController(CameraDescription camera) async {
    _cameraController = CameraController(camera, ResolutionPreset.high);
    try {
      await _cameraController.initialize();
      await _cameraController.startImageStream(_processCameraImage);
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    } on CameraException catch (e) {
      debugPrint('Error initializing camera: $e');
      setState(() => _isCameraInitialized = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isCameraInitialized = false);
    await _cameraController.stopImageStream();
    await _cameraController.dispose();
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _startController(_cameras[_currentCameraIndex]);
  }

  InputImage _inputImageFromCameraImage(CameraImage image) {
    final rotation =
        InputImageRotationValue.fromRawValue(
          _cameraController.description.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;
    final buffer = WriteBuffer();
    for (var plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    final bytes = buffer.done().buffer.asUint8List();
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_isCameraInitialized) return;
    final inputImage = _inputImageFromCameraImage(image);
    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.length != _detectedFaces.length) {
        setState(() => _detectedFaces = faces);
      }
      if (_scanRequested) {
        String detectedMood;
        String recommendedMusic;
        if (faces.isNotEmpty) {
          final face = faces.first;
          final smile = face.smilingProbability ?? 0;
          final leftEye = face.leftEyeOpenProbability ?? 0;
          final rightEye = face.rightEyeOpenProbability ?? 0;
          if (smile > 0.7) {
            detectedMood = 'Happy';
            recommendedMusic = 'Upbeat Pop';
          } else if (leftEye < 0.3 && rightEye < 0.3) {
            detectedMood = 'Sleepy';
            recommendedMusic = 'Calm Instrumental';
          } else if (leftEye > 0.7 && rightEye > 0.7 && smile < 0.2) {
            detectedMood = 'Neutral/Serious';
            recommendedMusic = 'Focus Music';
          } else {
            detectedMood = 'Neutral';
            recommendedMusic = 'Chill music';
          }
        } else {
          detectedMood = 'No Face Detected';
          recommendedMusic = 'Please position your face properly';
        }
        setState(() {
          _mood = detectedMood;
          _music = recommendedMusic;
        });
        // Save record
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().addMood(_mood, _music);
        }
        _scanRequested = false;
        _scanController.reset();

        // Haptic feedback
        HapticFeedback.mediumImpact();
      }
    } catch (e, stk) {
      debugPrint('Error during face detection: $e\n$stk');
      if (_scanRequested) {
        setState(() {
          _mood = 'Error detecting';
          _music = 'Please retry scanning';
        });
        _scanRequested = false;
        _scanController.reset();
      }
    }
  }

  String _getMoodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'sleepy':
        return '😴';
      case 'neutral':
      case 'neutral/serious':
        return '😐';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      case 'no face detected':
        return '🤔';
      case 'error detecting':
        return '❌';
      case 'scanning...':
        return '🔍';
      default:
        return '🎭';
    }
  }

  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return const Color(0xFF10B981);
      case 'sleepy':
        return const Color(0xFF6366F1);
      case 'neutral':
      case 'neutral/serious':
        return const Color(0xFF6B7280);
      case 'sad':
        return const Color(0xFF3B82F6);
      case 'angry':
        return const Color(0xFFEF4444);
      case 'no face detected':
        return const Color(0xFFEAB308);
      case 'error detecting':
        return const Color(0xFFDC2626);
      case 'scanning...':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6366F1);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _cameraController.stopImageStream();
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_isCameraInitialized)
            SizedBox(
              width: width,
              height: height,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController.value.previewSize!.height,
                  height: _cameraController.value.previewSize!.width,
                  child: CameraPreview(_cameraController),
                ),
              ),
            )
          else
            Container(
              width: width,
              height: height,
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF6366F1),
                      ),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Initializing Camera...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Dark overlay
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),

          // Face detection overlay
          if (_isCameraInitialized && _detectedFaces.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: FacePainter(
                  _detectedFaces,
                  Size(
                    _cameraController.value.previewSize!.height,
                    _cameraController.value.previewSize!.width,
                  ),
                  Size(width, height),
                  _cameraController.description.lensDirection ==
                      CameraLensDirection.front,
                ),
              ),
            ),

          // Scanning overlay
          if (_scanRequested)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [
                          0.0,
                          _scanAnimation.value - 0.1,
                          _scanAnimation.value,
                          _scanAnimation.value + 0.1,
                          1.0,
                        ],
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          const Color(0xFF6366F1).withOpacity(0.3),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Top Status Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: _buildStatusCard(),
          ),

          // Center Frame Guide
          Positioned.fill(
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _detectedFaces.isEmpty ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 250,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              _detectedFaces.isEmpty
                                  ? Colors.white.withOpacity(0.5)
                                  : const Color(0xFF10B981),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow:
                            _detectedFaces.isEmpty
                                ? []
                                : [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                      ),
                      child:
                          _detectedFaces.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.face_outlined,
                                      size: 60,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Position your face\nin the frame',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : null,
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 40,
            right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Switch Camera Button
                _buildControlButton(
                  icon: Icons.flip_camera_ios,
                  label: 'Switch',
                  onPressed: _cameras.length > 1 ? _switchCamera : null,
                  isSecondary: true,
                ),

                // Scan Button
                _buildScanButton(),

                // History Button
                _buildControlButton(
                  icon: Icons.history,
                  label: 'History',
                  onPressed: () {
                    Get.find<HomeController>().changeTab(1);
                  },
                  isSecondary: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final moodColor = _getMoodColor(_mood);
    final moodEmoji = _getMoodEmoji(_mood);
    final isError = _mood.toLowerCase().contains('error');
    final isScanning = _mood.toLowerCase().contains('scanning');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: moodColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: moodColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: moodColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child:
                      isScanning
                          ? SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                moodColor,
                              ),
                              strokeWidth: 3,
                            ),
                          )
                          : Text(
                            moodEmoji,
                            style: const TextStyle(fontSize: 30),
                          ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Mood',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mood,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: moodColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isScanning && _mood != 'Ready to scan') ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: moodColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: moodColor.withOpacity(0.2), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.music_note, size: 18, color: moodColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _music,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: () {
        if (_isCameraInitialized && !_scanRequested) {
          setState(() {
            _scanRequested = true;
            _mood = 'Scanning...';
            _music = 'Analyzing your expression...';
          });
          _scanController.forward();
          HapticFeedback.lightImpact();
        } else if (!_isCameraInitialized) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Camera not ready'),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient:
              _scanRequested
                  ? LinearGradient(
                    colors: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                  )
                  : LinearGradient(
                    colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                  ),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
        ),
        child:
            _scanRequested
                ? const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                )
                : const Icon(
                  Icons.center_focus_strong,
                  color: Colors.white,
                  size: 40,
                ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isSecondary = false,
  }) {
    return GestureDetector(
      onTap:
          onPressed != null
              ? () {
                HapticFeedback.lightImpact();
                onPressed();
              }
              : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color:
              isSecondary
                  ? Colors.white.withOpacity(0.9)
                  : const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: (isSecondary ? Colors.black : const Color(0xFF6366F1))
                  .withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border:
              isSecondary
                  ? Border.all(color: Colors.grey.withOpacity(0.3), width: 1)
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSecondary ? Colors.grey[700] : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSecondary ? Colors.grey[700] : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final FaceList faces;
  final Size imageSize;
  final Size widgetSize;
  final bool isFront;

  FacePainter(this.faces, this.imageSize, this.widgetSize, this.isFront);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF10B981);

    final shadowPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = const Color(0xFF10B981).withOpacity(0.3);

    final imageAR = imageSize.width / imageSize.height;
    final widgetAR = widgetSize.width / widgetSize.height;
    double scaleX, scaleY, offsetX = 0, offsetY = 0;

    if (imageAR > widgetAR) {
      scaleY = widgetSize.height / imageSize.height;
      scaleX = scaleY;
      offsetX = (widgetSize.width - imageSize.width * scaleX) / 2;
    } else {
      scaleX = widgetSize.width / imageSize.width;
      scaleY = scaleX;
      offsetY = (widgetSize.height - imageSize.height * scaleY) / 2;
    }

    for (var face in faces) {
      double left = face.boundingBox.left * scaleX + offsetX;
      double right = face.boundingBox.right * scaleX + offsetX;
      double top = face.boundingBox.top * scaleY + offsetY;
      double bottom = face.boundingBox.bottom * scaleY + offsetY;

      if (isFront) {
        final temp = left;
        left = widgetSize.width - right;
        right = widgetSize.width - temp;
      }

      final rect = Rect.fromLTRB(left, top, right, bottom);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(15));

      // Draw shadow
      canvas.drawRRect(rrect, shadowPaint);
      // Draw main border
      canvas.drawRRect(rrect, paint);

      // Draw corner indicators
      _drawCornerIndicators(canvas, rect);
    }
  }

  void _drawCornerIndicators(Canvas canvas, Rect rect) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF10B981);

    final fillPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF10B981);

    const cornerLength = 20.0;

    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      paint,
    );

    // Center dot
    canvas.drawCircle(rect.center, 4, fillPaint);
  }

  @override
  bool shouldRepaint(covariant FacePainter old) {
    if (old.faces.length != faces.length) return true;
    for (int i = 0; i < faces.length; i++) {
      if (faces[i].boundingBox != old.faces[i].boundingBox) return true;
    }
    return old.isFront != isFront;
  }
}
