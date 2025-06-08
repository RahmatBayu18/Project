import 'package:get/get.dart';

class HomeController extends GetxController {
  var currentIndex = 0.obs;

  // Simulasi histori mood
  var moodHistory =
      <Map<String, String>>[
        {
          "mood": "Happy",
          "music": "Pharrell Williams - Happy",
          "timestamp": "2025-06-07 14:23",
        },
      ].obs;

  void addMood(String mood, String music) {
    moodHistory.add({
      'mood': mood,
      'music': music,
      'timestamp': DateTime.now().toString(),
    });
  }

  void changeTab(int index) {
    currentIndex.value = index;
  }
}
