
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/study_plan_item.dart';

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const List<String> _models = [
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
  ];

  static const Duration _requestTimeout = Duration(seconds: 30);

  Future<List<StudyPlanItem>> generateWeeklyPlan({
    required Map<String, dynamic> preferences,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'Gemini API key missing. Check secrets.json and run configuration.',
      );
    }

    final prompt = '''
You are an expert AI study planner.

Create a personalized weekly study plan using these student preferences:

${jsonEncode(preferences)}

Rules:
- Use only the days listed in availableDays.
- Use the student's preferred study period when possible.
- Respect wakeUpTime and sleepTime.
- Respect dailyStudyHours.
- Use sessionMinutes as the preferred duration for each session.
- Consider breakMinutes between study sessions.
- Prioritize subjects with lower confidence.
- Consider exam dates and prioritize upcoming exams.
- Use the student's learningMethods and mainGoal.
- Create realistic and balanced study sessions.
- Do not invent subjects that are not in the preferences.
- Return day names in English.
- timeSlot must use the format "HH:mm - HH:mm".
- durationMinutes must be an integer.

Return a JSON object containing a "sessions" array.
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'sessions': {
              'type': 'ARRAY',
              'items': {
                'type': 'OBJECT',
                'properties': {
                  'day': {'type': 'STRING'},
                  'timeSlot': {'type': 'STRING'},
                  'subject': {'type': 'STRING'},
                  'objective': {'type': 'STRING'},
                  'durationMinutes': {'type': 'INTEGER'},
                },
                'required': [
                  'day',
                  'timeSlot',
                  'subject',
                  'objective',
                  'durationMinutes',
                ],
              },
            },
          },
          'required': ['sessions'],
        },
      },
    });

    Object? lastError;

    for (final model in _models) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$model:generateContent',
      );

      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          final response = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'x-goog-api-key': _apiKey,
                },
                body: requestBody,
              )
              .timeout(_requestTimeout);

          if (response.statusCode == 200) {
            return _parsePlanResponse(response.body);
          }

          final message = _extractErrorMessage(response.body);
          lastError = Exception(
            'Gemini ($model) HTTP ${response.statusCode}: ${message ?? response.body}',
          );

          final isTransient =
              response.statusCode == 503 || response.statusCode == 429;
          if (isTransient && attempt < 2) {
            debugPrint(
              'Gemini ($model) overloaded (${response.statusCode}). Retrying in 2s...',
            );
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }

          // Fall back to the next model on persistent 503/429 or model-not-found (404).
          if (isTransient || response.statusCode == 404) {
            debugPrint(
              'Gemini ($model) unavailable (${response.statusCode}). Switching fallback model...',
            );
            break;
          }

          // Non-retryable client error (e.g., 400/401/403): fail immediately.
          throw lastError;
        } on TimeoutException catch (e) {
          lastError = e;
          debugPrint('Gemini ($model) timed out. Switching fallback model...');
          break;
        }
      }
    }

    throw lastError ??
        Exception('All Gemini models are currently unavailable. Please try again.');
  }

  String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
        return (decoded['error'] as Map)['message']?.toString();
      }
    } catch (_) {}
    return null;
  }

  List<StudyPlanItem> _parsePlanResponse(String responseBody) {
    final responseData = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List?;

    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }

    final content = candidates.first['content'] as Map?;
    final parts = content?['parts'] as List?;

    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini returned no generated content.');
    }

    final generatedText = parts.first['text'] as String?;

    if (generatedText == null || generatedText.isEmpty) {
      throw Exception('Gemini returned empty text.');
    }

    final planData = jsonDecode(generatedText) as Map<String, dynamic>;
    final sessions = planData['sessions'] as List?;

    if (sessions == null || sessions.isEmpty) {
      throw Exception('Gemini did not generate any study sessions.');
    }

    return sessions.asMap().entries.map((entry) {
      final index = entry.key;
      final session = Map<String, dynamic>.from(entry.value as Map);

      return StudyPlanItem(
        id: 'gemini_${DateTime.now().microsecondsSinceEpoch}_$index',
        day: session['day'] as String,
        timeSlot: session['timeSlot'] as String,
        subject: session['subject'] as String,
        objective: session['objective'] as String,
        durationMinutes: (session['durationMinutes'] as num).toInt(),
        isCompleted: false,
      );
    }).toList();
  }
}
