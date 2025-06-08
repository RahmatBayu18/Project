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

class _MoodScannerScreenState extends State<MoodScannerScreen> {
  late List<CameraDescription> _cameras;
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _scanRequested = false;
  int _currentCameraIndex = 0;

  String _mood = 'No Face Detected';
  String _music = 'No recommendation';

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
    _initializeCamera();
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
          recommendedMusic = 'No recommendation';
        }
        setState(() {
          _mood = detectedMood;
          _music = recommendedMusic;
        });
        // Simpan record
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().addMood(_mood, _music);
        }
        _scanRequested = false;
      }
    } catch (e, stk) {
      debugPrint('Error during face detection: $e\n$stk');
      if (_scanRequested) {
        setState(() {
          _mood = 'Error detecting';
          _music = 'Please retry';
        });
        _scanRequested = false;
      }
    }
  }

  @override
  void dispose() {
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
      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
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
            const Center(child: CircularProgressIndicator()),
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
          Positioned(top: 50, left: 20, right: 20, child: _buildResultCard()),
          Positioned(
            bottom: 100,
            left: 40,
            right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _switchCamera,
                  icon: const Icon(Icons.cameraswitch, color: Colors.amber),
                  label: const Text(
                    'Switch',
                    style: TextStyle(color: Colors.amber),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_isCameraInitialized) {
                      setState(() {
                        _scanRequested = true;
                        _mood = 'Scanning...';
                        _music = 'Please wait...';
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Camera not ready')),
                      );
                    }
                  },
                  icon: const Icon(Icons.search, color: Colors.amber),
                  label: const Text(
                    'Scan Mood',
                    style: TextStyle(color: Colors.amber),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final isError = _mood.toLowerCase().startsWith('error');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mood: $_mood',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isError ? Colors.red : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Music Recommendation:\n$_music',
            style: TextStyle(
              fontSize: 16,
              color: isError ? Colors.redAccent : Colors.black87,
            ),
          ),
        ],
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
          ..strokeWidth = 3
          ..color = Colors.greenAccent;
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
      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
    }
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
