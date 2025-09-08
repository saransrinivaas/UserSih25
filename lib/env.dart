import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get googlePlacesApiKey => dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
} 