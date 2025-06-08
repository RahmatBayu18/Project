// lib/app/modules/home/views/mood_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../../../widgets/mood_analytics_widgets.dart';
import '../../../../services/mood_analytics_service.dart';

import '../../../../models/mood_record.dart';

class MoodAnalyticsScreen extends StatefulWidget {
  const MoodAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<MoodAnalyticsScreen> createState() => _MoodAnalyticsScreenState();
}

class _MoodAnalyticsScreenState extends State<MoodAnalyticsScreen> {
  String selectedPeriod = 'daily';

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Mood Analytics"),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Obx(() {
        final records = controller.moodHistory;

        if (records.isEmpty) {
          return _buildEmptyState();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Insights Card
              MoodInsightsCard(records: records),

              const SizedBox(height: 24),

              // Mood Distribution
              _buildSectionCard(
                title: 'Mood Distribution',
                icon: Icons.pie_chart,
                child: Column(
                  children: [
                    MoodDistributionChart(records: records),
                    const SizedBox(height: 16),
                    _buildMoodLegend(records),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Mood Trends
              _buildSectionCard(
                title: 'Mood Trends',
                icon: Icons.trending_up,
                child: Column(
                  children: [
                    AnalyticsPeriodSelector(
                      selectedPeriod: selectedPeriod,
                      onPeriodChanged: (period) {
                        setState(() {
                          selectedPeriod = period;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    MoodTrendChart(records: records, period: selectedPeriod),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Statistics Summary
              _buildStatisticsSummary(records),

              const SizedBox(height: 24),

              // Time Analysis
              _buildTimeAnalysis(records),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No analytics data yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Start tracking your mood to see detailed analytics",
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Start Scanning'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildMoodLegend(List<MoodRecord> records) {
    final distribution = MoodAnalyticsService.getMoodDistribution(records);

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children:
          distribution.entries.map((entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getMoodColor(entry.key),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${entry.key} (${entry.value})',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
    );
  }

  Widget _buildStatisticsSummary(List<MoodRecord> records) {
    final insights = MoodAnalyticsService.generateInsights(records);

    return _buildSectionCard(
      title: 'Statistics Summary',
      icon: Icons.bar_chart,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Entries',
                  records.length.toString(),
                  Icons.edit_note,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Avg Daily',
                  insights.averageDailyEntries.toStringAsFixed(1),
                  Icons.calendar_today,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Best Streak',
                  '${insights.moodStreak} days',
                  Icons.local_fire_department,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Trend',
                  insights.moodTrend,
                  Icons.trending_up,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAnalysis(List<MoodRecord> records) {
    final hourCounts = <int, int>{};
    for (var record in records) {
      final hour = record.timestamp.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    final mostActiveHour =
        hourCounts.isNotEmpty
            ? hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
            : 12;

    final timeOfDay = _getTimeOfDay(mostActiveHour);
    final moodCount = hourCounts[mostActiveHour] ?? 0;

    return _buildSectionCard(
      title: 'Time Analysis',
      icon: Icons.access_time,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.purple.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  _getTimeIcon(mostActiveHour),
                  size: 48,
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                Text(
                  'Most Active Time',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatHour(mostActiveHour)} ($timeOfDay)',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$moodCount entries logged',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTimeRecommendation(mostActiveHour),
        ],
      ),
    );
  }

  Widget _buildTimeRecommendation(int hour) {
    String recommendation;
    IconData icon;
    Color color;

    if (hour >= 6 && hour < 12) {
      recommendation = "Morning entries help set a positive tone for your day!";
      icon = Icons.wb_sunny;
      color = Colors.orange;
    } else if (hour >= 12 && hour < 18) {
      recommendation = "Afternoon check-ins are great for midday reflection.";
      icon = Icons.wb_cloudy;
      color = Colors.blue;
    } else if (hour >= 18 && hour < 22) {
      recommendation =
          "Evening reflection helps process your day's experiences.";
      icon = Icons.nightlight_round;
      color = Colors.indigo;
    } else {
      recommendation =
          "Late night entries suggest you're a night owl! Consider consistent timing.";
      icon = Icons.bedtime;
      color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              recommendation,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return const Color(0xFF10B981);
      case 'sad':
        return const Color(0xFF3B82F6);
      case 'angry':
        return const Color(0xFFEF4444);
      case 'sleepy':
        return const Color(0xFF6366F1);
      case 'neutral':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  String _getTimeOfDay(int hour) {
    if (hour >= 6 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 18) return 'Afternoon';
    if (hour >= 18 && hour < 22) return 'Evening';
    return 'Night';
  }

  IconData _getTimeIcon(int hour) {
    if (hour >= 6 && hour < 12) return Icons.wb_sunny;
    if (hour >= 12 && hour < 18) return Icons.wb_cloudy;
    if (hour >= 18 && hour < 22) return Icons.nightlight_round;
    return Icons.bedtime;
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }
}
