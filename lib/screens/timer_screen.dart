import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class TimerScreen extends StatefulWidget {
  final String? focusSubject;
  final int? focusDurationMinutes;
  final int focusRequestId;

  const TimerScreen({
    super.key,
    this.focusSubject,
    this.focusDurationMinutes,
    this.focusRequestId = 0,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  // Session State
  bool _isSessionActive = false;
  bool _isRunning = false;
  Timer? _ticker;

  final TextEditingController _sessionNameController = TextEditingController();

  int _selectedMinutes = 0;
  int _remainingSeconds = 0;
  int _secondsElapsed = 0;

  // Session Tag Colors (12 distinct vibrant colors so each session title has a unique color)
  static const List<Color> _availableColors = [
    Color(0xFF00E5FF), // Electric Cyan
    AppTheme.primaryGold, // Gold
    Color(0xFF00E676), // Emerald Mint
    Color(0xFFFF5252), // Sunset Coral
    Color(0xFFE040FB), // Neon Purple
    Color(0xFFFF9100), // Amber Orange
    Color(0xFF448AFF), // Royal Blue
    Color(0xFFFF4081), // Hot Pink
    Color(0xFFAEEA00), // Lime Green
    Color(0xFF7C4DFF), // Deep Indigo
    Color(0xFF1DE9B6), // Bright Teal
    Color(0xFFFF80AB), // Rose Pink
  ];

  // Static maps to remember assigned colors & display names for each title
  static final Map<String, Color> _savedTitleColors = {};
  static final Map<String, String> _savedTitleNames = {};

  /// Combines persisted Firestore subject colors with in-session saved colors
  Map<String, Color> _getAllTitleColors() {
    final map = <String, Color>{};
    for (final stat in AppState.instance.subjectFocusStats) {
      map[stat.name.trim().toLowerCase()] = stat.color;
    }
    map.addAll(_savedTitleColors);
    return map;
  }

  /// Combines persisted Firestore subject display names with in-session display names
  Map<String, String> _getAllTitleNames() {
    final map = <String, String>{};
    for (final stat in AppState.instance.subjectFocusStats) {
      map[stat.name.trim().toLowerCase()] = stat.name.trim();
    }
    map.addAll(_savedTitleNames);
    return map;
  }

  /// Returns the display name of another session that already owns [color], or null if free
  String? _ownerOfColor(Color color, {String? excludeKey}) {
    final allColors = _getAllTitleColors();
    final allNames = _getAllTitleNames();
    final targetArgb = color.toARGB32();
    for (final entry in allColors.entries) {
      if (excludeKey != null && entry.key == excludeKey) continue;
      if (entry.value.toARGB32() == targetArgb) {
        return allNames[entry.key] ?? entry.key;
      }
    }
    return null;
  }

  /// Returns the first unused color from [_availableColors], or the first color if all are used
  Color _firstAvailableColor({String? excludeKey}) {
    for (final c in _availableColors) {
      if (_ownerOfColor(c, excludeKey: excludeKey) == null) {
        return c;
      }
    }
    return _availableColors.first;
  }

  Color _getColorForTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      return _firstAvailableColor();
    }
    final key = title.trim().toLowerCase();
    final allColors = _getAllTitleColors();
    return allColors[key] ?? _firstAvailableColor(excludeKey: key);
  }

  Color get _currentSessionColor =>
      _getColorForTitle(_sessionNameController.text);

  // Pauses tracking (up to 5 pauses per session)
  static const int _maxPauses = 5;
  int? _pausesUsed;
  int get _safePausesUsed => _pausesUsed ?? 0;

  @override
  void initState() {
    super.initState();
    _pausesUsed = 0;
  }

  @override
  void didUpdateWidget(covariant TimerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.focusRequestId != oldWidget.focusRequestId &&
        widget.focusSubject != null &&
        widget.focusDurationMinutes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final subject = widget.focusSubject!.trim();
        final duration = widget.focusDurationMinutes!.clamp(5, 180);

        setState(() {
          _sessionNameController.text =
          subject.isEmpty ? 'Focus session' : subject;
          _selectedMinutes = duration;
          _remainingSeconds = duration * 60;
        });

        _startSession();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    SoundService.instance.stopAlarm();
    _sessionNameController.dispose();
    super.dispose();
  }

  void _startSession() {
    if (_selectedMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a session duration first!'),
          duration: Duration(seconds: 2),
        ),
      );
      _showDurationSliderDialog();
      return;
    }

    setState(() {
      _isSessionActive = true;
      _isRunning = true;
      _remainingSeconds = _selectedMinutes * 60;
      _secondsElapsed = 0;
      _pausesUsed = 0; // reset pauses for the new session
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _secondsElapsed++;
        });
      } else {
        _finishSession();
      }
    });
  }

  void _pauseSession() {
    setState(() => _isRunning = false);
    _ticker?.cancel();
  }

  void _resumeSession() {
    setState(() => _isRunning = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _secondsElapsed++;
        });
      } else {
        _finishSession();
      }
    });
  }

  void _onPauseTapped() {
    if (_safePausesUsed >= _maxPauses) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pauses left! You reached the limit of 5 pauses.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _pauseSession();
    setState(() => _pausesUsed = _safePausesUsed + 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session paused (${_maxPauses - _safePausesUsed} pauses left)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditSessionNameAndColorDialog() {
    final textController = TextEditingController(text: _sessionNameController.text);
    final initialKey = textController.text.trim().toLowerCase();
    final allColors = _getAllTitleColors();
    Color chosenColor = (initialKey.isNotEmpty && allColors.containsKey(initialKey))
        ? allColors[initialKey]!
        : _firstAvailableColor(excludeKey: initialKey.isEmpty ? null : initialKey);
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentKey = textController.text.trim().toLowerCase();
            final latestColors = _getAllTitleColors();
            final latestNames = _getAllTitleNames();
            final bool isExistingTitle =
                currentKey.isNotEmpty && latestColors.containsKey(currentKey);
            final Color? lockedColor =
                isExistingTitle ? latestColors[currentKey] : null;
            final String? existingDisplayName =
                isExistingTitle ? (latestNames[currentKey] ?? textController.text.trim()) : null;

            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.surfaceBorder),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              title: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: lockedColor ?? chosenColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Session Tag',
                    style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Session Name',
                    style: TextStyle(color: AppTheme.textDim, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: textController,
                    style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
                    onChanged: (val) {
                      final key = val.trim().toLowerCase();
                      setDialogState(() {
                        errorMsg = null;
                        if (key.isNotEmpty && latestColors.containsKey(key)) {
                          // Existing session title: lock to its assigned color
                          chosenColor = latestColors[key]!;
                        } else if (_ownerOfColor(chosenColor, excludeKey: key) != null) {
                          // New session title: auto-switch off any already-taken color
                          chosenColor = _firstAvailableColor(excludeKey: key);
                        }
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF14141C),
                      hintText: 'e.g. Web Engineering',
                      hintStyle: const TextStyle(color: AppTheme.textDim),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.surfaceBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryGold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Label Color',
                        style: TextStyle(color: AppTheme.textDim, fontSize: 12),
                      ),
                      if (isExistingTitle)
                        const Text(
                          'Locked to existing title',
                          style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _availableColors.map((color) {
                      final effectiveChosen = lockedColor ?? chosenColor;
                      final isSelected =
                          effectiveChosen.toARGB32() == color.toARGB32();
                      final ownerName = _ownerOfColor(
                        color,
                        excludeKey: currentKey.isEmpty ? null : currentKey,
                      );
                      final bool isTakenByOther = ownerName != null;
                      final bool isLockedOut = isExistingTitle && !isSelected;

                      return Tooltip(
                        message: isTakenByOther
                            ? 'Used by $ownerName'
                            : isLockedOut
                                ? '"$existingDisplayName" already has a color'
                                : 'Select color',
                        child: GestureDetector(
                          onTap: () {
                            if (isLockedOut) {
                              setDialogState(() {
                                errorMsg =
                                    '"$existingDisplayName" already has its own color and cannot use another.';
                              });
                              return;
                            }
                            if (isTakenByOther) {
                              setDialogState(() {
                                errorMsg =
                                    'This color is already used by "$ownerName". Pick another color.';
                              });
                              return;
                            }
                            setDialogState(() {
                              chosenColor = color;
                              errorMsg = null;
                            });
                          },
                          child: Opacity(
                            opacity: (isTakenByOther || isLockedOut) ? 0.3 : 1.0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.6),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 15,
                                      color: Colors.black,
                                    )
                                  : isTakenByOther
                                      ? const Icon(
                                          Icons.lock_outline,
                                          size: 13,
                                          color: Colors.black87,
                                        )
                                      : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMsg!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textDim)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newTitle = textController.text.trim();
                    if (newTitle.isEmpty) {
                      setDialogState(() {
                        errorMsg = 'Please enter a session name.';
                      });
                      return;
                    }
                    final newKey = newTitle.toLowerCase();
                    final finalColor = lockedColor ?? chosenColor;

                    // Final 1-to-1 uniqueness check before saving
                    final conflictOwner =
                        _ownerOfColor(finalColor, excludeKey: newKey);
                    if (conflictOwner != null) {
                      setDialogState(() {
                        errorMsg =
                            'This color is already used by "$conflictOwner". Pick another color.';
                      });
                      return;
                    }

                    setState(() {
                      _sessionNameController.text = newTitle;
                      _savedTitleColors[newKey] = finalColor;
                      _savedTitleNames[newKey] = newTitle;
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onStopTapped() {
    // If the countdown already hit 0, complete with normal rewards
    if (_remainingSeconds <= 0) {
      _finishSession();
      return;
    }

    // Session is unfinished! Show dialog with Pause or Exit (no reward) options
    final remainingPauses = _maxPauses - _safePausesUsed;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.surfaceBorder),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.pause_circle_outline,
                color: AppTheme.primaryGold,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Unfinished Session',
              style: TextStyle(
                color: AppTheme.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You have not completed your target focus time yet. What would you like to do?',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Option 1: Take a Pause Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF181822),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: remainingPauses > 0
                      ? AppTheme.primaryGold.withValues(alpha: 0.35)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pause_circle,
                    color: remainingPauses > 0 ? AppTheme.primaryGold : AppTheme.textDim,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Take a Pause',
                          style: TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          remainingPauses > 0
                              ? '$remainingPauses of $_maxPauses pauses remaining'
                              : '0 of $_maxPauses pauses left (Limit reached)',
                          style: TextStyle(
                            color: remainingPauses > 0
                                ? AppTheme.primaryGold
                                : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Exit without rewards Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF181822),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.cancel_outlined,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exit Session',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'You will earn NO rewards for this session.',
                          style: TextStyle(
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
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _exitWithoutRewards();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Exit',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (remainingPauses > 0)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pauseSession();
                      setState(() => _pausesUsed = _safePausesUsed + 1);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Session paused (${_maxPauses - _safePausesUsed} pauses left)',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Take Pause',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Keep Going',
                      style: TextStyle(color: AppTheme.textDim),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _exitWithoutRewards() {
    _ticker?.cancel();
    setState(() {
      _isSessionActive = false;
      _isRunning = false;
      _remainingSeconds = _selectedMinutes * 60;
      _secondsElapsed = 0;
      _pausesUsed = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session exited. No rewards were earned.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _finishSession() {
    _ticker?.cancel();
    final minutesDone = (_secondsElapsed / 60).ceil();
    final bonus = (minutesDone ~/ 30) * 5;
    final earnedCoins = minutesDone + bonus;

    if (minutesDone > 0) {
      AppState.instance.recordFocusSession(
        subject: _sessionNameController.text.trim().isEmpty
            ? 'Deep Focus'
            : _sessionNameController.text.trim(),
        minutesCompleted: minutesDone,
        tagColorValue: _currentSessionColor.toARGB32(),
      );
    }

    setState(() {
      _isSessionActive = false;
      _isRunning = false;
      _remainingSeconds = _selectedMinutes * 60;
      _secondsElapsed = 0;
    });

    // Start looping notification chime — only stops when user clicks Collect
    SoundService.instance.startSessionCompleteAlarm();

    _showCelebrationDialog(minutesDone, earnedCoins);
  }

  void _showCelebrationDialog(int minutes, int earnedCoins) {
    final durationStr = _formatDuration(minutes);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.primaryGold),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.notifications_active_rounded,
                color: AppTheme.primaryGold,
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Session Completed! 🎉',
                  style: TextStyle(
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You focused for $durationStr.\nTap Collect to claim your reward and stop the alarm!',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF191924),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryGold.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.monetization_on_outlined,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+$earnedCoins FC',
                      style: const TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  SoundService.instance.stopAlarm();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Collect',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats minutes into human readable text (e.g. "45 min", "1h", "1h 30m", "3h")
  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes}m';
  }

  /// Popup window with a volume-style slider to programme session duration
  void _showDurationSliderDialog() {
    double tempMinutes = (_selectedMinutes >= 5 ? _selectedMinutes : 5).toDouble();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final roundedMins = tempMinutes.round();
            final bonus = (roundedMins ~/ 30) * 5;
            final estimatedReward = roundedMins + bonus;

            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.surfaceBorder),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppTheme.primaryGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Programme a session',
                    style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 14),
                  // Big display of chosen time (e.g. "45 min", "1h", "2h 30m")
                  Text(
                    _formatDuration(roundedMins),
                    style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Adjust your focus session duration',
                    style: TextStyle(
                      color: AppTheme.textDim,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Volume-style Slider Bar (Min 5m, Max 3h / 180m)
                  Row(
                    children: [
                      const Text(
                        '5m',
                        style: TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.primaryGold,
                            inactiveTrackColor: const Color(0xFF262633),
                            thumbColor: AppTheme.primaryGold,
                            overlayColor: AppTheme.primaryGold.withValues(alpha: 0.2),
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 10,
                            ),
                            valueIndicatorColor: AppTheme.primaryGold,
                            valueIndicatorTextStyle: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: Slider(
                            value: tempMinutes,
                            min: 5,
                            max: 180, // Max 3 hours
                            divisions: 35, // 5 min increments from 5 to 180
                            label: _formatDuration(roundedMins),
                            onChanged: (val) {
                              setDialogState(() {
                                tempMinutes = val;
                              });
                            },
                          ),
                        ),
                      ),
                      const Text(
                        '3h',
                        style: TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Rectangle displaying the earning reward to obtain
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF191924),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primaryGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.monetization_on_outlined,
                            color: AppTheme.primaryGold,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reward upon completion',
                                style: TextStyle(
                                  color: AppTheme.textDim,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    '+$estimatedReward Coins',
                                    style: const TextStyle(
                                      color: AppTheme.primaryGold,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (bonus > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.depositGreen.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '+$bonus Bonus',
                                        style: const TextStyle(
                                          color: AppTheme.depositGreen,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textDim),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedMinutes = roundedMins;
                      _remainingSeconds = _selectedMinutes * 60;
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Session set to ${_formatDuration(_selectedMinutes)} (+$estimatedReward Coins)',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDigital(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: _isSessionActive ? _buildActiveScreen() : _buildSetupScreen(),
      ),
    );
  }

  // -------------------------------------------------------------
  // SCREEN 1: Setup Focus Session (Responsive & Pinned Bottom)
  // -------------------------------------------------------------
  Widget _buildSetupScreen() {
    final bonus = (_selectedMinutes ~/ 30) * 5;
    final estimatedReward = _selectedMinutes + bonus;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final clockSize = (availableHeight * 0.25).clamp(140.0, 220.0);
        final gap = (availableHeight * 0.016).clamp(8.0, 16.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Focus session',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: gap),

              // Session Name Box with Label Color Circle & Edit Icon
              InkWell(
                onTap: _showEditSessionNameAndColorDialog,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      // Small circle label with chosen color
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _currentSessionColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _currentSessionColor.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _sessionNameController.text.trim().isEmpty
                              ? 'Session name...'
                              : _sessionNameController.text.trim(),
                          style: TextStyle(
                            color: _sessionNameController.text.trim().isEmpty
                                ? AppTheme.textMuted
                                : AppTheme.textWhite,
                            fontSize: 14,
                            fontWeight: _sessionNameController.text.trim().isEmpty
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.edit_outlined,
                        color: AppTheme.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: gap * 1.1),

              // Set session duration header
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Set session duration',
                      style: TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_selectedMinutes > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        _formatDuration(_selectedMinutes),
                        style: const TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    const Text(
                      'drag to adjust',
                      style: TextStyle(color: AppTheme.textDim, fontSize: 11),
                    ),
                  ],
                ),
              ),
              SizedBox(height: gap * 0.8),

              // Circular Analog Clock with Hands (Classic App Yellow Design)
              Center(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    // Dragging to adjust time
                    final dy = details.delta.dy;
                    if (dy < -2 && _selectedMinutes < 180) {
                      setState(() {
                        _selectedMinutes = (_selectedMinutes + 5).clamp(5, 180);
                        _remainingSeconds = _selectedMinutes * 60;
                      });
                    } else if (dy > 2 && _selectedMinutes > 5) {
                      setState(() {
                        _selectedMinutes = (_selectedMinutes - 5).clamp(5, 180);
                        _remainingSeconds = _selectedMinutes * 60;
                      });
                    }
                  },
                  child: CustomPaint(
                    size: Size(clockSize, clockSize),
                    painter: _AnalogClockPainter(
                      durationMinutes: _selectedMinutes,
                    ),
                  ),
                ),
              ),
              SizedBox(height: gap * 1.1),

              // Action Options List: Programme a session
              _buildOptionTile(
                icon: Icons.tune_rounded,
                title: 'Programme a session',
                trailingText: _selectedMinutes > 0
                    ? _formatDuration(_selectedMinutes)
                    : 'Set time',
                onTap: _showDurationSliderDialog,
              ),
              SizedBox(height: gap * 0.9),

              // Session Summary Card (Aesthetic layout balance & reward info)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primaryGold.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.monetization_on_outlined,
                        color: AppTheme.primaryGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Session Reward',
                            style: TextStyle(
                              color: AppTheme.textDim,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '+$estimatedReward Coins',
                            style: const TextStyle(
                              color: AppTheme.primaryGold,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B24),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.surfaceBorder),
                      ),
                      child: const Text(
                        '5 Pauses max',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Pushes the buttons to the bottom of the screen
              const Spacer(),

              // Bottom Buttons: Cancel & Start now (Classic Yellow Gold App Design)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedMinutes = 0;
                          _remainingSeconds = 0;
                          _sessionNameController.clear();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B1B22),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: const BorderSide(color: AppTheme.surfaceBorder),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text(
                        'Start now',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // SCREEN 2: Active Focus Session (Responsive & Centered)
  // -------------------------------------------------------------
  Widget _buildActiveScreen() {
    final totalSec = _selectedMinutes * 60;
    final progress = totalSec == 0 ? 0.0 : (_secondsElapsed) / totalSec;
    final liveEarnings = (_secondsElapsed * 0.0104).toStringAsFixed(2);
    final pausesLeft = _maxPauses - _safePausesUsed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final clockSize = (availableHeight * 0.32).clamp(180.0, 260.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Session Name Title with Small Color Circle Label
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _currentSessionColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sessionNameController.text.trim().isEmpty
                        ? 'Focus session'
                        : _sessionNameController.text.trim(),
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Active Countdown Circular Clock (App Gold Yellow Design)
              CustomPaint(
                size: Size(clockSize, clockSize),
                painter: _ActiveTimerPainter(
                  progress: progress,
                  digitalTime: _formatDigital(_remainingSeconds),
                ),
              ),
              const Spacer(),

              // Controls: Play, Pause, Stop
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play
                  IconButton(
                    onPressed: _isRunning ? null : _resumeSession,
                    iconSize: 36,
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      color: !_isRunning ? AppTheme.primaryGold : AppTheme.textDim,
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Pause (with 5-pauses tracking)
                  IconButton(
                    onPressed: _isRunning ? _onPauseTapped : null,
                    iconSize: 32,
                    icon: Icon(
                      Icons.pause_rounded,
                      color: _isRunning ? Colors.white : AppTheme.textDim,
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Stop (rectangle icon: shows Pause or Exit without reward popup!)
                  IconButton(
                    onPressed: _onStopTapped,
                    iconSize: 28,
                    icon: const Icon(Icons.stop_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Pause Counter Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: pausesLeft > 0
                        ? AppTheme.surfaceBorder
                        : Colors.redAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Pauses remaining: $pausesLeft/$_maxPauses',
                  style: TextStyle(
                    color: pausesLeft > 0 ? AppTheme.textMuted : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),

              // Bottom Metrics: Earned so far & session earnings
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Earned so far: ',
                        style: TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '\$${AppState.instance.balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                        style: const TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'session earnings: ',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                      Text(
                        '+\$$liveEarnings',
                        style: const TextStyle(
                          color: AppTheme.depositGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textWhite, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailingText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  trailingText,
                  style: const TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Analog Clock Painter for Setup (Image 2 - Classic Yellow Design)
// -------------------------------------------------------------
class _AnalogClockPainter extends CustomPainter {
  final int durationMinutes;

  _AnalogClockPainter({required this.durationMinutes});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Dark blue clock background with subtle shadow
    final bgPaint = Paint()
      ..color = const Color(0xFF1F2F4D)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Minute Ticks
    final tickPaint = Paint()
      ..color = const Color(0xFF3B4E70)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 60; i++) {
      final angle = (i * 6) * pi / 180;
      final isMajor = i % 5 == 0;
      final tickLength = isMajor ? 8.0 : 4.0;
      final start = Offset(
        center.dx + (radius - 12) * cos(angle),
        center.dy + (radius - 12) * sin(angle),
      );
      final end = Offset(
        center.dx + (radius - 12 - tickLength) * cos(angle),
        center.dy + (radius - 12 - tickLength) * sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }

    // Yellow Hands (Matching App Design)
    final handPaint = Paint()
      ..color = AppTheme.primaryGold
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Hour hand (approx 2 o'clock)
    final hourAngle = (durationMinutes * 6 - 90) * pi / 180;
    final hourHandEnd = Offset(
      center.dx + (radius * 0.5) * cos(hourAngle),
      center.dy + (radius * 0.5) * sin(hourAngle),
    );
    canvas.drawLine(center, hourHandEnd, handPaint);

    // Minute hand (pointing to 3 o'clock / horizontal)
    final minuteHandEnd = Offset(center.dx + (radius * 0.65), center.dy);
    canvas.drawLine(center, minuteHandEnd, handPaint);

    // Center pin
    final pinPaint = Paint()..color = AppTheme.primaryGold;
    canvas.drawCircle(center, 4, pinPaint);
  }

  @override
  bool shouldRepaint(covariant _AnalogClockPainter oldDelegate) {
    return oldDelegate.durationMinutes != durationMinutes;
  }
}

// -------------------------------------------------------------
// Active Countdown Painter (Image 3 - Classic Yellow Design)
// -------------------------------------------------------------
class _ActiveTimerPainter extends CustomPainter {
  final double progress;
  final String digitalTime;

  _ActiveTimerPainter({
    required this.progress,
    required this.digitalTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Dark Blue dial
    final bgPaint = Paint()
      ..color = const Color(0xFF1E2F4C)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Perimeter tick marks
    final tickPaint = Paint()
      ..color = const Color(0xFF354B70)
      ..strokeWidth = 1.2;

    for (int i = 0; i < 60; i++) {
      final angle = (i * 6) * pi / 180;
      final tickLength = (i % 5 == 0) ? 6.0 : 3.0;
      final start = Offset(
        center.dx + (radius - 10) * cos(angle),
        center.dy + (radius - 10) * sin(angle),
      );
      final end = Offset(
        center.dx + (radius - 10 - tickLength) * cos(angle),
        center.dy + (radius - 10 - tickLength) * sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }

    // Active Yellow Arc (Matching App Design)
    final arcPaint = Paint()
      ..color = AppTheme.primaryGold
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 3),
      -pi / 2,
      sweep,
      false,
      arcPaint,
    );

    // Center Digital Time Text (20:00 or 01:00:00)
    final textPainter = TextPainter(
      text: TextSpan(
        text: digitalTime,
        style: TextStyle(
          color: Colors.white,
          fontSize: digitalTime.length > 5 ? 30 : 38,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ActiveTimerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.digitalTime != digitalTime;
  }
}
