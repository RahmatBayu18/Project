class MoodRecord {
  final String mood;
  final String music;
  final DateTime timestamp;

  MoodRecord({
    required this.mood,
    required this.music,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'mood': mood,
      'music': music,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MoodRecord.fromMap(Map<String, dynamic> map) {
    return MoodRecord(
      mood: map['mood'] as String,
      music: map['music'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
