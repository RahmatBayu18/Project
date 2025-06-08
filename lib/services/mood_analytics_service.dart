// lib/services/mood_analytics_service.dart
import '../models/mood_record.dart';

class MoodAnalyticsService {
  static Map<String, int> getMoodDistribution(List<MoodRecord> records) {
    Map<String, int> distribution = {};

    for (var record in records) {
      distribution[record.mood] = (distribution[record.mood] ?? 0) + 1;
    }

    return distribution;
  }

  static List<DailyMoodData> getDailyMoodData(
    List<MoodRecord> records, {
    int days = 7,
  }) {
    final now = DateTime.now();
    List<DailyMoodData> dailyData = [];

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayRecords =
          records
              .where(
                (record) =>
                    record.timestamp.year == date.year &&
                    record.timestamp.month == date.month &&
                    record.timestamp.day == date.day,
              )
              .toList();

      String dominantMood = 'neutral';
      if (dayRecords.isNotEmpty) {
        final moodCounts = getMoodDistribution(dayRecords);
        dominantMood =
            moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }

      dailyData.add(
        DailyMoodData(date: date, mood: dominantMood, count: dayRecords.length),
      );
    }

    return dailyData;
  }

  static List<WeeklyMoodData> getWeeklyMoodData(
    List<MoodRecord> records, {
    int weeks = 4,
  }) {
    final now = DateTime.now();
    List<WeeklyMoodData> weeklyData = [];

    for (int i = weeks - 1; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final weekRecords =
          records
              .where(
                (record) =>
                    record.timestamp.isAfter(
                      weekStart.subtract(const Duration(days: 1)),
                    ) &&
                    record.timestamp.isBefore(
                      weekEnd.add(const Duration(days: 1)),
                    ),
              )
              .toList();

      final moodDistribution = getMoodDistribution(weekRecords);

      weeklyData.add(
        WeeklyMoodData(
          weekStart: weekStart,
          weekEnd: weekEnd,
          moodDistribution: moodDistribution,
          totalCount: weekRecords.length,
        ),
      );
    }

    return weeklyData;
  }

  static List<MonthlyMoodData> getMonthlyMoodData(
    List<MoodRecord> records, {
    int months = 6,
  }) {
    final now = DateTime.now();
    List<MonthlyMoodData> monthlyData = [];

    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0);

      final monthRecords =
          records
              .where(
                (record) =>
                    record.timestamp.year == month.year &&
                    record.timestamp.month == month.month,
              )
              .toList();

      final moodDistribution = getMoodDistribution(monthRecords);

      monthlyData.add(
        MonthlyMoodData(
          month: month,
          moodDistribution: moodDistribution,
          totalCount: monthRecords.length,
        ),
      );
    }

    return monthlyData;
  }

  static MoodInsights generateInsights(List<MoodRecord> records) {
    if (records.isEmpty) {
      return MoodInsights(
        mostFrequentMood: 'No data',
        moodStreak: 0,
        averageDailyEntries: 0,
        moodTrend: 'No trend',
        recommendations: [
          'Start tracking your mood to get personalized insights!',
        ],
      );
    }

    // Most frequent mood
    final moodDistribution = getMoodDistribution(records);
    final mostFrequentMood =
        moodDistribution.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

    // Current streak
    final streak = _calculateCurrentStreak(records);

    // Average daily entries
    final oldestRecord = records.reduce(
      (a, b) => a.timestamp.isBefore(b.timestamp) ? a : b,
    );
    final daysSinceFirst =
        DateTime.now().difference(oldestRecord.timestamp).inDays + 1;
    final averageDailyEntries = (records.length / daysSinceFirst).toDouble();

    // Mood trend (last 7 days vs previous 7 days)
    final moodTrend = _calculateMoodTrend(records);

    // Generate recommendations
    final recommendations = _generateRecommendations(
      records,
      mostFrequentMood,
      moodTrend,
    );

    return MoodInsights(
      mostFrequentMood: mostFrequentMood,
      moodStreak: streak,
      averageDailyEntries: averageDailyEntries,
      moodTrend: moodTrend,
      recommendations: recommendations,
    );
  }

  static int _calculateCurrentStreak(List<MoodRecord> records) {
    if (records.isEmpty) return 0;

    final sortedRecords =
        records.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    int streak = 0;
    DateTime? lastDate;

    for (final record in sortedRecords) {
      final recordDate = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );

      if (lastDate == null) {
        lastDate = recordDate;
        streak = 1;
      } else {
        final daysDiff = lastDate.difference(recordDate).inDays;
        if (daysDiff == 1) {
          streak++;
          lastDate = recordDate;
        } else if (daysDiff > 1) {
          break;
        }
      }
    }

    return streak;
  }

  static String _calculateMoodTrend(List<MoodRecord> records) {
    final now = DateTime.now();
    final lastWeekStart = now.subtract(const Duration(days: 7));
    final previousWeekStart = now.subtract(const Duration(days: 14));

    final lastWeekRecords =
        records.where((r) => r.timestamp.isAfter(lastWeekStart)).toList();
    final previousWeekRecords =
        records
            .where(
              (r) =>
                  r.timestamp.isAfter(previousWeekStart) &&
                  r.timestamp.isBefore(lastWeekStart),
            )
            .toList();

    if (lastWeekRecords.isEmpty || previousWeekRecords.isEmpty) {
      return 'Insufficient data';
    }

    final lastWeekPositive =
        lastWeekRecords.where((r) => r.mood.toLowerCase() == 'happy').length;
    final previousWeekPositive =
        previousWeekRecords
            .where((r) => r.mood.toLowerCase() == 'happy')
            .length;

    final lastWeekRatio = lastWeekPositive / lastWeekRecords.length;
    final previousWeekRatio = previousWeekPositive / previousWeekRecords.length;

    if (lastWeekRatio > previousWeekRatio + 0.1) {
      return 'Improving';
    } else if (lastWeekRatio < previousWeekRatio - 0.1) {
      return 'Declining';
    } else {
      return 'Stable';
    }
  }

  static List<String> _generateRecommendations(
    List<MoodRecord> records,
    String mostFrequentMood,
    String trend,
  ) {
    List<String> recommendations = [];

    // Based on most frequent mood
    switch (mostFrequentMood.toLowerCase()) {
      case 'happy':
        recommendations.add(
          'Great job maintaining positive vibes! Keep doing what makes you happy.',
        );
        break;
      case 'sad':
        recommendations.add(
          'Consider engaging in activities that boost your mood, like exercise or socializing.',
        );
        break;
      case 'angry':
        recommendations.add(
          'Try stress-reduction techniques like deep breathing or meditation.',
        );
        break;
      case 'sleepy':
        recommendations.add(
          'Focus on improving your sleep schedule and energy levels.',
        );
        break;
      case 'neutral':
        recommendations.add(
          'Explore new activities to add more excitement to your routine.',
        );
        break;
    }

    // Based on trend
    switch (trend) {
      case 'Improving':
        recommendations.add(
          'Your mood is trending upward! Continue your current positive habits.',
        );
        break;
      case 'Declining':
        recommendations.add(
          'Consider reaching out to friends or trying new mood-boosting activities.',
        );
        break;
      case 'Stable':
        recommendations.add(
          'Your mood is consistent. Consider setting small goals for positive changes.',
        );
        break;
    }

    // Based on frequency
    if (records.length < 7) {
      recommendations.add(
        'Track your mood more regularly for better insights and patterns.',
      );
    }

    // Time-based recommendations
    final hourCounts = <int, int>{};
    for (var record in records) {
      final hour = record.timestamp.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    if (hourCounts.isNotEmpty) {
      final mostActiveHour =
          hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      if (mostActiveHour < 12) {
        recommendations.add(
          'You seem most active in the morning. Great for setting a positive tone for the day!',
        );
      } else if (mostActiveHour > 18) {
        recommendations.add(
          'Evening reflection is great for processing your day. Consider morning check-ins too.',
        );
      }
    }

    return recommendations.take(3).toList(); // Limit to 3 recommendations
  }
}

// Data models for analytics
class DailyMoodData {
  final DateTime date;
  final String mood;
  final int count;

  DailyMoodData({required this.date, required this.mood, required this.count});
}

class WeeklyMoodData {
  final DateTime weekStart;
  final DateTime weekEnd;
  final Map<String, int> moodDistribution;
  final int totalCount;

  WeeklyMoodData({
    required this.weekStart,
    required this.weekEnd,
    required this.moodDistribution,
    required this.totalCount,
  });
}

class MonthlyMoodData {
  final DateTime month;
  final Map<String, int> moodDistribution;
  final int totalCount;

  MonthlyMoodData({
    required this.month,
    required this.moodDistribution,
    required this.totalCount,
  });
}

class MoodInsights {
  final String mostFrequentMood;
  final int moodStreak;
  final double averageDailyEntries;
  final String moodTrend;
  final List<String> recommendations;

  MoodInsights({
    required this.mostFrequentMood,
    required this.moodStreak,
    required this.averageDailyEntries,
    required this.moodTrend,
    required this.recommendations,
  });
}
