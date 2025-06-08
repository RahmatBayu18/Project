import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/mood_record.dart';
import '../config/api_config.dart';

class AITipsService {
  static const String _apiKey = ApiConfig.geminiApiKey;

  late final GenerativeModel _model;

  AITipsService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 20,
        topP: 0.8,
        maxOutputTokens: 300,
      ),
    );
  }

  Future<String> generatePersonalizedTip(List<MoodRecord> recentMoods) async {
    try {
      // Ambil 10 record terakhir
      final last10Moods = recentMoods.take(10).toList();

      if (last10Moods.isEmpty) {
        return _getDefaultTip();
      }

      final prompt = _buildPrompt(last10Moods);

      final response = await _model.generateContent([Content.text(prompt)]);

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.trim();
      } else {
        return _getDefaultTip();
      }
    } catch (e) {
      print('Error generating AI tip: $e');
      return _getDefaultTip();
    }
  }

  String _buildPrompt(List<MoodRecord> moods) {
    final moodAnalysis = _analyzeMoodPattern(moods);

    return '''
Anda adalah seorang psikolog yang berpengalaman dalam memberikan saran kesehatan mental. 
Berdasarkan data tracking mood berikut dari 10 hari terakhir, berikan 1 tips praktis dan personal dalam bahasa Indonesia gaul.

Data mood (dari terbaru ke terlama):
${_formatMoodData(moods)}

Analisis pola:
- Mood yang sering muncul: ${moodAnalysis['frequent']}
- Trend mood: ${moodAnalysis['trend']}
- Variabilitas: ${moodAnalysis['variability']}

Berikan tips yang:
1. Spesifik untuk pola mood ini
2. Praktis dan mudah diterapkan
3. Positif dan memotivasi
4. Maksimal 2-3 kalimat
5. Fokus pada actionable advice

Format: Berikan hanya tips-nya saja tanpa penjelasan tambahan.
''';
  }

  String _formatMoodData(List<MoodRecord> moods) {
    return moods
        .map((mood) {
          final date = '${mood.timestamp.day}/${mood.timestamp.month}';
          return '- $date: ${mood.mood} (musik: ${mood.music})${mood.note.isNotEmpty ? ' - catatan: ${mood.note}' : ''}';
        })
        .join('\n');
  }

  Map<String, String> _analyzeMoodPattern(List<MoodRecord> moods) {
    // Hitung frekuensi mood
    final moodCounts = <String, int>{};
    for (final mood in moods) {
      moodCounts[mood.mood] = (moodCounts[mood.mood] ?? 0) + 1;
    }

    final sortedMoods =
        moodCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final frequentMood =
        sortedMoods.isNotEmpty ? sortedMoods.first.key : 'Tidak ada data';

    // Analisis trend (sederhana)
    String trend = 'Stabil';
    if (moods.length >= 3) {
      final recent3 = moods.take(3).toList();
      final older3 = moods.skip(3).take(3).toList();

      final recentPositive =
          recent3.where((m) => _isPositiveMood(m.mood)).length;
      final olderPositive = older3.where((m) => _isPositiveMood(m.mood)).length;

      if (recentPositive > olderPositive) {
        trend = 'Membaik';
      } else if (recentPositive < olderPositive) {
        trend = 'Menurun';
      }
    }

    // Variabilitas
    final uniqueMoods = moodCounts.keys.length;
    String variability = 'Rendah';
    if (uniqueMoods > 3) {
      variability = 'Tinggi';
    } else if (uniqueMoods > 1) {
      variability = 'Sedang';
    }

    return {
      'frequent': frequentMood,
      'trend': trend,
      'variability': variability,
    };
  }

  bool _isPositiveMood(String mood) {
    final positiveMoods = [
      'happy',
      'excited',
      'calm',
      'confident',
      'joyful',
      'content',
      'grateful',
    ];
    return positiveMoods.any(
      (positive) => mood.toLowerCase().contains(positive),
    );
  }

  String _getDefaultTip() {
    final defaultTips = [
      'Luangkan waktu 5 menit hari ini untuk bernapas dalam-dalam dan fokus pada hal-hal positif di sekitar Anda.',
      'Cobalah menulis 3 hal yang Anda syukuri hari ini, sekecil apapun itu.',
      'Dengarkan musik favorit Anda dan biarkan diri Anda merasakan emosi yang muncul.',
      'Lakukan aktivitas fisik ringan seperti jalan kaki untuk meningkatkan mood Anda.',
      'Hubungi teman atau keluarga yang membuat Anda merasa nyaman dan terhubung.',
    ];
    return defaultTips[DateTime.now().millisecond % defaultTips.length];
  }
}

// Model untuk menyimpan AI tip
class AITip {
  final String content;
  final DateTime generatedAt;
  final String category;

  AITip({
    required this.content,
    required this.generatedAt,
    this.category = 'personalized',
  });

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'generatedAt': generatedAt.toIso8601String(),
      'category': category,
    };
  }

  factory AITip.fromMap(Map<String, dynamic> map) {
    return AITip(
      content: map['content'] as String,
      generatedAt: DateTime.parse(map['generatedAt'] as String),
      category: map['category'] as String? ?? 'personalized',
    );
  }
}
