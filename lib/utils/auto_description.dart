import 'dart:io';
import 'dart:convert';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;
import '../env.dart';

class AutoDescriptionService {
  Future<List<String>> _labelImage(File? imageFile) async {
    if (imageFile == null) return [];
    try {
      final input = InputImage.fromFile(imageFile);
      final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
      final labels = await labeler.processImage(input);
      await labeler.close();
      return labels.map((e) => e.label.toLowerCase()).toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _mapLabelsToPhrases(String category, List<String> labels) {
    final phrases = <String>[];
    final has = (String k) => labels.any((l) => l.contains(k));
    switch (category.toLowerCase()) {
      case 'pothole':
        if (has('road') || has('street')) phrases.add('There is a pothole on the road');
        if (has('crack') || has('hole')) phrases.add('The surface is cracked and uneven');
        if (has('water')) phrases.add('Water has collected inside, making it hazardous');
        break;
      case 'garbage':
        if (has('plastic') || has('bag') || has('trash')) phrases.add('Plastic and other waste is scattered');
        if (has('street') || has('road')) phrases.add('Garbage is lying on the street');
        break;
      case 'streetlight':
        if (has('light') || has('lamp')) phrases.add('The streetlight appears to be broken');
        if (has('dark')) phrases.add('The area is poorly lit at night');
        break;
      default:
        if (labels.isNotEmpty) phrases.add('Observed: ${labels.take(3).join(', ')}');
    }
    return phrases;
  }

  Future<String?> _reverseGeocode(double? lat, double? lng) async {
    if (lat == null || lng == null) return null;
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final street = [p.street, p.subLocality, p.locality].where((e) => e != null && e!.isNotEmpty).map((e) => e!).join(', ');
      return street.isEmpty ? null : street;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _nearbyLandmarks(double? lat, double? lng) async {
    if (lat == null || lng == null) return [];
    final key = Env.googlePlacesApiKey;
    if (key.isEmpty) return [];
    try {
      final url = Uri.parse('https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=300&key=$key');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final names = results.map((e) => e['name']?.toString()).where((e) => e != null && e!.isNotEmpty).cast<String>().take(2).toList();
      return names;
    } catch (_) {
      return [];
    }
  }

  Future<String> generate({
    required String category,
    required File? imageFile,
    required double? lat,
    required double? lng,
  }) async {
    final labels = await _labelImage(imageFile);
    final phrases = _mapLabelsToPhrases(category, labels);
    final street = await _reverseGeocode(lat, lng);
    final landmarks = await _nearbyLandmarks(lat, lng);

    final parts = <String>[];
    final cat = category.isEmpty ? 'issue' : category.toLowerCase();
    if (street != null) {
      parts.add('Reported a $cat on $street');
    } else {
      parts.add('Reported a $cat at the provided location');
    }
    if (landmarks.isNotEmpty) {
      parts.add('near ${landmarks.join(' and ')}');
    }
    String sentence = parts.join(', ') + '.';
    if (phrases.isNotEmpty) {
      sentence += ' ${phrases.join('. ')}.';
    }
    return sentence;
  }
} 