import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../modules/auth/views/login_view.dart';
import '../modules/dashboard/views/dashboard_view.dart';
import '../modules/home/views/home_view.dart';

import '../modules/auth/bindings/auth_binding.dart';
import '../modules/dashboard/bindings/dashboard_binding.dart';
import '../modules/home/bindings/home_binding.dart';

import '../../app/modules/auth/controllers/auth_controller.dart';

part 'app_routes.dart';

/* ----------------------- MIDDLEWARE UNTUK AUTH ------------------------ */
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final user = FirebaseAuth.instance.currentUser; // <— ambil user di sini

    // Belum login → paksa ke LOGIN
    if (user == null && route != Routes.LOGIN) {
      return const RouteSettings(name: Routes.LOGIN);
    }
    // Sudah login → cegah kembali ke LOGIN
    if (user != null && route == Routes.LOGIN) {
      return const RouteSettings(name: Routes.DASHBOARD);
    }
    return null; // lanjut normal
  }
}

class AppPages {
  AppPages._();
  static const INITIAL = Routes.LOGIN;

  static final routes = [
    GetPage(
      name: Routes.LOGIN,
      page: () => const LoginView(),
      binding: AuthBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.DASHBOARD,
      page: () => const DashboardView(),
      binding: DashboardBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
      middlewares: [AuthMiddleware()],
    ),
  ];
}
