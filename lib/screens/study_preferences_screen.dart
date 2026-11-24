import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/study_preferences.dart';
import '../services/study_preferences_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'main_navigation.dart';

class StudyPreferencesScreen extends StatefulWidget {
  const StudyPreferencesScreen({super.key});

  @override
  State<StudyPreferencesScreen> createState() => _StudyPreferencesScreenState();
}

class _StudyPreferencesScreenState extends State<StudyPreferencesScreen> {
  static const _days = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  int _step = 0;
  bool _saving = false;

  final Set<String> _availableDays = {'Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
  String _period = 'Morning';
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _sleep = const TimeOfDay(hour: 23, minute: 0);
  int _dailyHours = 3;
  int _sessionMinutes = 45;
  int _breakMinutes = 10;
  String _goal = 'Prepare for exams';
  final Set<String> _methods = {'Practice exercises'};

  final List<_SubjectDraft> _subjects = [_SubjectDraft()];
  final List<_ExamDraft> _exams = [];

  @override
  void dispose() {
    for (final subject in _subjects) { subject.dispose(); }
    for (final exam in _exams) { exam.dispose(); }
    super.dispose();
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isWake) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isWake ? _wake : _sleep,
    );
    if (picked != null) setState(() { if (isWake) { _wake = picked; } else { _sleep = picked; } });
  }

  void _next() {
    if (_step == 1) {
      if (_subjects.isEmpty || _subjects.any((s) => s.name.text.trim().isEmpty)) {
        _message('Please enter a name for every subject.');
        return;
      }
    }
    if (_step < 2) { setState(() => _step++); } else { _save(); }
  }

  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));


  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _message('Your session expired. Please log in again.');
      return;
    }

    setState(() => _saving = true);

    final prefs = StudyPreferences(
      availableDays: _days.where(_availableDays.contains).toList(),
      preferredPeriod: _period,
      wakeUpTime: _formatTime(_wake),
      sleepTime: _formatTime(_sleep),
      dailyStudyHours: _dailyHours,
      sessionMinutes: _sessionMinutes,
      breakMinutes: _breakMinutes,
      subjects: _subjects.map((s) => s.toJson()).toList(),
      exams: _exams
          .where((e) => e.subject.text.trim().isNotEmpty)
          .map((e) => e.toJson())
          .toList(),
      learningMethods: _methods.toList(),
      mainGoal: _goal,
    );

    try {
      // 1. Save preferences in Firestore.
      await StudyPreferencesService().save(user.uid, prefs);

      // 2. Reload the user's profile.
      await AppState.instance.loadUserDataFromFirestore(user.uid);

      // 3. Generate the personalized AI plan and save it.
      try {
        await AppState.instance.generateAIStudyPlan();
      } catch (e) {
        debugPrint('AI plan generation failed: $e');

        if (mounted) {
          _message(
            'Your preferences were saved, but AI plan generation failed. Please try again.',
          );
        }
        return;
      }

      // 4. Open the existing navigation screen.
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
            (_) => false,
      );
    } catch (e) {
      debugPrint('Study preferences save failed: $e');

      if (mounted) {
        _message(
          'Could not save your preferences. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final titles = ['Your availability', 'Your subjects & exams', 'Your study habits'];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Set up your study profile'),
        leading: _step == 0 ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _step--)),
      ),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('STEP ${_step + 1} OF 3', style: const TextStyle(color: AppColors.yellow, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (_step + 1) / 3, color: AppColors.yellow, backgroundColor: AppColors.fieldBorder),
          const SizedBox(height: 14),
          Text(titles[_step], style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('You can update these preferences later.', style: TextStyle(color: AppColors.textSecondary)),
        ])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: _step == 0 ? _availabilityStep() : _step == 1 ? _subjectsStep() : _habitsStep())),
        Padding(padding: const EdgeInsets.all(20), child: SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15)),
          onPressed: _saving ? null : _next,
          child: _saving ? const CircularProgressIndicator() : Text(_step == 2 ? 'Save preferences' : 'Continue', style: const TextStyle(fontWeight: FontWeight.bold)),
        ))),
      ])),
    );
  }

  Widget _availabilityStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle('Which days can you study?'),
    Wrap(spacing: 8, runSpacing: 8, children: _days.map((day) => FilterChip(
      label: Text(day), selected: _availableDays.contains(day), selectedColor: AppColors.yellow.withValues(alpha: .25),
      onSelected: (v) => setState(() { v ? _availableDays.add(day) : _availableDays.remove(day); }),
    )).toList()),
    const SizedBox(height: 12),
    const Text(
      'Choose the days when you usually have time for studying. You can change this later.',
      style: TextStyle(color: AppColors.textSecondary),
    ),
  ]);

  Widget _subjectsStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle('Add your subjects'),
    const Text('Add the subjects you want the AI to include in your weekly plan.', style: TextStyle(color: AppColors.textSecondary)),
    const SizedBox(height: 12),
    ..._subjects.asMap().entries.map((entry) => _subjectCard(entry.key, entry.value)),
    OutlinedButton.icon(onPressed: () => setState(() => _subjects.add(_SubjectDraft())), icon: const Icon(Icons.add), label: const Text('Add another subject')),
    const SizedBox(height: 24),
    _sectionTitle('Upcoming exams (optional)'),
    ..._exams.asMap().entries.map((entry) => _examCard(entry.key, entry.value)),
    OutlinedButton.icon(onPressed: () => setState(() => _exams.add(_ExamDraft())), icon: const Icon(Icons.add), label: const Text('Add an exam')),
  ]);

  Widget _subjectCard(int index, _SubjectDraft draft) => Card(
    color: const Color(0xFF19191F),
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: TextField(
            controller: draft.name,
            style: const TextStyle(color: Colors.white),
            decoration: _input('Subject name (e.g. Java)'),
          )),
          IconButton(
            onPressed: _subjects.length == 1 ? null : () => setState(() { _subjects.removeAt(index).dispose(); }),
            icon: const Icon(Icons.delete_outline),
          ),
        ]),
        const SizedBox(height: 16),
        _sectionTitle('How do you feel about this subject?'),
        _choiceGroup(
          draft.confidence,
          ['I need help', 'Some parts are difficult', 'I feel confident'],
          (value) => setState(() => draft.confidence = value),
        ),
        const SizedBox(height: 16),
        _sectionTitle('What would you like to work on?'),
        const Text(
          'Select all that apply.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: _SubjectDraft.focusOptions.map((option) => FilterChip(
          label: Text(option),
          selected: draft.focusAreas.contains(option),
          selectedColor: AppColors.yellow.withValues(alpha: .25),
          onSelected: (selected) => setState(() {
            selected ? draft.focusAreas.add(option) : draft.focusAreas.remove(option);
          }),
        )).toList()),
      ]),
    ),
  );

  Widget _examCard(int index, _ExamDraft draft) => Card(color: const Color(0xFF19191F), margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
    Row(children: [Expanded(child: TextField(controller: draft.subject, style: const TextStyle(color: Colors.white), decoration: _input('Exam subject'))), IconButton(onPressed: () => setState(() { _exams.removeAt(index).dispose(); }), icon: const Icon(Icons.delete_outline))]),
    const SizedBox(height: 8),
    Row(children: [Expanded(child: Text('Date: ${draft.date == null ? 'Not selected' : '${draft.date!.day}/${draft.date!.month}/${draft.date!.year}'}', style: const TextStyle(color: Colors.white))), TextButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730))); if (d != null) setState(() => draft.date = d); }, child: const Text('Choose date'))]),
  ])));

  Widget _habitsStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle('When do you prefer studying?'),
    _choiceGroup(_period, ['Morning', 'Afternoon', 'Evening', 'Flexible'], (v) => setState(() => _period = v)),
    const SizedBox(height: 18),
    _sectionTitle('Your daily routine'),
    _timeTile('Wake-up time', _formatTime(_wake), () => _pickTime(true)),
    _timeTile('Bedtime', _formatTime(_sleep), () => _pickTime(false)),
    const SizedBox(height: 12),
    _sectionTitle('How much can you study each day?'),
    DropdownButtonFormField<int>(value: _dailyHours, dropdownColor: const Color(0xFF25252B), decoration: _input('Daily study goal'), items: [1,2,3,4,5,6,7,8].map((v) => DropdownMenuItem(value: v, child: Text('$v hour${v == 1 ? '' : 's'}'))).toList(), onChanged: (v) => setState(() => _dailyHours = v ?? 3)),
    const SizedBox(height: 18),
    _sectionTitle('Focus session length'),
    _choiceGroup('$_sessionMinutes minutes', ['25 minutes', '45 minutes', '60 minutes', '90 minutes'], (v) => setState(() => _sessionMinutes = int.parse(v.split(' ').first))),
    const SizedBox(height: 18),
    _sectionTitle('Break duration'),
    _choiceGroup('$_breakMinutes minutes', ['5 minutes', '10 minutes', '15 minutes', '20 minutes'], (v) => setState(() => _breakMinutes = int.parse(v.split(' ').first))),
    const SizedBox(height: 18),
    _sectionTitle('How do you prefer to learn?'),
    ...['Read and understand lessons', 'Practice exercises', 'Watch videos', 'Create summaries / flashcards'].map((method) => CheckboxListTile(contentPadding: EdgeInsets.zero, value: _methods.contains(method), activeColor: AppColors.yellow, title: Text(method, style: const TextStyle(color: Colors.white)), onChanged: (v) => setState(() { v == true ? _methods.add(method) : _methods.remove(method); }))),
    const SizedBox(height: 12),
    _sectionTitle('Your main goal'),
    _choiceGroup(_goal, ['Prepare for exams', 'Improve my grades', 'Catch up on lessons', 'Build a regular study habit', 'Prepare for a competition'], (v) => setState(() => _goal = v)),
  ]);

  Widget _sectionTitle(String text) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)));
  InputDecoration _input(String hint) => InputDecoration(hintText: hint, hintStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: const Color(0xFF19191F), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13));
  Widget _choiceGroup(String selected, List<String> values, ValueChanged<String> onChanged) => Wrap(spacing: 8, runSpacing: 8, children: values.map((v) => ChoiceChip(label: Text(v), selected: selected == v, selectedColor: AppColors.yellow.withValues(alpha: .25), onSelected: (_) => onChanged(v))).toList());
  Widget _timeTile(String title, String value, VoidCallback onTap) => ListTile(contentPadding: EdgeInsets.zero, title: Text(title, style: const TextStyle(color: Colors.white)), trailing: TextButton(onPressed: onTap, child: Text(value, style: const TextStyle(color: AppColors.yellow))));
}

class _SubjectDraft {
  static const focusOptions = [
    'Understand lessons',
    'Practice exercises',
    'Memorize and revise',
    'Prepare for an exam',
  ];

  final name = TextEditingController();
  String confidence = 'Some parts are difficult';
  final Set<String> focusAreas = {};

  Map<String, dynamic> toJson() => {
    'name': name.text.trim(),
    'confidence': confidence,
    'focusAreas': focusAreas.toList(),
  };

  void dispose() => name.dispose();
}

class _ExamDraft {
  final subject = TextEditingController();
  DateTime? date;
  Map<String, dynamic> toJson() => {'subject': subject.text.trim(), 'date': date?.toIso8601String()};
  void dispose() => subject.dispose();
}
