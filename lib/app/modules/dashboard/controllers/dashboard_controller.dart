import 'package:get/get.dart';
import '../../home/controllers/home_controller.dart';
import '../../../../services/ai_tips_service.dart';

class DashboardController extends GetxController {
  final HomeController homeC = Get.find<HomeController>();
  final AITipsService _aiTipsService = AITipsService();

  // Observable untuk total records
  late final RxInt totalRecords;

  // Observable untuk AI tips
  final RxString aiTip = ''.obs;
  final RxBool isLoadingTip = false.obs;
  final RxString tipError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    totalRecords = homeC.moodHistory.length.obs;

    // Listen to mood history changes
    ever(homeC.moodHistory, (_) {
      totalRecords.value = homeC.moodHistory.length;
      // Generate new tip when mood history updates
      generateAITip();
    });

    // Generate initial tip
    generateAITip();
  }

  Future<void> generateAITip() async {
    if (homeC.moodHistory.isEmpty) {
      aiTip.value =
          'Mulai tracking mood Anda untuk mendapatkan tips personal dari AI!';
      return;
    }

    try {
      isLoadingTip.value = true;
      tipError.value = '';

      final tip = await _aiTipsService.generatePersonalizedTip(
        homeC.moodHistory.toList(),
      );

      aiTip.value = tip;
    } catch (e) {
      tipError.value = 'Gagal memuat tips AI';
      aiTip.value =
          'Luangkan waktu untuk merefleksikan perasaan Anda hari ini.';
    } finally {
      isLoadingTip.value = false;
    }
  }

  Future<void> refreshAITip() async {
    await generateAITip();
  }
}
