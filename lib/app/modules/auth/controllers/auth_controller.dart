import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

import '../../../routes/app_pages.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find<AuthController>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _auth.authStateChanges().listen(_handleAuthChanged);
  }

  void _handleAuthChanged(User? user) {
    if (user != null) {
      if (Get.currentRoute != Routes.DASHBOARD) {
        Get.offAllNamed(Routes.DASHBOARD);
      }
    } else {
      if (Get.currentRoute != Routes.LOGIN) {
        Get.offAllNamed(Routes.LOGIN);
      }
    }
  }

  /* --------------------------- GOOGLE SIGN-IN -------------------------- */
  Future<void> loginWithGoogle() async {
    try {
      isLoading.value = true;

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);

      Get.snackbar(
        'Success',
        'Welcome ${userCred.user?.displayName ?? ''}!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Login Failed',
        'Failed to sign in with Google: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      Get.snackbar(
        'Success',
        'Logged out successfully',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to logout: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
