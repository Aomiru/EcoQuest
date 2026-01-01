import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/species.dart';

/// Service wrapper around Google's Gemini model for generating species information.
///
/// Set the API key at build/run time using:
/// flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE
/// flutter build apk --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE
class GeminiService {
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyBrkv2cHEsDazb_19jN88RunOCXb-cO2q0',
  );

  late final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: _apiKey,
  );

  /// Asks a custom question about the given species.
  /// The question will be answered in the context of the specified species.
  Future<String> askQuestion(Species species, String question) async {
    if (_apiKey.isEmpty) {
      return 'Gemini API key not set. Pass with --dart-define=GEMINI_API_KEY=YOUR_KEY';
    }

    final prompt =
        '''
You are an expert on wildlife and nature, specifically about ${species.name} (${species.scientificName}).
A curious kid (ages 8-12) is asking you this question: "$question"

Requirements:
- Answer the question clearly, accurately and short in 1 sentence.
- Use kid-friendly language that's easy to understand.
- Keep the answer focused on ${species.name}.
- Make it educational and interesting!
- Do NOT include phrases like "great question" or conversational intros.
- If the question is not related to ${species.name}, politely redirect to information about this species.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);

      final raw = response.text?.trim();
      if (raw == null || raw.isEmpty) {
        return 'No answer generated.';
      }

      return raw;
    } catch (e) {
      return 'Error generating answer: $e';
    }
  }
}
