
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/study_plan_item.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  static const String _apiKey =
  String.fromEnvironment('GEMINI_API_KEY');

static const String _model = 'gemini-3.8-flash';

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

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
          '$_model:generateContent',
    );

late http.Response response;

for (var attempt = 1; attempt <= 3; attempt++) {
  response = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': _apiKey,
    },
    body: jsonEncode({
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
    }),
  );

  if (response.statusCode != 503 || attempt == 3) {
    break;
  }

  debugPrint('Gemini overloaded. Retry $attempt in ${attempt * 2} seconds...');
  await Future.delayed(Duration(seconds: attempt * 2));
}

    final responseData =
    jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final error = responseData['error'];
      final message = error is Map
          ? error['message']?.toString()
          : null;

     throw Exception(
  'Gemini HTTP ${response.statusCode}: ${message ?? response.body}',
);
    }

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

    final planData =
    jsonDecode(generatedText) as Map<String, dynamic>;

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
        durationMinutes:
        (session['durationMinutes'] as num).toInt(),
        isCompleted: false,
      );
    }).toList();
  }
}
