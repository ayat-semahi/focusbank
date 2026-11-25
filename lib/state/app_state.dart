import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/transaction.dart';
import '../models/study_plan_item.dart';
import '../models/reward_item.dart';
import '../services/database_service.dart';
import '../services/study_preferences_service.dart';
import '../services/gemini_service.dart';

class SubjectFocusStat {
  final String name;
  final int minutes;
  final int colorValue;

  const SubjectFocusStat({
    required this.name,
    required this.minutes,
    required this.colorValue,
  });

  Color get color => Color(colorValue);
}

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  factory AppState() => instance;
  AppState._internal() {
    _initDefaults();
    _checkCurrentUser();
  }

  bool _isLoggedIn = true;
  bool _isOnboarded = true;
  UserProfile? _profile;
  bool _isGeneratingAIPlan = false;

  int? _balance = 0;
  int? _totalEarned = 0;
  int? _sessionCount = 0;
  int? _totalMinutesFocused = 0;
  int? _streakDays = 1;
  String? _lastActiveDate = '';
  DateTime? _accountCreatedAt;
  bool _notificationsEnabled = true;
  bool _doNotDisturbEnabled = false;
  int _defaultTimerMinutes = 45;

  // Safe fallback storage for Web Hot-Reload safety
  static final Map<String, int> _fallbackDailyMinutes = <String, int>{};
  static final Map<String, Map<String, dynamic>> _fallbackSubjectStats =
      <String, Map<String, dynamic>>{};
  static final Map<String, Map<String, Map<String, dynamic>>>
      _fallbackDailySubjectStats =
      <String, Map<String, Map<String, dynamic>>>{};
  static final List<BankTransaction> _fallbackTransactions = <BankTransaction>[];
  static final List<StudyPlanItem> _fallbackStudyPlan = <StudyPlanItem>[];
  static final List<RewardItem> _fallbackRewards = <RewardItem>[];

  // Map of 'YYYY-MM-DD' -> minutes focused on that day
  Map<String, int>? _dailyFocusMinutes;
  Map<String, int> get _safeDailyFocusMinutes {
    _dailyFocusMinutes ??= _fallbackDailyMinutes;
    return _dailyFocusMinutes!;
  }

  // Map of lowercase subject key -> { 'name': String, 'minutes': int, 'colorValue': int }
  Map<String, Map<String, dynamic>>? _subjectFocusStats;
  Map<String, Map<String, dynamic>> get _safeSubjectStats {
    _subjectFocusStats ??= _fallbackSubjectStats;
    return _subjectFocusStats!;
  }

  // Map of 'YYYY-MM-DD' -> { subjectKey -> { 'name', 'minutes', 'colorValue' } }
  Map<String, Map<String, Map<String, dynamic>>>? _dailySubjectStats;
  Map<String, Map<String, Map<String, dynamic>>> get _safeDailySubjectStats {
    _dailySubjectStats ??= _fallbackDailySubjectStats;
    return _dailySubjectStats!;
  }

  List<BankTransaction>? _transactions;
  List<BankTransaction> get _safeTransactions {
    _transactions ??= _fallbackTransactions;
    return _transactions!;
  }

  List<StudyPlanItem>? _studyPlan;
  List<StudyPlanItem> get _safeStudyPlan {
    _studyPlan ??= _fallbackStudyPlan;
    return _studyPlan!;
  }

  List<RewardItem>? _rewards;
  List<RewardItem> get _safeRewards {
    _rewards ??= _fallbackRewards;
    return _rewards!;
  }

  bool _isLoading = false;

  // Getters with null-safety fallbacks for Web Hot-Reload
  bool get isLoggedIn => _isLoggedIn;
  bool get isOnboarded => _isOnboarded;
  UserProfile get profile => _profile ??= UserProfile.defaultProfile();
  int get balance => _balance ?? 0;
  int get totalEarned => _totalEarned ?? 0;
  int get sessionCount => _sessionCount ?? 0;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get doNotDisturbEnabled => _doNotDisturbEnabled;
  int get defaultTimerMinutes => _defaultTimerMinutes;
  int get streakDays => _streakDays ?? 1;
  int get totalMinutesFocused => _totalMinutesFocused ?? 0;
  double get totalHoursFocused => (_totalMinutesFocused ?? 0) / 60.0;
  String get lastActiveDate => _lastActiveDate ?? '';
  DateTime get accountCreatedAt {
    final dt = _accountCreatedAt ??
        FirebaseAuth.instance.currentUser?.metadata.creationTime ??
        DateTime.now();
    return DateTime(dt.year, dt.month, dt.day);
  }
  Map<String, int> get dailyFocusMinutes => Map.unmodifiable(_safeDailyFocusMinutes);
  List<SubjectFocusStat> get subjectFocusStats {
    final list = _safeSubjectStats.values
        .map((entry) => SubjectFocusStat(
              name: (entry['name'] as String?) ?? 'Deep Focus',
              minutes: (entry['minutes'] as num?)?.toInt() ?? 0,
              colorValue: (entry['colorValue'] as num?)?.toInt() ?? 0xFF00E5FF,
            ))
        .where((stat) => stat.minutes > 0)
        .toList();
    list.sort((a, b) => b.minutes.compareTo(a.minutes));
    return List.unmodifiable(list);
  }
  List<BankTransaction> get transactions => List.unmodifiable(_safeTransactions);
  List<StudyPlanItem> get studyPlan => List.unmodifiable(_safeStudyPlan);
  List<RewardItem> get rewards => List.unmodifiable(_safeRewards);
  bool get isLoading => _isLoading;

  Future<void> _saveStudyPlanToFirestore(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'studyPlan': _safeStudyPlan.map((item) => item.toJson()).toList(),
    }, SetOptions(merge: true));
  }

  Future<bool> _loadStudyPlanFromFirestore(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final data = doc.data();
    final rawPlan = data?['studyPlan'];

    if (rawPlan is! List || rawPlan.isEmpty) {
      return false;
    }

    _studyPlan = rawPlan
        .whereType<Map>()
        .map(
          (item) => StudyPlanItem.fromJson(
        Map<String, dynamic>.from(item),
      ),
    )
        .toList();

    return _safeStudyPlan.isNotEmpty;
  }


