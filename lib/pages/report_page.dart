import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/app_botton_nav.dart';

enum AppLang { en, hi }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  AppLang _lang = AppLang.en;
  final themeGreen = const Color(0xFF2E582D);
  final lightBg = const Color(0xFFF1F8E9);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _statusFilterIndex = 0; // 0=All, 1=Pending, 2=Verified , 3=Resolved

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myReportsStream(String uid) {
    // Keep query simple and sort on client to avoid index/order issues
    return FirebaseFirestore.instance
        .collection('issues')
        .where('createdBy', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myUpvotesStream(String uid) {
    // Avoid orderBy to prevent index requirement; sort client-side
    return FirebaseFirestore.instance
        .collection('upvotes')
        .where('userId', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true);
  }

  Future<Map<String, dynamic>?> _fetchIssueById(String issueId) async {
    try {
      // Try cache first
      final cache = await FirebaseFirestore.instance
          .collection('issues')
          .doc(issueId)
          .get(const GetOptions(source: Source.cache));
      if (cache.exists) return cache.data();
    } catch (_) {
      // ignore cache failures
    }
    try {
      // Then server
      final server = await FirebaseFirestore.instance
          .collection('issues')
          .doc(issueId)
          .get(const GetOptions(source: Source.server));
      if (server.exists) return server.data();
    } catch (_) {}
    return null;
  }

  static const List<String> _statusOrder = ['Pending', 'Verified ', 'Resolved'];
  int _statusToStep(String status) {
    final idx = _statusOrder.indexOf(status);
    return idx >= 0 ? idx : 0;
  }
  bool _passesFilter(String status) {
    if (_statusFilterIndex == 0) return true;
    final target = _statusFilterIndex == 1 ? 'Pending' : _statusFilterIndex == 2 ? 'Verified ' : 'Resolved';
    return status == target;
  }
  Map<String, int> _summarize(List<Map<String, dynamic>> issues) {
    final map = {'Pending': 0, 'Verified ': 0, 'Resolved': 0};
    for (final it in issues) {
      final s = (it['status'] ?? 'Pending').toString();
      if (map.containsKey(s)) map[s] = (map[s] ?? 0) + 1;
    }
    return map;
  }
  List<Map<String, dynamic>> _filterAndSort(List<Map<String, dynamic>> issues) {
    final filtered = issues.where((e) => _passesFilter((e['status'] ?? 'Pending').toString())).toList();
    filtered.sort((a, b) => _statusToStep((a['status'] ?? 'Pending').toString()).compareTo(_statusToStep((b['status'] ?? 'Pending').toString())));
    return filtered;
  }
  Widget _buildSummary(Map<String, int> sum) {
    final total = (sum['Pending'] ?? 0) + (sum['Verified '] ?? 0) + (sum['Resolved'] ?? 0);
    Widget chip(String label, int count, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [Text(label), const SizedBox(width: 6), CircleAvatar(radius: 10, backgroundColor: Colors.white, child: Text('$count', style: const TextStyle(fontSize: 12)))]),
    );
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_lang == AppLang.en ? 'Total' : 'कुल'}: $total', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          chip(_lang == AppLang.en ? 'Pending' : 'लंबित', sum['Pending'] ?? 0, const Color(0xFFFFF4CC)),
          chip(_lang == AppLang.en ? 'Verified ' : 'प्रगति में', sum['Verified '] ?? 0, const Color(0xFFDDEBFF)),
          chip(_lang == AppLang.en ? 'Resolved' : 'सुलझा', sum['Resolved'] ?? 0, const Color(0xFFD0F0D2)),
        ])
      ]),
    );
  }
  Widget _buildStatusFilter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ToggleButtons(
          isSelected: [
            _statusFilterIndex == 0,
            _statusFilterIndex == 1,
            _statusFilterIndex == 2,
            _statusFilterIndex == 3,
          ],
          onPressed: (i) => setState(() => _statusFilterIndex = i),
          borderRadius: BorderRadius.circular(20),
          selectedColor: Colors.white,
          fillColor: themeGreen,
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(_lang == AppLang.en ? 'All' : 'सभी')),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(_lang == AppLang.en ? 'Pending' : 'लंबित')),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(_lang == AppLang.en ? 'Verified ' : 'प्रगति में')),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(_lang == AppLang.en ? 'Resolved' : 'सुलझा')),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _lang == AppLang.en ? 'Reports' : 'रिपोर्ट्स';

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: lightBg,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: Color(0xFF1B1B1B))),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1B1B1B)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          ToggleButtons(
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
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              ListTile(leading: const Icon(Icons.person), title: const Text('Profile'), onTap: () => Navigator.pushReplacementNamed(context, '/profile')),
              ListTile(leading: const Icon(Icons.home), title: const Text('Home'), onTap: () => Navigator.pushReplacementNamed(context, '/home')),
              ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Reports'), onTap: () => Navigator.pushReplacementNamed(context, '/report')),
              const Spacer(),
              const Divider(),
              ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: _logout),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
                child: TabBar(
                  indicatorColor: const Color(0xFF2E582D),
                  labelColor: const Color(0xFF2E582D),
                  unselectedLabelColor: const Color(0xFF4E5D4A),
                  tabs: [
                    Tab(text: _lang == AppLang.en ? 'My Reports' : 'मेरी रिपोर्ट्स'),
                    Tab(text: _lang == AppLang.en ? 'My Upvotes' : 'मेरे अपवोट्स'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Builder(
                builder: (context) {
                  final user = _auth.currentUser;
                  if (user == null) {
                    return Center(child: Text(_lang == AppLang.en ? 'Please login to view reports' : 'रिपोर्ट देखने के लिए लॉगिन करें'));
                  }
                  return TabBarView(
                    children: [
                      // My Reports (progress focused)
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _myReportsStream(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final issues = (snapshot.data?.docs ?? []).map((d) => d.data()).toList();
                          if (issues.isEmpty) return Center(child: Text(_lang == AppLang.en ? 'No reports yet' : 'अभी तक कोई रिपोर्ट नहीं'));
                          final sum = _summarize(issues);
                          final filtered = _filterAndSort(issues);
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              _buildSummary(sum),
                              const SizedBox(height: 12),
                              _buildStatusFilter(),
                              const SizedBox(height: 12),
                              for (final data in filtered) _IssueProgressCard(data: data, themeGreen: themeGreen),
                            ],
                          );
                        },
                      ),
                      // My Upvotes (progress focused)
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _myUpvotesStream(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final upvotes = snapshot.data?.docs ?? [];
                          if (upvotes.isEmpty) return Center(child: Text(_lang == AppLang.en ? 'No upvotes yet' : 'अभी तक कोई अपवोट नहीं'));
                          final ids = upvotes.map((d) => d.data()['issueId'] as String?).where((e) => e != null && e.isNotEmpty).cast<String>().toSet().toList();
                          return FutureBuilder<List<Map<String, dynamic>?>>(
                            future: Future.wait(ids.map((id) => _fetchIssueById(id))),
                            builder: (context, snap) {
                              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                              final issues = snap.data!.whereType<Map<String, dynamic>>().toList();
                              if (issues.isEmpty) return Center(child: Text(_lang == AppLang.en ? 'No issues available (offline)' : 'समस्या उपलब्ध नहीं (ऑफ़लाइन)'));
                              final sum = _summarize(issues);
                              final filtered = _filterAndSort(issues);
                              return ListView(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                children: [
                                  _buildSummary(sum),
                                  const SizedBox(height: 12),
                                  _buildStatusFilter(),
                                  const SizedBox(height: 12),
                                  for (final data in filtered) _IssueProgressCard(data: data, themeGreen: themeGreen),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

class _IssueTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color themeGreen;
  const _IssueTile({required this.data, required this.themeGreen});

  @override
  Widget build(BuildContext context) {
    final category = data['category']?.toString() ?? '-';
    final status = data['status']?.toString() ?? 'Pending';
    final upvotes = (data['upvotes'] as num?)?.toInt() ?? 0;
    final description = data['description']?.toString() ?? '';
    final imageUrl = data['imageUrl']?.toString();
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover)
              : Container(width: 56, height: 56, color: const Color(0xFFF1F8E9), child: const Icon(Icons.image_not_supported)),
        ),
        title: Text(category, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (description.isNotEmpty) Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'Resolved' ? const Color(0xFFD0F0D2) : status == 'Verified ' ? const Color(0xFFFFF4CC) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status, style: TextStyle(color: themeGreen, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.thumb_up_alt_outlined, size: 16),
                const SizedBox(width: 4),
                Text(upvotes.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueProgressCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color themeGreen;
  const _IssueProgressCard({required this.data, required this.themeGreen});

  int _statusToStep(String status) {
    const order = ['Pending', 'Verified ', 'Resolved'];
    final idx = order.indexOf(status);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final category = data['category']?.toString() ?? '-';
    final status = data['status']?.toString() ?? 'Pending';
    final description = data['description']?.toString() ?? '';
    final imageUrl = data['imageUrl']?.toString();
    final step = _statusToStep(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover))
          else
            Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image, color: Colors.black45)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(category, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (description.isNotEmpty) Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: step / 2.0, color: themeGreen, backgroundColor: const Color(0xFFE8F5E9)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
          Text('Pending'),
          Text('Verified '),
          Text('Resolved'),
        ]),
      ]),
    );
  }
}
