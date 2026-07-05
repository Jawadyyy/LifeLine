import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/constants/app_design.dart';
import 'package:lifeline/views/main/contact/controller/contacts_screen_controller.dart';
import 'package:lifeline/views/main/contact/chat/chat_screen.dart';
import 'package:lifeline/services/global_data_service.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage>
    implements ContactsScreenView {
  @override
  List<Map<String, dynamic>> contacts = [];
  List<Map<String, dynamic>> filteredContacts = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  ContactsScreenController? controller;
  final GlobalDataService _globalDataService = GlobalDataService();

  @override
  void initState() {
    super.initState();
    controller = ContactsScreenController(this, setState);

    _globalDataService.addListener(_onGlobalDataChanged);

    // Load directly from Firestore to guarantee profileImageUrl is included
    _loadContacts();
    // Loads once and caches; drives the header avatar.
    _globalDataService.loadUserData();
  }

  String get _profileImage =>
      _globalDataService.currentUser?.profileImage ?? '';

  String get _initial {
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim() ??
        _globalDataService.currentUser?.name.trim() ??
        '';
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  void _onGlobalDataChanged() {
    if (mounted) {
      // When global service notifies, reload from Firestore directly
      _loadContacts();
    }
  }

  /// Populates the list from [GlobalDataService]'s cache, which holds the full
  /// contact docs (including profileImageUrl). The cache survives tab switches,
  /// so a return visit shows data instantly instead of re-fetching with a
  /// spinner. Only when nothing is cached yet do we wait on a load.
  Future<void> _loadContacts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_globalDataService.hasLoadedContacts) {
      _applyContacts(_globalDataService.contacts);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _globalDataService.loadContactsData();
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    }
    if (!mounted) return;
    _applyContacts(_globalDataService.contacts);
  }

  /// Sorts newest-first (oldest = primary, shown last) and pushes to the UI.
  void _applyContacts(List<Map<String, dynamic>> list) {
    final sorted = [...list]
      ..sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
        return 0;
      });
    if (!mounted) return;
    setState(() {
      contacts = sorted;
      filteredContacts = sorted;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _globalDataService.removeListener(_onGlobalDataChanged);
    super.dispose();
  }

  // ─── ContactsScreenView (typed contract for the controller) ─────────────────
  @override
  set isLoading(bool value) => _isLoading = value;

  void _navigateToChat(Map<String, dynamic> contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          contactName: contact['name'] as String,
          contactPhone: contact['phone'] as String,
          contactImageUrl: contact['profileImageUrl'] as String?,
          contactId: contact['id'] as String,
          contactUid: contact['uid'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _searchController.text.isNotEmpty;
    return Scaffold(
      backgroundColor: LL.canvas,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await controller?.showContactsDialog();
          // Reload after dialog closes in case a contact was added
          _loadContacts();
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LL.grad,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: LL.orange.withOpacity(0.4),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 26),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildSearch(),
            if (_isLoading)
              LinearProgressIndicator(
                minHeight: 2,
                color: LL.orange,
                backgroundColor: LL.orange.withOpacity(0.1),
              )
            else
              const SizedBox(height: 2),
            _buildSectionLabel(),
            Expanded(
              child: filteredContacts.isEmpty
                  ? (_isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: LL.orange))
                      : _buildEmptyState())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                      itemCount: filteredContacts.length + 1,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == filteredContacts.length) {
                          return _AddContactTile(onTap: () async {
                            await controller?.showContactsDialog();
                            _loadContacts();
                          });
                        }
                        final contact = filteredContacts[index];
                        return Dismissible(
                          key: Key(contact['id']),
                          background: Container(
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: Icon(Icons.delete, color: AppColors.error),
                          ),
                          confirmDismiss: (direction) async {
                            if (controller == null) return false;
                            final deleted = await controller!.showDeleteDialog(
                                contact['id'], contact['name']);
                            if (deleted) _loadContacts();
                            return deleted;
                          },
                          child: controller?.buildContactCard(
                                contact,
                                onTap: () => _navigateToChat(contact),
                                isPrimary: !searching &&
                                    index == filteredContacts.length - 1,
                              ) ??
                              ListTile(
                                title: Text(contact['name'] ?? ''),
                                subtitle: Text(contact['phone'] ?? ''),
                              ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final count = filteredContacts.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 14, 26, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("People we'll alert in an emergency",
                    style: LL.body(13, weight: FontWeight.w600, color: LL.muted)),
                const SizedBox(height: 5),
                Text('Emergency Circle', style: LL.display(28)),
                if (count > 0) const SizedBox(height: 2),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _avatar(),
        ],
      ),
    );
  }

  Widget _avatar() {
    final url = _profileImage;
    final fallback = Text(_initial,
        style: LL.display(15, weight: FontWeight.w800, color: Colors.white));
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
          color: LL.orange, shape: BoxShape.circle),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: LL.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LL.border),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (q) {
            controller?.filterContacts(q);
            setState(() {});
          },
          style: LL.body(15, color: LL.ink),
          decoration: InputDecoration(
            hintText: 'Search contacts…',
            hintStyle: LL.body(15, color: LL.faint),
            prefixIcon: const Icon(Icons.search, color: LL.orange),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel() {
    final count = filteredContacts.length;
    if (count == 0) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('YOUR CONTACTS',
              style: LL.body(12,
                  weight: FontWeight.w800, color: LL.faint, letterSpacing: 1.2)),
          Text('$count ${count == 1 ? 'person' : 'people'}',
              style: LL.body(12, weight: FontWeight.w700, color: LL.orange)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
                color: LL.soft, shape: BoxShape.circle),
            child: const Icon(Icons.group_outlined, size: 36, color: LL.orange),
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No emergency contacts yet'
                : 'No matching contacts',
            style: LL.body(15, weight: FontWeight.w600, color: LL.muted),
          ),
          if (_searchController.text.isEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _AddContactTile(onTap: () async {
                await controller?.showContactsDialog();
                _loadContacts();
              }),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dashed-bordered call-to-action for adding a new emergency contact.
class _AddContactTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddContactTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: const Color(0xFFE0C9BF),
          radius: 20,
          dash: 6,
          gap: 5,
          strokeWidth: 1.5,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LL.card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                    color: LL.softTint, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: LL.orangeText, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add emergency contact',
                        style: LL.body(15.5, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Alerted the moment you trigger SOS',
                        style: LL.body(13, color: LL.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle outline.
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(
          metric.extractPath(dist, dist + dash),
          paint,
        );
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color;
}