Future<void> generateAIStudyPlan() async {
  // Prevent multiple simultaneous Gemini requests.
  if (_isGeneratingAIPlan) {
    debugPrint(
      'AI plan generation already in progress. Skipping duplicate request.',
    );
    return;
  }

  _isGeneratingAIPlan = true;

  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    _isGeneratingAIPlan = false;
    throw Exception('You must be logged in to generate a study plan.');
  }

  _isLoading = true;
  notifyListeners();

  try {
    final preferences =
        await StudyPreferencesService().get(user.uid);

    if (preferences == null) {
      throw Exception(
        'No study preferences found. Complete the study profile first.',
      );
    }

    final generatedPlan =
        await GeminiService().generateWeeklyPlan(
      preferences: preferences,
    );

    _studyPlan = generatedPlan;

    await _saveStudyPlanToFirestore(user.uid);
  } catch (e) {
    debugPrint('AI study plan generation error: $e');
    rethrow;
  } finally {
    _isLoading = false;
    _isGeneratingAIPlan = false;
    notifyListeners();
  }
}


  /// Helper to format DateTime to 'YYYY-MM-DD'
  static String formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Returns the focus minutes recorded for a specific date
  int getMinutesForDate(DateTime date) {
    final key = formatDateKey(date);
    return _safeDailyFocusMinutes[key] ?? 0;
  }

  /// Calculates total focus minutes for any 7-day week starting on [monday]
  int getWeekMinutesFocused(DateTime monday) {
    int total = 0;
    for (int i = 0; i < 7; i++) {
      total += getMinutesForDate(monday.add(Duration(days: i)));
    }
    return total;
  }

  /// Returns the highest focus minutes on any single day in the week starting on [monday]
  int getMaxMinutesInWeek(DateTime monday) {
    int maxM = 0;
    for (int i = 0; i < 7; i++) {
      final m = getMinutesForDate(monday.add(Duration(days: i)));
      if (m > maxM) maxM = m;
    }
    return maxM;
  }

  /// Returns sorted session breakdown stats for a specific [date]
  List<SubjectFocusStat> getSubjectStatsForDate(DateTime date) {
    final dayMap = _safeDailySubjectStats[formatDateKey(date)];
    if (dayMap == null || dayMap.isEmpty) return const [];
    final list = dayMap.values
        .map((entry) => SubjectFocusStat(
              name: (entry['name'] as String?) ?? 'Deep Focus',
              minutes: (entry['minutes'] as num?)?.toInt() ?? 0,
              colorValue: (entry['colorValue'] as num?)?.toInt() ?? 0xFF00E5FF,
            ))
        .where((s) => s.minutes > 0)
        .toList();
    list.sort((a, b) => b.minutes.compareTo(a.minutes));
    return List.unmodifiable(list);
  }

  /// Aggregates sorted session breakdown stats across all 7 days starting on [monday]
  List<SubjectFocusStat> getSubjectStatsForWeek(DateTime monday) {
    final combined = <String, Map<String, dynamic>>{};
    for (int i = 0; i < 7; i++) {
      final key = formatDateKey(monday.add(Duration(days: i)));
      final dayMap = _safeDailySubjectStats[key];
      if (dayMap == null) continue;
      dayMap.forEach((subjectKey, entry) {
        final mins = (entry['minutes'] as num?)?.toInt() ?? 0;
        if (mins <= 0) return;
        final existing = combined[subjectKey];
        if (existing != null) {
          existing['minutes'] = ((existing['minutes'] as int?) ?? 0) + mins;
        } else {
          combined[subjectKey] = {
            'name': (entry['name'] as String?) ?? 'Deep Focus',
            'minutes': mins,
            'colorValue': (entry['colorValue'] as num?)?.toInt() ?? 0xFF00E5FF,
          };
        }
      });
    }
    final list = combined.values
        .map((entry) => SubjectFocusStat(
              name: entry['name'] as String,
              minutes: entry['minutes'] as int,
              colorValue: entry['colorValue'] as int,
            ))
        .toList();
    list.sort((a, b) => b.minutes.compareTo(a.minutes));
    return List.unmodifiable(list);
  }

  /// Calculates the total focus minutes recorded for the current week (Monday through Sunday)
  int get currentWeekMinutesFocused {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    int total = 0;
    for (int i = 0; i < 7; i++) {
      final dayDate = monday.add(Duration(days: i));
      total += getMinutesForDate(dayDate);
    }
    return total;
  }

  /// Returns the highest focus minutes recorded on any single day of the current week
  int get maxMinutesInCurrentWeek {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    int maxM = 0;
    for (int i = 0; i < 7; i++) {
      final dayDate = monday.add(Duration(days: i));
      final m = getMinutesForDate(dayDate);
      if (m > maxM) maxM = m;
    }
    return maxM;
  }

  void _checkCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      loadUserDataFromFirestore(user.uid);
    }
  }

  static List<RewardItem> _defaultRewards() => [
    RewardItem(
      id: 'r_1',
      title: '30m Gaming Break',
      description: 'Play on PC / Console guilt-free',
      costCoins: 35,
      iconEmoji: '🎮',
      category: 'Entertainment',
    ),
    RewardItem(
      id: 'r_2',
      title: '1 Episode of Netflix/Anime',
      description: 'Watch your favorite series',
      costCoins: 45,
      iconEmoji: '🍿',
      category: 'Entertainment',
    ),
    RewardItem(
      id: 'r_3',
      title: 'Specialty Coffee / Boba',
      description: 'Treat yourself to your favorite drink',
      costCoins: 60,
      iconEmoji: '☕',
      category: 'Treat',
    ),
    RewardItem(
      id: 'r_4',
      title: '20m Social Media Break',
      description: 'Scroll guilt-free',
      costCoins: 25,
      iconEmoji: '📱',
      category: 'Break',
    ),
    RewardItem(
      id: 'r_5',
      title: 'Weekend Celebration',
      description: 'Full evening off with friends',
      costCoins: 150,
      iconEmoji: '🎉',
      category: 'Treat',
    ),
  ];

  void _initDefaults() {
    _rewards = _defaultRewards();

    _generateStudyPlanFor(profile);
  }

  void _generateStudyPlanFor(UserProfile user) {
    final timePrefix = user.preferredTime == 'Morning'
        ? '08:30 - 10:00'
        : user.preferredTime == 'Afternoon'
            ? '14:00 - 15:30'
            : user.preferredTime == 'Night'
                ? '22:00 - 23:30'
                : '19:00 - 20:30';

    _studyPlan = [
      StudyPlanItem(
        id: 'sp_1',
        day: 'Monday',
        timeSlot: timePrefix,
        subject: user.subjects.isNotEmpty ? user.subjects[0] : 'Mobile App Dev',
        objective: 'Timer & State Architecture setup',
        durationMinutes: 60,
        isCompleted: true,
      ),
      StudyPlanItem(
        id: 'sp_2',
        day: 'Tuesday',
        timeSlot: timePrefix,
        subject: user.subjects.length > 1 ? user.subjects[1] : 'Algorithms',
        objective: 'Data structures & problem solving',
        durationMinutes: 60,
        isCompleted: true,
      ),
      StudyPlanItem(
        id: 'sp_3',
        day: 'Wednesday',
        timeSlot: timePrefix,
        subject: user.subjects.length > 2 ? user.subjects[2] : 'Mathematics',
        objective: 'Calculus & applied problem sets',
        durationMinutes: 90,
        isCompleted: false,
      ),
      StudyPlanItem(
        id: 'sp_4',
        day: 'Thursday',
        timeSlot: timePrefix,
        subject: user.subjects.isNotEmpty ? user.subjects[0] : 'Mobile App Dev',
        objective: 'UI polish & micro-interactions',
        durationMinutes: 60,
        isCompleted: false,
      ),
      StudyPlanItem(
        id: 'sp_5',
        day: 'Friday',
        timeSlot: timePrefix,
        subject: user.subjects.length > 3 ? user.subjects[3] : 'System Design',
        objective: 'Mock exam & synthesis',
        durationMinutes: 60,
        isCompleted: false,
      ),
      StudyPlanItem(
        id: 'sp_6',
        day: 'Saturday',
        timeSlot: '10:00 - 12:00',
        subject: 'Weekly Review',
        objective: 'Comprehensive test & AI study analysis',
        durationMinutes: 120,
        isCompleted: false,
      ),
    ];
  }

  /// Loads user profile, stats, transactions and weekly focus minutes from Firestore
  Future<void> loadUserDataFromFirestore(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final docData = await DatabaseService.instance.getUserData(uid);
      if (docData != null) {
        _profile = UserProfile.fromJson(docData);
        _balance = (docData['balance'] as num?)?.toInt() ?? 0;
        _totalEarned = (docData['totalEarned'] as num?)?.toInt();
        _sessionCount = (docData['sessionCount'] as num?)?.toInt() ?? 0;
        _totalMinutesFocused = (docData['totalMinutesFocused'] as num?)?.toInt() ?? 0;
        _streakDays = (docData['streakDays'] as num?)?.toInt() ?? 1;
        _lastActiveDate = docData['lastActiveDate'] as String? ?? '';
        _notificationsEnabled = docData['notificationsEnabled'] as bool? ?? true;
        _doNotDisturbEnabled = docData['doNotDisturbEnabled'] as bool? ?? false;

        final rawPrefs = docData['studyPreferences'];
        final prefSessionMins = rawPrefs is Map
            ? (rawPrefs['sessionMinutes'] as num?)?.toInt()
            : null;
        _defaultTimerMinutes =
            (docData['defaultTimerMinutes'] as num?)?.toInt() ??
                prefSessionMins ??
                45;

        final rawRewards = docData['rewards'];
        if (rawRewards is List && rawRewards.isNotEmpty) {
          final parsedRewards = rawRewards
              .whereType<Map>()
              .map((m) => RewardItem.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          _rewards = parsedRewards.isNotEmpty ? parsedRewards : _defaultRewards();
        } else {
          _rewards = _defaultRewards();
        }

        final rawCreatedAt = docData['createdAt'];
        if (rawCreatedAt is Timestamp) {
          _accountCreatedAt = rawCreatedAt.toDate();
        } else if (rawCreatedAt is String) {
          _accountCreatedAt = DateTime.tryParse(rawCreatedAt);
        }
        _accountCreatedAt ??=
            FirebaseAuth.instance.currentUser?.metadata.creationTime;

        if (docData['dailyFocusMinutes'] is Map) {
          final rawMap = docData['dailyFocusMinutes'] as Map;
          _dailyFocusMinutes = rawMap.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          );
        }

        if (docData['subjectFocusStats'] is Map) {
          final rawSubjects = docData['subjectFocusStats'] as Map;
          final parsed = <String, Map<String, dynamic>>{};
          rawSubjects.forEach((k, v) {
            if (v is Map) {
              parsed[k.toString()] = {
                'name': (v['name'] as String?) ?? k.toString(),
                'minutes': (v['minutes'] as num?)?.toInt() ?? 0,
                'colorValue': (v['colorValue'] as num?)?.toInt() ?? 0xFF00E5FF,
              };
            }
          });
          _subjectFocusStats = parsed;
        }

        if (docData['dailySubjectStats'] is Map) {
          final rawDailySubjects = docData['dailySubjectStats'] as Map;
          final parsedDaily = <String, Map<String, Map<String, dynamic>>>{};
          rawDailySubjects.forEach((dateKey, subjectsVal) {
            if (subjectsVal is Map) {
              final daySubjects = <String, Map<String, dynamic>>{};
              subjectsVal.forEach((subjKey, entry) {
                if (entry is Map) {
                  daySubjects[subjKey.toString()] = {
                    'name': (entry['name'] as String?) ?? subjKey.toString(),
                    'minutes': (entry['minutes'] as num?)?.toInt() ?? 0,
                    'colorValue':
                        (entry['colorValue'] as num?)?.toInt() ?? 0xFF00E5FF,
                  };
                }
              });
              parsedDaily[dateKey.toString()] = daySubjects;
            }
          });
          _dailySubjectStats = parsedDaily;
        }

        if (docData['recentTransactions'] is List) {
          final rawTxs = docData['recentTransactions'] as List;
          _transactions = rawTxs
              .whereType<Map>()
              .map((m) => BankTransaction.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }

        final hasSavedPlan = await _loadStudyPlanFromFirestore(uid);

        if (!hasSavedPlan) {
          _generateStudyPlanFor(profile);
        }
      }

      // If recentTransactions wasn't stored in the user doc, fallback to subcollection
      if (_safeTransactions.isEmpty) {
        final txList = await DatabaseService.instance.getTransactions(uid);
        if (txList.isNotEmpty) {
          _transactions = txList;
        }
      }

      // If dailyFocusMinutes was empty, recover from past transactions
      if (_safeDailyFocusMinutes.isEmpty && _safeTransactions.isNotEmpty) {
        for (final tx in _safeTransactions) {
          if (tx.type == TransactionType.deposit) {
            final key = formatDateKey(tx.date);
            _safeDailyFocusMinutes[key] =
                (_safeDailyFocusMinutes[key] ?? 0) + tx.coins;
          }
        }
      }

      // Recover totalEarned for older accounts that don't have it stored yet
      if (_totalEarned == null) {
        int depositSum = 0;
        for (final tx in _safeTransactions) {
          if (tx.type == TransactionType.deposit) {
            depositSum += tx.coins;
          }
        }
        final currentBal = _balance ?? 0;
        _totalEarned = depositSum > currentBal ? depositSum : currentBal;
      }

      _isLoggedIn = true;
      _isOnboarded = true;
    } catch (e) {
      debugPrint('AppState.loadUserDataFromFirestore error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Authentication Flow
  void login({required String email, required String password}) {
    _isLoggedIn = true;
    _isOnboarded = true;
    notifyListeners();
  }

  void signUp({
    required String name,
    required String email,
    required String password,
  }) {
    _profile = UserProfile(
      name: name.trim().isEmpty ? 'User' : name.trim(),
      email: email.trim(),
      dreamCareer: 'Student',
      academicGoal: 'Ace exams with top grades',
      dailyGoalMinutes: 90,
      preferredTime: 'Evening',
      subjects: ['Mobile App Dev', 'Algorithms', 'Mathematics', 'System Design'],
    );
    _isLoggedIn = true;
    _isOnboarded = false;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _balance = 0;
    _totalEarned = 0;
    _sessionCount = 0;
    _totalMinutesFocused = 0;
    _streakDays = 1;
    _lastActiveDate = '';
    _accountCreatedAt = null;
    _notificationsEnabled = true;
    _doNotDisturbEnabled = false;
    _defaultTimerMinutes = 45;
    _dailyFocusMinutes = {};
    _subjectFocusStats = {};
    _dailySubjectStats = {};
    _fallbackDailyMinutes.clear();
    _fallbackSubjectStats.clear();
    _fallbackDailySubjectStats.clear();
    _transactions = [];
    _fallbackTransactions.clear();
    _fallbackRewards.clear();
    _rewards = _defaultRewards();
    _profile = UserProfile.defaultProfile();
    notifyListeners();
  }

  // Completing the questionnaire form
  void completeOnboarding(UserProfile newProfile) {
    _profile = newProfile;
    _isOnboarded = true;
    _generateStudyPlanFor(newProfile);
    notifyListeners();
  }

  // Recording a focus session
  void recordFocusSession({
    required String subject,
    required int minutesCompleted,
    int tagColorValue = 0xFF00E5FF,
  }) {
    if (minutesCompleted <= 0) return;

    final bonus = (minutesCompleted ~/ 30) * 5;
    final totalCoins = minutesCompleted + bonus;

    _balance = balance + totalCoins;
    _totalEarned = totalEarned + totalCoins;
    _totalMinutesFocused = totalMinutesFocused + minutesCompleted;
    _sessionCount = sessionCount + 1;

    final now = DateTime.now();
    final todayKey = formatDateKey(now);
    _safeDailyFocusMinutes[todayKey] =
        (_safeDailyFocusMinutes[todayKey] ?? 0) + minutesCompleted;

    // Track per-subject minutes & tag color (all-time + per-day) for the dashboard pie chart
    // Preserve the original color if this subject already exists (1-to-1 title <-> color rule)
    final cleanSubject = subject.trim().isEmpty ? 'Deep Focus' : subject.trim();
    final subjectKey = cleanSubject.toLowerCase();
    final existing = _safeSubjectStats[subjectKey];
    final int lockedColorValue = existing != null
        ? ((existing['colorValue'] as num?)?.toInt() ?? tagColorValue)
        : tagColorValue;

    if (existing != null) {
      final prevMinutes = (existing['minutes'] as num?)?.toInt() ?? 0;
      _safeSubjectStats[subjectKey] = {
        'name': (existing['name'] as String?) ?? cleanSubject,
        'minutes': prevMinutes + minutesCompleted,
        'colorValue': lockedColorValue,
      };
    } else {
      _safeSubjectStats[subjectKey] = {
        'name': cleanSubject,
        'minutes': minutesCompleted,
        'colorValue': lockedColorValue,
      };
    }

    final daySubjects =
        _safeDailySubjectStats.putIfAbsent(todayKey, () => <String, Map<String, dynamic>>{});
    final existingDay = daySubjects[subjectKey];
    if (existingDay != null) {
      final prevDayMins = (existingDay['minutes'] as num?)?.toInt() ?? 0;
      daySubjects[subjectKey] = {
        'name': (existingDay['name'] as String?) ?? cleanSubject,
        'minutes': prevDayMins + minutesCompleted,
        'colorValue': lockedColorValue,
      };
    } else {
      daySubjects[subjectKey] = {
        'name': cleanSubject,
        'minutes': minutesCompleted,
        'colorValue': lockedColorValue,
      };
    }

    // Streak logic
    final yesterdayKey = formatDateKey(now.subtract(const Duration(days: 1)));
    final currentLastActive = lastActiveDate;
    if (currentLastActive == yesterdayKey) {
      _streakDays = streakDays + 1;
    } else if (currentLastActive != todayKey && currentLastActive.isNotEmpty) {
      _streakDays = 1;
    } else if (streakDays == 0) {
      _streakDays = 1;
    }
    _lastActiveDate = todayKey;

    final tx = BankTransaction(
      id: 'tx_${now.millisecondsSinceEpoch}',
      title: 'Focus: $cleanSubject',
      description: 'Completed $minutesCompleted min focus session',
      coins: totalCoins,
      type: TransactionType.deposit,
      date: now,
      category: 'Study',
    );

    _safeTransactions.insert(0, tx);
    notifyListeners();

    // Persist to Cloud Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseService.instance.saveUserProgress(
        uid: user.uid,
        balance: balance,
        totalEarned: totalEarned,
        totalMinutesFocused: totalMinutesFocused,
        sessionCount: sessionCount,
        streakDays: streakDays,
        lastActiveDate: lastActiveDate,
        dailyFocusMinutes: _safeDailyFocusMinutes,
        subjectFocusStats: _safeSubjectStats,
        dailySubjectStats: _safeDailySubjectStats,
        recentTransactions: _safeTransactions,
      );
    }
  }

  // Redeem Reward
  bool redeemReward(RewardItem reward) {
    if (balance < reward.costCoins) return false;

    _balance = balance - reward.costCoins;
    reward.timesRedeemed += 1;

    final now = DateTime.now();
    final tx = BankTransaction(
      id: 'tx_${now.millisecondsSinceEpoch}',
      title: 'Redeemed: ${reward.title}',
      description: 'Shop reward redemption',
      coins: reward.costCoins,
      type: TransactionType.withdrawal,
      date: now,
      category: 'Shop',
    );

    _safeTransactions.insert(0, tx);
    notifyListeners();

    // Persist to Cloud Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseService.instance.saveUserProgress(
        uid: user.uid,
        balance: balance,
        totalEarned: totalEarned,
        totalMinutesFocused: totalMinutesFocused,
        sessionCount: sessionCount,
        streakDays: streakDays,
        lastActiveDate: lastActiveDate,
        dailyFocusMinutes: _safeDailyFocusMinutes,
        recentTransactions: _safeTransactions,
        rewards: _safeRewards,
      );
    }

    return true;
  }

  void addCustomReward({
    required String title,
    required String description,
    required int costCoins,
    required String emoji,
    required String category,
  }) {
    _safeRewards.insert(
      0,
      RewardItem(
        id: 'r_custom_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        description: description,
        costCoins: costCoins,
        iconEmoji: emoji.isEmpty ? '⭐' : emoji,
        category: category,
        isCustom: true,
      ),
    );
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseService.instance.saveRewards(
        uid: user.uid,
        rewards: _safeRewards,
      );
    }
  }

  void deleteCustomReward(String id) {
    final beforeLen = _safeRewards.length;
    _safeRewards.removeWhere((r) => r.id == id && r.isCustom);
    if (_safeRewards.length == beforeLen) return;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseService.instance.saveRewards(
        uid: user.uid,
        rewards: _safeRewards,
      );
    }
  }

  Future<void> updateProfile({
    required String name,
    required String dreamCareer,
    String? academicGoal,
    double? dreamIncome,
  }) async {
    _profile = profile.copyWith(
      name: name,
      dreamCareer: dreamCareer,
      academicGoal: academicGoal ?? profile.academicGoal,
      dreamIncome: dreamIncome ?? profile.dreamIncome,
    );
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await DatabaseService.instance.updateUserProfile(
          uid: user.uid,
          name: name,
          dreamCareer: dreamCareer,
          academicGoal: academicGoal,
          dreamIncome: dreamIncome,
        );
      } catch (e) {
        debugPrint('AppState.updateProfile error: $e');
      }
    }
  }

  Future<void> updateSettings({
    bool? notificationsEnabled,
    bool? doNotDisturbEnabled,
    int? defaultTimerMinutes,
  }) async {
    if (notificationsEnabled != null) {
      _notificationsEnabled = notificationsEnabled;
    }
    if (doNotDisturbEnabled != null) {
      _doNotDisturbEnabled = doNotDisturbEnabled;
    }
    if (defaultTimerMinutes != null) {
      _defaultTimerMinutes = defaultTimerMinutes;
    }
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await DatabaseService.instance.updateUserSettings(
          uid: user.uid,
          notificationsEnabled: notificationsEnabled,
          doNotDisturbEnabled: doNotDisturbEnabled,
          defaultTimerMinutes: defaultTimerMinutes,
        );
      } catch (e) {
        debugPrint('AppState.updateSettings error: $e');
      }
    }
  }

  void toggleStudyPlanItem(String id) {
    final idx = _safeStudyPlan.indexWhere((item) => item.id == id);
    if (idx != -1) {
      _safeStudyPlan[idx].isCompleted = !_safeStudyPlan[idx].isCompleted;
      notifyListeners();
    }
  }
}
