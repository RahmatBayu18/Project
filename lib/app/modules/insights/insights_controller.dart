import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../../../models/mood_record.dart';
import '../home/controllers/home_controller.dart';

class InsightsController extends GetxController {
  final HomeController homeC = Get.find();

  late TooltipBehavior _tooltipBehavior;
  late ZoomPanBehavior _zoomPanBehavior;

  TooltipBehavior get tooltipBehavior => _tooltipBehavior;
  ZoomPanBehavior get zoomPanBehavior => _zoomPanBehavior;

  final selectedPeriod = 'Weekly'.obs;
  final moodDistribution = <String, int>{}.obs;
  final weeklyTrend = <ChartData>[].obs;
  final moodInsights = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enableDoubleTapZooming: true,
      enablePanning: true,
    );
    ever(homeC.moodHistory, (_) => _analyzeMoodData());
  }

  void _analyzeMoodData() {
    _calculateMoodDistribution();
    _calculateWeeklyTrend();
    _generateInsights();
  }

  void _calculateMoodDistribution() {
    moodDistribution.clear();
    for (var record in homeC.moodHistory) {
      moodDistribution[record.mood] = (moodDistribution[record.mood] ?? 0) + 1;
    }
  }

  void _calculateWeeklyTrend() {
    weeklyTrend.clear();
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    // Kelompokkan berdasarkan minggu
    final weeklyData = <String, Map<String, int>>{};

    for (var record in homeC.moodHistory) {
      final weekKey = record.weekNumber;
      weeklyData.putIfAbsent(weekKey, () => {});
      weeklyData[weekKey]![record.mood] =
          (weeklyData[weekKey]![record.mood] ?? 0) + 1;
    }

    // Konversi ke format chart
    for (var entry in weeklyData.entries) {
      final dominantMood =
          entry.value.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      weeklyTrend.add(
        ChartData(
          entry.key,
          entry.value.values.reduce((a, b) => a + b),
          dominantMood,
        ),
      );
    }
  }

  void _generateInsights() {
    if (homeC.moodHistory.isEmpty) {
      moodInsights.value =
          'Mulai scan mood Anda untuk mendapatkan insight personal';
      return;
    }

    // Hitung mood paling sering
    final mostCommonMood =
        moodDistribution.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

    // Hitung tren mingguan
    final lastTwoWeeks =
        weeklyTrend.length >= 2
            ? weeklyTrend.sublist(weeklyTrend.length - 2, weeklyTrend.length)
            : [];

    String trend = '';
    if (lastTwoWeeks.length == 2) {
      final diff = lastTwoWeeks[1].value - lastTwoWeeks[0].value;
      if (diff > 0) {
        trend = 'meningkat ${diff.abs()}% dari minggu lalu';
      } else if (diff < 0) {
        trend = 'menurun ${diff.abs()}% dari minggu lalu';
      } else {
        trend = 'stabil sama dengan minggu lalu';
      }
    }

    // Generate insight
    moodInsights.value =
        'Mood dominan Anda adalah $mostCommonMood. '
        'Tren mood Anda $trend. '
        'Saat mood $mostCommonMood, coba dengarkan musik yang direkomendasikan untuk membantu meningkatkan perasaan Anda.';
  }
}

class ChartData {
  ChartData(this.week, this.value, this.dominantMood);
  final String week;
  final int value;
  final String dominantMood;
}
