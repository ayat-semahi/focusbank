class UserProfile {
  final String name;
  final String email;
  final String dreamCareer;
  final double dreamIncome;
  final String academicGoal;
  final int dailyGoalMinutes;
  final String preferredTime; // Morning, Afternoon, Evening, Night
  final List<String> subjects;

  UserProfile({
    required this.name,
    this.email = '',
    required this.dreamCareer,
    this.dreamIncome = 0,
    required this.academicGoal,
    required this.dailyGoalMinutes,
    required this.preferredTime,
    required this.subjects,
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? dreamCareer,
    double? dreamIncome,
    String? academicGoal,
    int? dailyGoalMinutes,
    String? preferredTime,
    List<String>? subjects,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      dreamCareer: dreamCareer ?? this.dreamCareer,
      dreamIncome: dreamIncome ?? this.dreamIncome,
      academicGoal: academicGoal ?? this.academicGoal,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      preferredTime: preferredTime ?? this.preferredTime,
      subjects: subjects ?? this.subjects,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'dreamCareer': dreamCareer,
    'dreamIncome': dreamIncome,
    'academicGoal': academicGoal,
    'dailyGoalMinutes': dailyGoalMinutes,
    'preferredTime': preferredTime,
    'subjects': subjects,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? 'User',
    email: json['email'] as String? ?? '',
    dreamCareer: (json['dreamCareer'] as String?) ?? (json['dreamJob'] as String?) ?? 'Student',
    dreamIncome: (json['dreamIncome'] as num?)?.toDouble() ?? 0,
    academicGoal: json['academicGoal'] as String? ?? 'Master Focus Habits',
    dailyGoalMinutes: (json['dailyGoalMinutes'] as num?)?.toInt() ?? 120,
    preferredTime: json['preferredTime'] as String? ?? 'Evening',
    subjects: (json['subjects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [
      'Mobile App Dev',
      'Algorithms',
      'Mathematics',
      'System Design',
    ],
  );

  static UserProfile defaultProfile() => UserProfile(
    name: 'Ralph Edwards',
    email: 'ralph.edwards@focusbank.app',
    dreamCareer: 'Senior Eng',
    dreamIncome: 3000,
    academicGoal: 'Pass exams with top honors',
    dailyGoalMinutes: 120,
    preferredTime: 'Evening',
    subjects: ['Mobile App Dev', 'Algorithms', 'Mathematics', 'System Design'],
  );
}
