import 'package:flutter/material.dart';
import '../models/study_plan_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class StudyPlanScreen extends StatefulWidget {
  final Function(String, int) onStartFocus;

  const StudyPlanScreen({super.key, required this.onStartFocus});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  String _selectedDay = 'Monday';
  bool _isGenerating = false;


  Future<void> _regenerateAIPlan() async {
    setState(() => _isGenerating = true);

    try {
      await AppState.instance.generateAIStudyPlan();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surfaceCard,
          content: Row(
            children: const [
              Icon(
                Icons.auto_awesome,
                color: AppTheme.primaryGold,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Study Plan generated successfully!',
                  style: TextStyle(color: AppTheme.textWhite),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Study plan generation failed: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Failed to generate your study plan. Please try again.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final profile = state.profile;
        final dayItems = state.studyPlan.where((item) => item.day == _selectedDay).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('AI Weekly Plan'),
            actions: [
              IconButton(
                onPressed: _isGenerating ? null : _regenerateAIPlan,
                icon: _isGenerating
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryGold,
                  ),
                )
                    : const Icon(Icons.auto_awesome, color: AppTheme.primaryGold),
                tooltip: 'Regenerate Plan with AI',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top AI Header Banner
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.surfaceCard,
                        AppTheme.surfaceCard.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.psychology_outlined,
                          color: AppTheme.primaryGold,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personalized for ${profile.name}',
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Aiming for: ${profile.academicGoal} â€¢ ${profile.preferredTime} focus blocks',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Days selector pills
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _days.length,
                    itemBuilder: (context, index) {
                      final day = _days[index];
                      final isSelected = day == _selectedDay;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(day),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryGold,
                          backgroundColor: AppTheme.surfaceCard,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : AppTheme.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedDay = day);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Schedule items list
                Expanded(
                  child: dayItems.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 40, color: AppTheme.textDim),
                        const SizedBox(height: 12),
                        Text(
                          'Rest day on $_selectedDay!\nUse coins to redeem a treat.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: dayItems.length,
                    itemBuilder: (context, index) {
                      final item = dayItems[index];
                      return _StudyBlockCard(
                        item: item,
                        onToggleComplete: () => state.toggleStudyPlanItem(item.id),
                        onStartFocus: () => widget.onStartFocus(
                          item.subject,
                          item.durationMinutes,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StudyBlockCard extends StatelessWidget {
  final StudyPlanItem item;
  final VoidCallback onToggleComplete;
  final VoidCallback onStartFocus;

  const _StudyBlockCard({
    required this.item,
    required this.onToggleComplete,
    required this.onStartFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isCompleted
              ? AppTheme.depositGreen.withOpacity(0.5)
              : AppTheme.surfaceBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Time & duration
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: AppTheme.primaryGold),
                  const SizedBox(width: 6),
                  Text(
                    '${item.timeSlot} (${item.durationMinutes} min)',
                    style: const TextStyle(
                      color: AppTheme.goldLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              // Complete Checkbox
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onToggleComplete,
                icon: Icon(
                  item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: item.isCompleted ? AppTheme.depositGreen : AppTheme.textDim,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.subject,
            style: TextStyle(
              color: AppTheme.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.objective,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.isCompleted
                    ? 'Completed âœ“'
                    : 'Earn ~${item.durationMinutes} FocusCoins',
                style: TextStyle(
                  color: item.isCompleted ? AppTheme.depositGreen : AppTheme.primaryGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!item.isCompleted)
                ElevatedButton.icon(
                  onPressed: onStartFocus,
                  icon: const Icon(Icons.play_arrow, size: 16, color: Colors.black),
                  label: const Text('Start Focus', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
