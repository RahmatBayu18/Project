import 'package:get/get.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/dashboard_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    // Pastikan HomeController tersedia sebelum DashboardController
    Get.lazyPut<HomeController>(() => HomeController());

    // Baru bind DashboardController
    Get.lazyPut<DashboardController>(() => DashboardController());
  }
}
