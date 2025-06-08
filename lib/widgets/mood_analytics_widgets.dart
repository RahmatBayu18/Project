// lib/widgets/mood_analytics_widgets.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/mood_analytics_service.dart';
import '../models/mood_record.dart';

class MoodDistributionChart extends StatelessWidget {
  final List<MoodRecord> records;

  const MoodDistributionChart({Key? key, required this.records})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final distribution = MoodAnalyticsService.getMoodDistribution(records);

    if (distribution.isEmpty) {
      return const Center(
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      height: 200,
      child: PieChart(
        PieChartData(
          sections:
              distribution.entries.map((entry) {
                return PieChartSectionData(
                  color: _getMoodColor(entry.key),
                  value: entry.value.toDouble(),
                  title: '${entry.value}',
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  radius: 60,
                );
              }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
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
}

class MoodTrendChart extends StatelessWidget {
  final List<MoodRecord> records;
  final String period; // 'daily', 'weekly', 'monthly'

  const MoodTrendChart({Key? key, required this.records, this.period = 'daily'})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<FlSpot> spots = [];
    List<String> labels = [];

    if (period == 'daily') {
      final dailyData = MoodAnalyticsService.getDailyMoodData(records);
      for (int i = 0; i < dailyData.length; i++) {
        spots.add(FlSpot(i.toDouble(), _getMoodValue(dailyData[i].mood)));
        labels.add(DateFormat('E').format(dailyData[i].date));
      }
    } else if (period == 'weekly') {
      final weeklyData = MoodAnalyticsService.getWeeklyMoodData(records);
      for (int i = 0; i < weeklyData.length; i++) {
        final avgMoodValue = _calculateAverageMoodValue(
          weeklyData[i].moodDistribution,
        );
        spots.add(FlSpot(i.toDouble(), avgMoodValue));
        labels.add('W${i + 1}');
      }
    }

    if (spots.isEmpty) {
      return const Center(
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.3),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < labels.length) {
                    return Text(
                      labels[value.toInt()],
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 1:
                      return const Text('😢', style: TextStyle(fontSize: 12));
                    case 2:
                      return const Text('😐', style: TextStyle(fontSize: 12));
                    case 3:
                      return const Text('😊', style: TextStyle(fontSize: 12));
                    default:
                      return const Text('');
                  }
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: spots.length - 1.0,
          minY: 0,
          maxY: 4,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF6366F1),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: const Color(0xFF6366F1),
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF6366F1).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getMoodValue(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return 3;
      case 'neutral':
        return 2;
      case 'sleepy':
        return 2;
      case 'sad':
        return 1;
      case 'angry':
        return 1;
      default:
        return 2;
    }
  }

  double _calculateAverageMoodValue(Map<String, int> distribution) {
    if (distribution.isEmpty) return 2;

    double total = 0;
    int count = 0;

    distribution.forEach((mood, freq) {
      total += _getMoodValue(mood) * freq;
      count += freq;
    });

    return count > 0 ? total / count : 2;
  }
}

class MoodInsightsCard extends StatelessWidget {
  final List<MoodRecord> records;

  const MoodInsightsCard({Key? key, required this.records}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final insights = MoodAnalyticsService.generateInsights(records);

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
                Icon(Icons.psychology, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Mood Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Most Frequent',
                    insights.mostFrequentMood,
                    _getMoodEmoji(insights.mostFrequentMood),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Current Streak',
                    '${insights.moodStreak} days',
                    '🔥',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Trend',
                    insights.moodTrend,
                    _getTrendEmoji(insights.moodTrend),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Recommendations
            Text(
              'Personalized Tips',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),

            ...insights.recommendations
                .map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getMoodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      case 'sleepy':
        return '😴';
      case 'neutral':
        return '😐';
      default:
        return '🤔';
    }
  }

  String _getTrendEmoji(String trend) {
    switch (trend) {
      case 'Improving':
        return '📈';
      case 'Declining':
        return '📉';
      case 'Stable':
        return '➖';
      default:
        return '❓';
    }
  }
}

class AnalyticsPeriodSelector extends StatelessWidget {
  final String selectedPeriod;
  final Function(String) onPeriodChanged;

  const AnalyticsPeriodSelector({
    Key? key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildPeriodButton('Daily', 'daily'),
          _buildPeriodButton('Weekly', 'weekly'),
          _buildPeriodButton('Monthly', 'monthly'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = selectedPeriod == period;

    return Expanded(
      child: GestureDetector(
        onTap: () => onPeriodChanged(period),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
