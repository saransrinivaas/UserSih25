// home_page.dart (drop-in replacement)
// Note: This file assumes Firebase is initialized in main.dart and Firestore persistence enabled.

import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'widgets/app_botton_nav.dart'; // keep path correct
import 'widgets/app_drawer.dart';
import '../utils/auto_description.dart';

double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000; // meters
  final dLat = (lat2 - lat1) * (pi / 180);
  final dLon = (lon2 - lon1) * (pi / 180);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
          sin(dLon / 2) * sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

enum AppLang { en, hi }
enum VoiceStep { category, confirmCategory, photo, submit, done }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // UI / state
  final ScrollController _scroll = ScrollController();
  final GlobalKey _detailsKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AppLang _lang = AppLang.en;

  Map<String, dynamic>? _selectedCategory;
  File? _imageFile;
  String _description = '';
  String? _locationText; // stored as "lat,lng"
  bool _isLoading = false;

  // Voice control
  late final stt.SpeechToText _speech;
  late final FlutterTts _tts;
  bool _isListening = false;
  VoiceStep _voiceStep = VoiceStep.category;
  String _lastHeard = '';
  bool _autoVoiceHandled = false;
  Timer? _voiceTimer;
  bool _isSpeaking = false;
  int _stepAttempts = 0;
  String _voiceUIHint = '';
  bool _voiceActive = false;

  // categories (same as yours)
  final List<Map<String, dynamic>> _categories = [
    {'id': 'pothole', 'icon': Icons.traffic, 'label': {'en': 'Pothole', 'hi': 'गड्ढा'}},
    {'id': 'garbage', 'icon': Icons.delete_outline, 'label': {'en': 'Garbage', 'hi': 'कूड़ा'}},
    {'id': 'bin', 'icon': Icons.delete, 'label': {'en': 'Broken Bin', 'hi': 'टूटी डस्टबिन'}},
    {'id': 'streetlight', 'icon': Icons.lightbulb_outline, 'label': {'en': 'Streetlight', 'hi': 'स्ट्रीट लाइट'}},
    {'id': 'toilet', 'icon': Icons.wc, 'label': {'en': 'Public Toilet', 'hi': 'सार्वजनिक शौचालय'}},
    {'id': 'mosquito', 'icon': Icons.bug_report_outlined, 'label': {'en': 'Mosquito Menace', 'hi': 'मच्छर समस्या'}},
    {'id': 'water', 'icon': Icons.water_damage_outlined, 'label': {'en': 'Water Stagnation', 'hi': 'पानी भराव'}},
    {'id': 'drain', 'icon': Icons.plumbing, 'label': {'en': 'Storm Drains', 'hi': 'नाला समस्या'}},
    {'id': 'dogs', 'icon': Icons.pets, 'label': {'en': 'Street Dogs', 'hi': 'आवारा कुत्ते'}},
    {'id': 'tree', 'icon': Icons.park, 'label': {'en': 'Tree Fallen', 'hi': 'गिरे पेड़'}},
    {'id': 'other', 'icon': Icons.more_horiz, 'label': {'en': 'Other', 'hi': 'अन्य'}},
  ];

  // translations
  static const Map<AppLang, Map<String, Map<String, String>>> _translations = {
    AppLang.en: {
      'home': {
        'title': 'City Connect',
        'gList': 'Grievances',
        'viewAndReport': 'Select an issue to add details & submit',
        'location': 'Use Current Location',
        'pick': 'Pick from Gallery',
        'camera': 'Take Photo',
        'desc': 'Add Description',
        'descHint': 'Describe the problem (optional)',
        'submit': 'Submit Issue',
        'selected': 'Selected Issue',
        'noImage': 'No image selected',
        'logout': 'Logout',
        'delete': 'Delete Account',
        'profile': 'Profile',
        'report': 'Reports',
        'autoDesc': 'Auto Description',
      }
    },
    AppLang.hi: {
      'home': {
        'title': 'सिटी कनेक्ट',
        'gList': 'शिकायतें',
        'viewAndReport': 'विवरण जोड़ने व सबमिट करने के लिए शिकायत चुनें',
        'location': 'वर्तमान स्थान उपयोग करें',
        'pick': 'गैलरी से चुनें',
        'camera': 'फोटो लें',
        'desc': 'विवरण जोड़ें',
        'descHint': 'समस्या का विवरण (वैकल्पिक)',
        'submit': 'शिकायत सबमिट करें',
        'selected': 'चयनित शिकायत',
        'noImage': 'कोई तस्वीर नहीं चुनी गई',
        'logout': 'लॉग आउट',
        'delete': 'खाता हटाएं',
        'profile': 'प्रोफ़ाइल',
        'report': 'रिपोर्ट',
        'autoDesc': 'स्वतः विवरण',
      }
    },
  };

  Map<String, String> _t(String ns) {
    final langMap = _translations[_lang];
    if (langMap == null) return {};
    return langMap[ns] ?? {};
  }

  // ----------------------- Helpers & UI behaviors -----------------------

  void _selectCategory(Map<String, dynamic> cat) {
    setState(() => _selectedCategory = cat);
    _scrollToDetails();
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _tts.awaitSpeakCompletion(true);
    // Optional: warn when offline before voice
    Connectivity().onConnectivityChanged.listen((event) async {
      if (event != ConnectivityResult.none) {
        await _syncPendingImages();
      }
    });
    // Also attempt a sync on start
    Future.microtask(() async => await _syncPendingImages());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (!_autoVoiceHandled && args is Map && args['voiceStart'] == true) {
      _autoVoiceHandled = true;
      _startVoiceFlow();
    }
  }

  @override
  void dispose() {
    try { _speech.stop(); } catch (_) {}
    try { _tts.stop(); } catch (_) {}
    _voiceTimer?.cancel();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    try {
      _isSpeaking = true;
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
    _isSpeaking = false;
  }

  Future<void> _startVoiceFlow() async {
    if (_voiceActive) return; // already active
    _voiceStep = VoiceStep.category;
    // Request mic permission proactively
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        showSafeToast("Microphone permission required for voice mode");
        return;
      }
    } catch (_) {}
    _stepAttempts = 0;
    _voiceActive = true;
    if (mounted) setState(() {});
    await _promptStep(explain: true);
  }

  Future<void> _stopVoiceFlow() async {
    _voiceActive = false;
    _voiceTimer?.cancel();
    try { await _speech.stop(); } catch (_) {}
    try { await _tts.stop(); } catch (_) {}
    if (mounted) {
      setState(() {
        _isListening = false;
        _voiceUIHint = '';
        _lastHeard = '';
      });
    }
  }

  Future<void> _startListening() async {
    final available = await _speech.initialize(onStatus: (s) {}, onError: (e) {});
    if (!available) {
      showSafeToast("Speech not available");
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(onResult: (result) {
      final cmd = result.recognizedWords.toLowerCase();
      if (cmd.isEmpty) return;
      setState(() => _lastHeard = cmd);
      _handleVoiceCommand(cmd);
    });
  }

  // Single-utterance listening: start, wait for a final result (or timeout), then stop and process once.
  Future<void> _startListeningSingleUtterance() async {
    if (!_voiceActive) return;
    // Cancel any existing timeout
    _voiceTimer?.cancel();

    final available = await _speech.initialize(onError: (e) async {
      if (!_voiceActive) return;
      if (mounted) setState(() => _isListening = false);
      await _repeatPromptForStep();
    }, onStatus: (status) async {
      // If engine reports stopped and we have no final result, retry prompt
      if (!_voiceActive) return;
      if (status == 'notListening') {
        if (mounted) setState(() => _isListening = false);
        if (_lastHeard.isEmpty) {
          await _sayNotHeardAndRepeat();
        }
      }
    });
    if (!available) {
      showSafeToast("Speech not available");
      return;
    }

    setState(() {
      _isListening = true;
      _lastHeard = '';
    });

    // If no final result in time, re-prompt
    _voiceTimer = Timer(const Duration(seconds: 10), () async {
      if (!_voiceActive) return;
      if (!mounted) return;
      try { await _speech.stop(); } catch (_) {}
      if (mounted) setState(() => _isListening = false);
      await _sayNotHeardAndRepeat();
    });

    await _speech.listen(
      partialResults: true,
      listenFor: const Duration(seconds: 9),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) async {
        // We only handle when a final result arrives
        if (!_voiceActive) return;
        if (!result.finalResult) {
          final partial = result.recognizedWords.toLowerCase();
          if (partial.isNotEmpty && mounted) {
            setState(() => _lastHeard = partial);
          }
          return;
        }
        if (!_voiceActive) return;
        final cmd = result.recognizedWords.toLowerCase();
        _voiceTimer?.cancel();
        if (cmd.isEmpty) {
          try { await _speech.stop(); } catch (_) {}
          if (mounted) setState(() => _isListening = false);
          await _sayNotHeardAndRepeat();
          return;
        }
        if (mounted) setState(() => _lastHeard = cmd);
        try { await _speech.stop(); } catch (_) {}
        if (mounted) setState(() => _isListening = false);
        await _handleVoiceCommand(cmd);
      },
    );
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _handleVoiceCommand(String cmd) async {
    // Global intents
    if (cmd.contains('start over')) {
      _selectedCategory = null;
      _imageFile = null;
      _description = '';
      _locationText = null;
      _voiceStep = VoiceStep.category;
      await _speak("Starting over.");
      _stepAttempts = 0;
      return _promptStep(explain: true);
    }

    switch (_voiceStep) {
      case VoiceStep.category:
        final matched = _matchCategoryFromSpeech(cmd);
        if (matched != null) {
          await _speak("You said ${matched['label']['en']}. Say 'yes' to confirm or say another category.");
          _selectCategory(matched);
          _voiceStep = VoiceStep.confirmCategory;
          _stepAttempts = 0;
          return _promptStep(explain: true);
        } else {
          _stepAttempts += 1;
          await _speak("I didn't catch that.");
          return _promptStep(explain: _stepAttempts == 1);
        }
      case VoiceStep.confirmCategory:
        if (cmd.contains('yes') || cmd.contains('correct')) {
          await _speak("Confirmed.");
          _voiceStep = VoiceStep.photo;
          _stepAttempts = 0;
          return _promptStep(explain: true);
        } else {
          // Try to interpret a replacement category
          final matched = _matchCategoryFromSpeech(cmd);
          if (matched != null) {
            await _speak("Changing to ${matched['label']['en']}. Say 'yes' to confirm.");
            _selectCategory(matched);
            _stepAttempts = 0;
            return _promptStep(explain: true);
          }
          _stepAttempts += 1;
          await _speak("Not clear. Say 'yes' to confirm or say the category again.");
          return _promptStep(explain: false);
        }
      case VoiceStep.photo:
        if (cmd.contains('skip') || cmd.contains('no photo') || cmd.contains('without photo')) {
          await _speak("Okay, skipping photo.");
          _voiceStep = VoiceStep.submit;
          _stepAttempts = 0;
          return _promptStep(explain: true);
        }
        if (cmd.contains('take photo') || cmd.contains('take picture') || cmd.contains('capture')) {
          await _takePhoto();
          await _speak("Photo captured.");
          _voiceStep = VoiceStep.submit;
          _stepAttempts = 0;
          return _promptStep(explain: true);
        } else if (cmd.contains('auto description') || cmd.contains('generate') || cmd.contains('describe')) {
          await _speak("Generating description.");
          await _autoGenerateDescription();
          _voiceStep = VoiceStep.submit;
          _stepAttempts = 0;
          return _promptStep(explain: true);
        } else {
          _stepAttempts += 1;
          await _speak("Say 'take photo' to capture, 'skip' to continue without photo, or 'auto description' to generate.");
          return _promptStep(explain: false);
        }
      case VoiceStep.submit:
        if (cmd.contains('submit')) {
          await _speak("Submitting now.");
          await _submitIssue();
          _voiceStep = VoiceStep.done;
          await _speak("Submitted. Thank you.");
          _voiceActive = false;
          _voiceUIHint = 'Voice flow done';
          if (mounted) setState(() {});
        } else {
          _stepAttempts += 1;
          await _speak("Not clear.");
          return _promptStep(explain: false);
        }
      case VoiceStep.done:
        await _speak("Voice session completed. You can start again with the mic.");
        return;
    }
  }

  Future<void> _repeatPromptForStep() async {
    await _promptStep(explain: false);
  }

  Future<void> _sayNotHeardAndRepeat() async {
    if (!_voiceActive) return;
    _stepAttempts += 1;
    if (_stepAttempts >= 3) {
      await _speak("I didn't catch that. You can try again or use the screen controls.");
      _stepAttempts = 0;
      return;
    }
    await _speak("I didn't catch that.");
    await _promptStep(explain: false);
  }

  Future<void> _promptStep({required bool explain}) async {
    if (!_voiceActive) return;
    String explainText = '';
    String cue = 'You can speak now.';
    switch (_voiceStep) {
      case VoiceStep.category:
        explainText = explain ? 'Please say the type of issue: pothole, garbage, water leak, streetlight, dogs, tree, other.' : 'Say the issue type.';
        _voiceUIHint = 'Waiting: say a category (e.g., pothole)';
        break;
      case VoiceStep.confirmCategory:
        explainText = explain ? "Say 'yes' to confirm or say a different category." : "Say 'yes' to confirm or say category.";
        _voiceUIHint = "Waiting: say 'yes' or a category";
        break;
      case VoiceStep.photo:
        explainText = explain ? "Say 'take photo' to capture, 'skip' to continue without photo, or 'auto description' to generate." : "Say 'take photo', 'skip' or 'auto description'.";
        _voiceUIHint = "Waiting: say 'take photo', 'skip', or 'auto description'";
        break;
      case VoiceStep.submit:
        explainText = explain ? "Say 'submit' to finish or 'start over' to restart." : "Say 'submit' to finish.";
        _voiceUIHint = "Waiting: say 'submit'";
        break;
      case VoiceStep.done:
        _voiceUIHint = 'Voice flow done';
        return;
    }
    if (mounted) setState(() {});
    await _speak(explainText);
    await _speak(cue);
    // Short delay to avoid TTS bleeding into STT
    await Future.delayed(const Duration(milliseconds: 600));
    await _startListeningSingleUtterance();
  }

  Map<String, dynamic>? _matchCategoryFromSpeech(String cmd) {
    Map<String, List<String>> keywords = {
      'pothole': ['pothole', 'road hole'],
      'garbage': ['garbage', 'trash', 'waste', 'litter'],
      'bin': ['bin', 'dustbin', 'broken bin'],
      'streetlight': ['streetlight', 'street light', 'light'],
      'toilet': ['toilet', 'public toilet', 'urinal'],
      'mosquito': ['mosquito', 'dengue', 'mosquito menace'],
      'water': ['water', 'water stagnation', 'leak', 'leakage'],
      'drain': ['drain', 'storm drain', 'sewer'],
      'dogs': ['dog', 'dogs', 'stray dog', 'street dogs'],
      'tree': ['tree', 'fallen tree', 'branch'],
      'other': ['other', 'misc', 'something else'],
    };
    for (final cat in _categories) {
      final id = cat['id'] as String;
      final list = keywords[id] ?? [];
      for (final k in list) {
        if (cmd.contains(k)) return cat;
      }
    }
    return null;
  }

  Future<void> _scrollToDetails() async {
    final ctx = _detailsKey.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  // Prompt user for upvote description (unchanged)
  Future<String?> _askForUpvoteDescription() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Description"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Describe the issue on your own words? (optional)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text("Submit")),
        ],
      ),
    );
  }

  // ----------------------- Location (offline-safe) -----------------------
  Future<void> _getLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        showSafeToast("Location services are disabled.");
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          showSafeToast("Location permission denied.");
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        showSafeToast("Location permission permanently denied.");
        setState(() => _isLoading = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      if (!mounted) return;
      setState(() => _locationText = "${pos.latitude},${pos.longitude}");
      showSafeToast("Location captured.");
    } catch (e) {
      showSafeToast("Failed to get location: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------------- Image picking & preview -----------------------
  Future<void> _pickFromGallery() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile != null && mounted) setState(() => _imageFile = File(pickedFile.path));
    } catch (e) {
      showSafeToast("Image pick failed: $e");
    }
  }

  Future<void> _takePhoto() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile != null && mounted) setState(() => _imageFile = File(pickedFile.path));
    } catch (e) {
      showSafeToast("Camera failed: $e");
    }
  }

  void _removeImage() {
    if (!mounted) return;
    setState(() => _imageFile = null);
    showSafeToast("Image removed");
  }

  Future<void> _editDescription() async {
    final controller = TextEditingController(text: _description);
    final res = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t('home')['desc'] ?? ''),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: _t('home')['descHint'] ?? '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (res != null && mounted) setState(() => _description = res);
  }

  Future<void> _autoGenerateDescription() async {
    if (_selectedCategory == null) {
      showSafeToast("Select an issue first");
      return;
    }
    if (_locationText == null) {
      showSafeToast("Add a location first");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final parts = _locationText!.split(',');
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      final cat = _selectedCategory?['label']['en']?.toString() ?? 'Issue';
      final service = AutoDescriptionService();
      final generated = await service.generate(category: cat, imageFile: _imageFile, lat: lat, lng: lng);
      if (!mounted) return;
      setState(() => _description = generated);
      showSafeToast("Description generated");
    } catch (e) {
      showSafeToast("Auto description failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------------- Upload helpers -----------------------
  Future<String?> _uploadImage(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showSafeToast("User not signed in!");
      return null;
    }

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = ref.putFile(file).timeout(
            const Duration(seconds: 90),
            onTimeout: () {
              throw Exception("Upload timed out. Try again.");
            },
          );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Upload failed: $e");
      return null;
    }
  }

  // ----------------------- Upvote saving (offline-safe, unique per user+issue) -----------------------
  Future<void> _saveUpvote(String issueId, String description) async {
    final user = _auth.currentUser;
    if (user == null) {
      showSafeToast("You must be logged in to upvote");
      return;
    }

    final upvoteDocId = '${issueId}_${user.uid}';
    final upvoteData = {
      "issueId": issueId,
      "userId": user.uid,
      "description": description,
      "createdAt": FieldValue.serverTimestamp(),
    };

    try {
      // Use set on a deterministic doc id to avoid duplicate upvotes from the same user.
      await FirebaseFirestore.instance.collection('upvotes').doc(upvoteDocId).set(upvoteData);
      // Increment issue upvotes (this also queues offline)
      await FirebaseFirestore.instance.collection('issues').doc(issueId).update({"upvotes": FieldValue.increment(1)});

      showSafeToast("Upvote recorded!");
    } catch (e) {
      // If offline, Firestore will still persist local writes if persistence enabled,
      // but we catch general errors and show user-friendly message.
      debugPrint("Upvote save error: $e");
      showSafeToast("Couldn't save upvote right now. It will sync when online.");
    }
  }

  // ----------------------- Existing issue dialog (shows distance and details) -----------------------
  Future<bool> _showExistingIssueDialog(Map<String, dynamic> issueData, double distance) async {
    final distanceText = distance < 1000 ? "${distance.toStringAsFixed(0)} m away" : "${(distance / 1000).toStringAsFixed(2)} km away";
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Issue Already Reported"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Category: ${issueData['category'] ?? '-'}"),
                const SizedBox(height: 6),
                Text("Distance: $distanceText"),
                const SizedBox(height: 6),
                if (issueData['description'] != null && issueData['description'].toString().isNotEmpty)
                  Text("Description: ${issueData['description']}"),
                const SizedBox(height: 6),
                if (issueData['imageUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(issueData['imageUrl'], height: 120, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 6),
                Text("Upvotes: ${issueData['upvotes'] ?? 0}"),
                const SizedBox(height: 12),
                const Text("Do you want to upvote this issue?", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E582D)),
                  child: const Text("Yes, Upvote")),
            ],
          ),
        ) ??
        false;
  }

  void showSafeToast(String? msg) {
    Fluttertoast.showToast(msg: msg != null && msg.isNotEmpty ? msg : "Something went wrong");
  }

  // ----------------------- Submit flow (cache-first detection) -----------------------
  Future<void> _submitIssue() async {
    if (_selectedCategory == null) {
      Fluttertoast.showToast(msg: "Select an issue first");
      return;
    }

    if (_locationText == null) {
      Fluttertoast.showToast(msg: "Add a location");
      return;
    }

    // Image is now optional

    setState(() => _isLoading = true);

    // 1) Upload image (best-effort)
    String? imageUrl;
    try {
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }
    } catch (e) {
      debugPrint("Image upload failed: $e");
      imageUrl = null;
    }

    final user = _auth.currentUser;
    final latLng = _locationText!.split(',');
    final double currentLat = double.tryParse(latLng[0]) ?? 0;
    final double currentLng = double.tryParse(latLng[1]) ?? 0;
    final String currentCategory = _selectedCategory?['label']['en'] ?? 'Other';

    try {
      // 2) Query Firestore cache-first to find near issues in same category
      Query query = FirebaseFirestore.instance
          .collection('issues')
          .where('category', isEqualTo: currentCategory)
          .where('status', isEqualTo: "Pending")
          .orderBy('createdAt', descending: true)
          .limit(50);

      // Try cache first (so offline users use whatever was previously synced)
      QuerySnapshot? cachedSnapshot;
      try {
        cachedSnapshot = await query.get(const GetOptions(source: Source.cache));
      } catch (e) {
        debugPrint("Cache read error (can be okay): $e");
      }
      bool matchedExisting = false;
      Future<void> _checkDocsAndMaybeUpvote(QuerySnapshot snap) async {
        for (var doc in snap.docs) {
final data = doc.data() as Map<String, dynamic>? ?? {};
          final loc = data['location'] as Map<String, dynamic>?;
          if (loc != null) {
            final existingLat = (loc['lat'] as num).toDouble();
            final existingLng = (loc['lng'] as num).toDouble();
            final distance = _calculateDistance(currentLat, currentLng, existingLat, existingLng);
            if (distance <= 100) {
              matchedExisting = true;
              final shouldUpvote = await _showExistingIssueDialog(data, distance);
              if (shouldUpvote) {
                final desc = await _askForUpvoteDescription();
                if (desc != null) {
                  await _saveUpvote(doc.id, desc);
                }
              }
              break;
            }
          }
        }
      }

      // Check cached docs first (offline-friendly)
      if (cachedSnapshot != null && cachedSnapshot.docs.isNotEmpty) {
        await _checkDocsAndMaybeUpvote(cachedSnapshot);
      }

      // If not matched and we are online, check server to be sure
      if (!matchedExisting) {
        try {
          final serverSnap = await query.get(const GetOptions(source: Source.server));
          if (serverSnap.docs.isNotEmpty) {
            await _checkDocsAndMaybeUpvote(serverSnap);
          }
        } catch (e) {
          // server fetch failed (might be offline). That's okay — we'll create new issue locally.
          debugPrint("Server fetch failed or offline: $e");
        }
      }

      // 3) If still not matched, create new issue (this will queue if offline)
      if (!matchedExisting) {
        final issueData = {
          "category": currentCategory,
          "description": _description,
          "priority": "Medium",
          "status": "Pending",
          "createdAt": FieldValue.serverTimestamp(),
          "createdBy": user?.uid ?? 'anonymous',
          "location": {"lat": currentLat, "lng": currentLng},
          "upvotes": 0,
          "imageUrl": imageUrl,
          if (imageUrl == null && _imageFile != null) "localImagePath": _imageFile!.path,
          if (_imageFile != null) "imageUploadPending": imageUrl == null,
          "departmentId": "dept_1757055931512",
        };

        await FirebaseFirestore.instance.collection('issues').add(issueData);

        Fluttertoast.showToast(msg: "Issue submitted (will sync if offline).");
      }

      // reset
      if (mounted) {
        setState(() {
          _selectedCategory = null;
          _imageFile = null;
          _description = '';
          _locationText = null;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to submit issue: $e");
      debugPrint("Submit error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Try to upload any issues having a pending local image path and update Firestore with the URL
  Future<void> _syncPendingImages() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final qs = await FirebaseFirestore.instance
          .collection('issues')
          .where('createdBy', isEqualTo: user.uid)
          .where('imageUploadPending', isEqualTo: true)
          .get(const GetOptions(source: Source.serverAndCache));
      for (final doc in qs.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final localPath = data['localImagePath']?.toString();
        if (localPath == null || localPath.isEmpty) continue;
        final file = File(localPath);
        if (!file.existsSync()) continue;
        final url = await _uploadImage(file);
        if (url != null) {
          await doc.reference.update({
            'imageUrl': url,
            'imageUploadPending': false,
          });
        }
      }
    } catch (e) {
      debugPrint('Pending image sync error: $e');
    }
  }

  // ----------------------- Build UI -----------------------
  @override
  Widget build(BuildContext context) {
    final t = _t('home');
    final themeGreen = const Color(0xFF2E582D);
    final lightBg = const Color(0xFFF1F8E9);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: lightBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: lightBg,
        centerTitle: true,
        title: Text(t['title'] ?? '', style: const TextStyle(color: Color(0xFF1B1B1B), fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.menu, color: Color(0xFF1B1B1B)), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ToggleButtons(
              isSelected: [_lang == AppLang.en, _lang == AppLang.hi],
              onPressed: (i) => setState(() => _lang = i == 0 ? AppLang.en : AppLang.hi),
              borderRadius: BorderRadius.circular(12),
              selectedColor: Colors.white,
              fillColor: themeGreen,
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('EN')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('हिं')),
              ],
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(icon: Icons.list_alt, title: t['gList'] ?? ''),
                const SizedBox(height: 8),
                // Responsive grid: max tile width 120
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      childAspectRatio: 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, i) {
                      final c = _categories[i];
                      final label = c['label'] as Map<String, String>? ?? {};
                      final selected = _selectedCategory?['id'] == c['id'];

                      return GestureDetector(
                        onTap: () => _selectCategory(c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: selected ? themeGreen.withOpacity(0.08) : lightBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? themeGreen : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(c['icon'] as IconData? ?? Icons.help_outline, color: themeGreen, size: 28),
                              const SizedBox(height: 8),
                              Text(label[_lang == AppLang.en ? 'en' : 'hi'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(t['viewAndReport'] ?? '', style: const TextStyle(color: Color(0xFF4E5D4A))),
                const SizedBox(height: 16),
                _ReportDetailsCard(
                  key: _detailsKey,
                  themeGreen: themeGreen,
                  tHome: t,
                  selected: _selectedCategory,
                  locationText: _locationText,
                  imageFile: _imageFile,
                  description: _description,
                  isSubmitEnabled: _selectedCategory != null && _locationText != null && !_isLoading,
                  onUseLocation: _getLocation,
                  onPickGallery: _pickFromGallery,
                  onTakePhoto: _takePhoto,
                  onEditDesc: _editDescription,
                  onAutoDesc: _autoGenerateDescription,
                  onRemoveImage: _removeImage,
                  onSubmit: _isLoading ? () {} : _submitIssue, // additional guarding; main control via isSubmitEnabled
                ),
              ],
            ),
          ),
          // non-blocking loader top-right
          if (_isLoading)
            Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(color: themeGreen),
            ),
          if (_isListening || _voiceUIHint.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 86,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(_isListening ? Icons.hearing : Icons.info, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(_voiceUIHint, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                    if (_lastHeard.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Heard: $_lastHeard', style: const TextStyle(color: Colors.white70)),
                    ]
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _VoiceFab(isListening: _isListening || _voiceActive, onTap: () async {
        if (_voiceActive) {
          await _stopVoiceFlow();
        } else {
          await _startVoiceFlow();
        }
      }),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

/// Section Title widget (unchanged)
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFA5D6A7), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFF2E582D)),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
      ],
    );
  }
}

