import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mood_record.dart';

class MoodService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid;

  MoodService(this.uid);

  Stream<List<MoodRecord>> streamMoodHistory() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('mood_records')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => MoodRecord.fromMap(doc.data())).toList(),
        );
  }

  Future<void> addMood(MoodRecord record) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('mood_records')
        .add(record.toMap());
  }
}
