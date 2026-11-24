
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/study_preferences.dart';

class StudyPreferencesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save study preferences
  Future<void> save(String uid, StudyPreferences preferences) async {
    await _db.collection('users').doc(uid).set({
      'studyPreferences': preferences.toJson(),
      'studyPreferencesCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Retrieve saved study preferences
  Future<Map<String, dynamic>?> get(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    final preferences = data['studyPreferences'];

    if (preferences is Map) {
      return Map<String, dynamic>.from(preferences);
    }

    return null;
  }
}