class _VoiceFab extends StatelessWidget {
  final bool isListening;
  final VoidCallback onTap;
  const _VoiceFab({required this.isListening, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: isListening ? Colors.red : const Color(0xFF2E582D),
      child: Icon(isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
    );
  }
}

/// Report Details Card (mostly same, improved button disable and image preview removable)
class _ReportDetailsCard extends StatelessWidget {
  final Color themeGreen;
  final Map<String, String> tHome;
  final Map<String, dynamic>? selected;
  final String? locationText;
  final File? imageFile;
  final String description;
  final bool isSubmitEnabled;
  final VoidCallback onUseLocation;
  final VoidCallback onPickGallery;
  final VoidCallback onTakePhoto;
  final VoidCallback onEditDesc;
  final VoidCallback onAutoDesc;
  final VoidCallback onRemoveImage;
  final VoidCallback onSubmit;

  const _ReportDetailsCard({
    super.key,
    required this.themeGreen,
    required this.tHome,
    required this.selected,
    required this.locationText,
    required this.imageFile,
    required this.description,
    required this.isSubmitEnabled,
    required this.onUseLocation,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onEditDesc,
    required this.onAutoDesc,
    required this.onRemoveImage,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final labelMap = selected?['label'] as Map<String, String>? ?? {};
    final icon = selected?['icon'] as IconData? ?? Icons.help_outline;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.edit_location_alt, color: themeGreen), const SizedBox(width: 8), Text(tHome['selected'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 8),
          if (selected != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: const Color(0xFFF1F8E9), child: Icon(icon, color: themeGreen)),
              title: Text(labelMap['en'] ?? ''),
              subtitle: Text(labelMap['hi'] ?? ''),
            )
          else
            Text('—', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_pin, color: themeGreen, size: 20),
              const SizedBox(width: 6),
              Expanded(child: Text(locationText ?? '—', style: TextStyle(color: Colors.grey[800]))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ActionChip(label: Text(tHome['location'] ?? ''), onPressed: onUseLocation, avatar: const Icon(Icons.location_on, size: 18)),
              ActionChip(label: Text(tHome['pick'] ?? ''), onPressed: onPickGallery, avatar: const Icon(Icons.photo, size: 18)),
              ActionChip(label: Text(tHome['camera'] ?? ''), onPressed: onTakePhoto, avatar: const Icon(Icons.camera_alt, size: 18)),
              ActionChip(label: Text(tHome['desc'] ?? ''), onPressed: onEditDesc, avatar: const Icon(Icons.note_alt_outlined, size: 18)),
              ActionChip(label: Text(tHome['autoDesc'] ?? 'Auto Description'), onPressed: onAutoDesc, avatar: const Icon(Icons.auto_fix_high, size: 18)),
            ],
          ),
          const SizedBox(height: 12),
          if (imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Promote the nullable imageFile to a local non-null variable for Image.file
                  Builder(builder: (context) {
                    final nonNullImage = imageFile!;
                    return Image.file(nonNullImage, height: 150, width: double.infinity, fit: BoxFit.cover);
                  }),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onRemoveImage,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(tHome['noImage'] ?? ''),
          const SizedBox(height: 12),
          Text(description.isEmpty ? '—' : description),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
                onPressed: isSubmitEnabled ? onSubmit : null,
                style: ElevatedButton.styleFrom(backgroundColor: themeGreen),
                child: Text(tHome['submit'] ?? 'Submit')),
          ),
        ],
      ),
    );
  }
}
