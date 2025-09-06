import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

enum AppLang { en, hi }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _detailsKey = GlobalKey();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  AppLang _lang = AppLang.en;

  Map<String, dynamic>? _selectedCategory;
  File? _imageFile;
  String _description = '';
  String? _locationText;
  bool _isLoading = false;

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
      }
    },
  };

  Map<String, String> _t(String ns) {
    final langMap = _translations[_lang];
    if (langMap == null) return {};
    return langMap[ns] ?? {};
  }

  void _selectCategory(Map<String, dynamic> cat) {
    setState(() => _selectedCategory = cat);
    _scrollToDetails();
  }

  Future<void> _scrollToDetails() async {
    final ctx = _detailsKey.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  Future<void> _getLocation() async {
    // mock location, replace with geolocator
    setState(() => _locationText = "23.821,90.402");
  }

  Future<void> _pickFromGallery() async {
  final pickedFile = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 50, // reduce quality
    maxWidth: 1024,   // resize max width
    maxHeight: 1024,  // resize max height
  );
  if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
}

Future<void> _takePhoto() async {
  final pickedFile = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 50, // reduce quality
    maxWidth: 1024,
    maxHeight: 1024,
  );
  if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
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
    if (res != null) setState(() => _description = res);
  }


Future<String?> _uploadImage(File file) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    showSafeToast("User not signed in!");
    return null;
  }

  try {
    // Reference path in Firebase Storage
    final ref = FirebaseStorage.instance
        .ref()
        .child('uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');

    // Upload with a timeout
    final uploadTask = ref.putFile(file).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception("Upload timed out. Try again.");
          },
        );

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    showSafeToast("Upload successful!");
    return downloadUrl;
  } catch (e) {
    print("Upload failed: $e");
    showSafeToast("Upload failed: ${e.toString()}");
    return null;
  }
}

// Safe toast wrapper
void showSafeToast(String? msg) {
  Fluttertoast.showToast(msg: msg != null && msg.isNotEmpty ? msg : "Something went wrong");
}

Future<void> _submitIssue() async {
  if (_selectedCategory == null) {
    Fluttertoast.showToast(msg: "Select an issue first");
    return;
  }

  if (_locationText == null) {
    Fluttertoast.showToast(msg: "Add a location");
    return;
  }

  if (_imageFile == null) {
    Fluttertoast.showToast(msg: "Attach a photo");
    return;
  }

  setState(() => _isLoading = true);

  final imageUrl = await _uploadImage(_imageFile!);
  if (imageUrl == null) {
    setState(() => _isLoading = false);
    return; // stop if upload failed
  }

  final user = _auth.currentUser;
  final latLng = _locationText!.split(',');

  final issueData = {
    "category": _selectedCategory?['label']['en'] ?? 'Other',
    "description": _description,
    "priority": "Medium", // keep default, no dropdown for user
    "status": "Pending",
    "createdAt": FieldValue.serverTimestamp(),
    "createdBy": user?.uid ?? 'anonymous',
    "location": {
      "lat": double.tryParse(latLng[0]) ?? 0,
      "lng": double.tryParse(latLng[1]) ?? 0,
    },
    "upvotes": 0,
    "imageUrl": imageUrl,
    "departmentId": "dept_1757055931512",
  };

  try {
    await FirebaseFirestore.instance.collection('issues').add(issueData);
    Fluttertoast.showToast(msg: "Issue submitted successfully!");
    setState(() {
      _selectedCategory = null;
      _imageFile = null;
      _description = '';
      _locationText = null;
    });
  } catch (e) {
    Fluttertoast.showToast(msg: "Failed to submit issue: $e");
  } finally {
    setState(() => _isLoading = false);
  }
}


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
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              ListTile(leading: const Icon(Icons.person), title: Text(t['profile'] ?? ''), onTap: () => Navigator.pushNamed(context, '/profile')),
              ListTile(leading: const Icon(Icons.home), title: Text(t['title'] ?? ''), onTap: () => Navigator.pop(context)),
              ListTile(leading: const Icon(Icons.receipt_long), title: Text(t['report'] ?? ''), onTap: () => Navigator.pushNamed(context, '/report')),
              const Spacer(),
              Divider(),
              ListTile(leading: const Icon(Icons.logout), title: Text(t['logout'] ?? ''), onTap: () async => await _auth.signOut()),
              ListTile(leading: const Icon(Icons.delete_forever), title: Text(t['delete'] ?? ''), onTap: () async {
                final user = _auth.currentUser;
                if (user != null) await user.delete();
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, i) {
                      final c = _categories[i];
                      final label = c['label'] as Map<String, String>? ?? {};
                      return GestureDetector(
                        onTap: () => _selectCategory(c),
                        child: Container(
                          decoration: BoxDecoration(
                            color: lightBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedCategory?['id'] == c['id'] ? themeGreen : Colors.transparent,
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
                  onUseLocation: _getLocation,
                  onPickGallery: _pickFromGallery,
                  onTakePhoto: _takePhoto,
                  onEditDesc: _editDescription,
                  onSubmit: _submitIssue,
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            )
        ],
      ),
    );
  }
}

/// Section Title
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

/// Report Details Card
class _ReportDetailsCard extends StatelessWidget {
  final Color themeGreen;
  final Map<String, String> tHome;
  final Map<String, dynamic>? selected;
  final String? locationText;
  final File? imageFile;
  final String description;
  final VoidCallback onUseLocation;
  final VoidCallback onPickGallery;
  final VoidCallback onTakePhoto;
  final VoidCallback onEditDesc;
  final VoidCallback onSubmit;

  const _ReportDetailsCard({
    super.key,
    required this.themeGreen,
    required this.tHome,
    required this.selected,
    required this.locationText,
    required this.imageFile,
    required this.description,
    required this.onUseLocation,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onEditDesc,
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
            ],
          ),
          const SizedBox(height: 12),
          if (imageFile != null) Image.file(imageFile!, height: 150, width: double.infinity, fit: BoxFit.cover) else Text(tHome['noImage'] ?? ''),
          const SizedBox(height: 12),
          Text(description.isEmpty ? '—' : description),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(onPressed: onSubmit, style: ElevatedButton.styleFrom(backgroundColor: themeGreen), child: Text(tHome['submit'] ?? 'Submit')),
          ),
        ],
      ),
    );
  }
}
