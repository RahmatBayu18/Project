import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../models/mood_record.dart';
import '../../../../services/mood_services.dart';

class HomeController extends GetxController {
  late final MoodService _service;
  var moodHistory = <MoodRecord>[].obs;
  var currentIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _service = MoodService(user.uid);
      _service.streamMoodHistory().listen((records) {
        moodHistory.value = records;
      });
    }
  }

  void addMood(String mood, String music, {String note = ''}) {
    if (_service != null) {
      final record = MoodRecord(
        mood: mood,
        music: music,
        timestamp: DateTime.now(),
        note: note, // Tambahkan note
      );
      _service.addMood(record);
    }
  }

  void changeTab(int index) => currentIndex.value = index;
}
