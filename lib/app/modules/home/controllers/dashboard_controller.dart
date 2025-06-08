import 'package:get/get.dart';
import '../../home/controllers/home_controller.dart';

class DashboardController extends GetxController {
  final HomeController homeC = Get.find();
  var totalRecords = 0.obs;

  @override
  void onInit() {
    super.onInit();
    ever(homeC.moodHistory, (_) {
      totalRecords.value = homeC.moodHistory.length;
    });
  }
}
