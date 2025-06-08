import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'dart:typed_data';

import '../controllers/home_controller.dart';

class MoodScannerScreen extends StatefulWidget {
  const MoodScannerScreen({Key? key}) : super(key: key);

  @override
  State<MoodScannerScreen> createState() => _MoodScannerScreenState();
}

class _MoodScannerScreenState extends State<MoodScannerScreen> {
  late CameraController _cameraController;
  late List<CameraDescription> _cameras;
  bool _isCameraInitialized = false;
  bool _scanRequested = false; // Hanya untuk memicu update mood/musik

  String _mood = "No Face Detected"; // Default initial mood
  String _music = "No recommendation"; // Default initial music

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast, // Menggunakan mode fast untuk real-time
    ),
  );

  List<Face> _detectedFaces = []; // Variabel untuk menyimpan wajah terdeteksi

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    // Gunakan ResolutionPreset.high atau medium untuk keseimbangan performa real-time dan akurasi
    _cameraController = CameraController(_cameras[0], ResolutionPreset.high); 

    try {
      await _cameraController.initialize();
      if (!mounted) return;

      _cameraController.startImageStream((image) => _processCameraImage(image));
      setState(() {
        _isCameraInitialized = true;
      });
      print("Camera Initialized: true");
    } on CameraException catch (e) {
      print("Error initializing camera: $e");
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  InputImage _inputImageFromCameraImage(CameraImage image) {
    // Debugging: Lihat orientasi sensor kamera
    // print("Camera Sensor Orientation: ${_cameraController.description.sensorOrientation}");

    final InputImageRotation imageRotation =
        InputImageRotationValue.fromRawValue(
              _cameraController.description.sensorOrientation,
            ) ??
            InputImageRotation.rotation0deg;
    // print("InputImage Rotation set to: $imageRotation");

    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // Debugging: Lihat format gambar mentah
    // print("CameraImage format raw: ${image.format.raw}");
    // print("CameraImage format group: ${image.format.group}");

    InputImageFormat inputImageFormat = InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    // --- PENTING: TIDAK ADA LAGI `if (!_scanRequested) return;` di sini ---
    // Ini memastikan ML Kit selalu memproses gambar untuk deteksi wajah real-time.

    if (image.format.group != ImageFormatGroup.yuv420 && image.format.group != ImageFormatGroup.bgra8888) {
      print("Unsupported image format group: ${image.format.group}");
      // Set _detectedFaces kosong jika format tidak didukung untuk mencegah error rendering
      if (_detectedFaces.isNotEmpty) {
        setState(() {
          _detectedFaces = [];
        });
      }
      return;
    }

    final inputImage = _inputImageFromCameraImage(image);

    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      
      // Update _detectedFaces secara real-time untuk FacePainter
      if (_detectedFaces.length != faces.length || !_listEquals(_detectedFaces, faces)) {
         setState(() {
          _detectedFaces = faces; 
         });
      }
     
      // Debugging: Lihat berapa wajah yang terdeteksi secara real-time
      // print("ML Kit detected faces count: ${faces.length}");

      // Logika deteksi mood, hanya berjalan jika _scanRequested adalah true
      if (_scanRequested) {
        if (faces.isNotEmpty) {
          final Face face = faces.first;
          String detectedMood = "Neutral";
          String recommendedMusic = "Chill music";

          // --- Logika Deteksi Mood Anda ---
          if (face.smilingProbability != null && face.smilingProbability! > 0.7) {
            detectedMood = "Happy";
            recommendedMusic = "Upbeat Pop";
          } else if (face.leftEyeOpenProbability != null &&
              face.leftEyeOpenProbability! < 0.3 &&
              face.rightEyeOpenProbability != null &&
              face.rightEyeOpenProbability! < 0.3) {
            detectedMood = "Sleepy";
            recommendedMusic = "Calm Instrumental";
          } else if (face.leftEyeOpenProbability != null &&
              face.leftEyeOpenProbability! > 0.7 &&
              face.rightEyeOpenProbability != null &&
              face.rightEyeOpenProbability! > 0.7 &&
              face.smilingProbability != null &&
              face.smilingProbability! < 0.2) {
            detectedMood = "Neutral/Serious";
            recommendedMusic = "Focus Music";
          }
          // --- Akhir Logika Deteksi Mood ---

          // Hanya update mood di UI jika ada perubahan
          if (_mood != detectedMood) {
            setState(() {
              _mood = detectedMood;
              _music = recommendedMusic;
            });
            if (Get.isRegistered<HomeController>()) {
              Get.find<HomeController>().addMood(_mood, _music);
            }
          }
          _scanRequested = false; // Reset permintaan scan mood setelah deteksi
        } else {
          // Jika tidak ada wajah saat scan mood diminta
          setState(() {
            _mood = "No Face Detected";
            _music = "No recommendation";
          });
          _scanRequested = false; // Reset permintaan scan mood
        }
      }
    } catch (e) {
      print("Error during face detection: $e");
      // Pastikan kotak juga hilang jika ada error pemrosesan
      if (_detectedFaces.isNotEmpty) {
        setState(() {
          _detectedFaces = [];
        });
      }
      // Jika terjadi error, dan scan sedang diminta, berikan feedback
      if (_scanRequested) {
        setState(() {
          _mood = "Error";
          _music = "Please retry scan";
        });
        _scanRequested = false;
      }
    }
  }

  // Helper untuk membandingkan list Face (bukan hanya referensi objek)
  bool _listEquals(List<Face> list1, List<Face> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].boundingBox != list2[i].boundingBox) {
        return false;
      }
    }
    return true;
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isCameraInitialized)
              Container(
                height: double.infinity,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                child: ClipRRect(
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController.value.previewSize!.height,
                        height: _cameraController.value.previewSize!.width,
                        child: CameraPreview(_cameraController),
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: double.infinity,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),

            // CustomPaint untuk menggambar kotak deteksi wajah
            // Sekarang selalu aktif jika kamera siap dan ada wajah terdeteksi
            if (_isCameraInitialized && _detectedFaces.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: FacePainter(
                    _detectedFaces,
                    // imageSize: Ukuran gambar yang diproses oleh ML Kit
                    Size(
                      _cameraController.value.previewSize!.height,
                      _cameraController.value.previewSize!.width,
                    ),
                    // widgetSize: Ukuran aktual dari area tampilan CameraPreview (ukuran layar penuh)
                    Size(screenWidth, screenHeight),
                    _cameraController.description.lensDirection == CameraLensDirection.front, // Teruskan info kamera depan
                  ),
                ),
              ),

            // Kotak putih untuk menampilkan hasil detektor
            Positioned(
              top: 50,
              child: Container(
                padding: const EdgeInsets.all(16),
                width: 320,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mood: $_mood",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Rekomendasi Musik:\n$_music",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            // Tombol Scan Mood
            Positioned(
              bottom: 100,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.search),
                label: const Text(
                  "Scan Mood",
                  style: TextStyle(fontSize: 16, color: Colors.amber),
                ),
                onPressed: () {
                  if (_isCameraInitialized) {
                    setState(() {
                      _scanRequested = true; // Mengaktifkan permintaan scan mood
                      _mood = "Scanning..."; // Umpan balik visual di kotak putih
                      _music = "Please wait...";
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Camera is not ready yet.')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;   // Ukuran gambar yang diproses ML Kit
  final Size widgetSize;  // Ukuran widget CameraPreview di layar
  final bool isFrontCamera; // Menunjukkan apakah kamera depan digunakan

  FacePainter(this.faces, this.imageSize, this.widgetSize, this.isFrontCamera);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = Colors.greenAccent;

    // Perhitungan transformasi untuk BoxFit.cover
    final double imageAspectRatio = imageSize.width / imageSize.height;
    final double widgetAspectRatio = widgetSize.width / widgetSize.height;

    double scaleX, scaleY;
    double offsetX = 0;
    double offsetY = 0;

    if (imageAspectRatio > widgetAspectRatio) {
      scaleY = widgetSize.height / imageSize.height;
      scaleX = scaleY;
      offsetX = (widgetSize.width - (imageSize.width * scaleX)) / 2;
    } else {
      scaleX = widgetSize.width / imageSize.width;
      scaleY = scaleX;
      offsetY = (widgetSize.height - (imageSize.height * scaleY)) / 2;
    }

    for (final face in faces) {
      double transformedLeft = face.boundingBox.left * scaleX + offsetX;
      double transformedRight = face.boundingBox.right * scaleX + offsetX;
      double transformedTop = face.boundingBox.top * scaleY + offsetY;
      double transformedBottom = face.boundingBox.bottom * scaleY + offsetY;

      // --- Logika Mirroring untuk Kamera Depan ---
      if (isFrontCamera) {
        // Ini akan membalik koordinat X secara horizontal
        double tempLeft = transformedLeft;
        transformedLeft = widgetSize.width - transformedRight;
        transformedRight = widgetSize.width - tempLeft;
      }
      // --- Akhir Logika Mirroring ---

      final rect = Rect.fromLTRB(
        transformedLeft,
        transformedTop,
        transformedRight,
        transformedBottom,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces.length != faces.length ||
           !_listDeepEquals(oldDelegate.faces, faces) ||
           oldDelegate.imageSize != imageSize ||
           oldDelegate.widgetSize != widgetSize ||
           oldDelegate.isFrontCamera != isFrontCamera; // Tambahkan perbandingan isFrontCamera
  }

  // Helper function untuk membandingkan list Face secara mendalam
  bool _listDeepEquals(List<Face> list1, List<Face> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].boundingBox != list2[i].boundingBox) {
        return false;
      }
    }
    return true;
  }
}