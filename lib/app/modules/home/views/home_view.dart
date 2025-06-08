import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import 'mood_scanner_screen.dart';
import 'mood_history_screen.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController c = Get.put(HomeController());

    final pages = [
      const MoodScannerScreen(),
      const MoodHistoryScreen(),
    ];

    return Obx(() => Scaffold(
          body: pages[c.currentIndex.value],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: c.currentIndex.value,
            onTap: c.changeTab,
            selectedItemColor: Colors.amber,
            backgroundColor: Colors.black,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner),
                label: 'Scan Mood',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'History',
              ),
            ],
          ),
        ));
  }
}