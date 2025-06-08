import 'package:intl/intl.dart';

class MoodRecord {
  final String mood;
  final String music;
  final DateTime timestamp;
  final String note;

  MoodRecord({
    required this.mood,
    required this.music,
    required this.timestamp,
    this.note = "",
  });

  Map<String, dynamic> toMap() {
    return {
      'mood': mood,
      'music': music,
      'timestamp': timestamp.toIso8601String(),
      'note': note, // Tambahkan note
    };
  }

  factory MoodRecord.fromMap(Map<String, dynamic> map) {
    return MoodRecord(
      mood: map['mood'] as String,
      music: map['music'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      note: map['note'] as String? ?? '',
    );
  }

  String get dayOfWeek {
    return DateFormat('E').format(timestamp);
  }

  String get weekNumber {
    return 'Week ${timestamp.weekOfYear}';
  }
}

extension DateExtension on DateTime {
  int get weekOfYear {
    final date = DateTime(year, month, day);
    final firstDay = DateTime(year, 1, 1);
    final weekNumber = ((date.difference(firstDay).inDays / 7).floor() + 1);
    return weekNumber;
  }
}
