/// Preferences collected during FocusBank onboarding.
/// Stored under users/{uid}.studyPreferences in Cloud Firestore.
class StudyPreferences {
  final List<String> availableDays;
  final String preferredPeriod;
  final String wakeUpTime;
  final String sleepTime;
  final int dailyStudyHours;
  final int sessionMinutes;
  final int breakMinutes;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> exams;
  final List<String> learningMethods;
  final String mainGoal;

  const StudyPreferences({
    required this.availableDays,
    required this.preferredPeriod,
    required this.wakeUpTime,
    required this.sleepTime,
    required this.dailyStudyHours,
    required this.sessionMinutes,
    required this.breakMinutes,
    required this.subjects,
    required this.exams,
    required this.learningMethods,
    required this.mainGoal,
  });

  Map<String, dynamic> toJson() => {
        'availableDays': availableDays,
        'preferredPeriod': preferredPeriod,
        'wakeUpTime': wakeUpTime,
        'sleepTime': sleepTime,
        'dailyStudyHours': dailyStudyHours,
        'sessionMinutes': sessionMinutes,
        'breakMinutes': breakMinutes,
        'subjects': subjects,
        'exams': exams,
        'learningMethods': learningMethods,
        'mainGoal': mainGoal,
        'updatedAt': DateTime.now().toIso8601String(),
      };
}
