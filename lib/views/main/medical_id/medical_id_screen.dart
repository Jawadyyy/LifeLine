import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/constants/app_design.dart';
import 'package:lifeline/models/user_model.dart';
import 'package:lifeline/views/main/medical_id/widgets/medical_id_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fast-access medical summary. Streams the user's profile so it stays current,
/// and loads the primary (oldest) emergency contact alongside.
class MedicalIdScreen extends StatefulWidget {
  /// When null, shows the signed-in user's own Medical ID. Pass another user's
  /// uid (e.g. an emergency contact) to view theirs read-only.
  final String? uid;
  final String? title;

  const MedicalIdScreen({super.key, this.uid, this.title});

  @override
  State<MedicalIdScreen> createState() => _MedicalIdScreenState();
}

class _MedicalIdScreenState extends State<MedicalIdScreen> {
  late final Future<Map<String, String>?> _primaryContact = _loadPrimary();

  String? get _uid => widget.uid ?? FirebaseAuth.instance.currentUser?.uid;

  Future<Map<String, String>?> _loadPrimary() async {
    // Only load the viewer's own primary contact; another user's contacts
    // subcollection is owner-only (would be permission-denied).
    if (widget.uid != null) return null;
    final uid = _uid;
    if (uid == null) return null;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .orderBy('createdAt')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    return {
      'name': (data['name'] as String?) ?? '',
      'phone': (data['phone'] as String?) ?? '',
    };
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: LL.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Expanded(
              child: uid == null
                  ? Center(
                      child: Text('You are not signed in.',
                          style: LL.body(14, color: LL.muted)))
                  : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: LL.orange));
                        }
                        final data =
                            snapshot.data?.data() ?? <String, dynamic>{};
                        final user = UserModel.fromMap(data);

                        return FutureBuilder<Map<String, String>?>(
                          future: _primaryContact,
                          builder: (context, contactSnap) {
                            final contact = contactSnap.data;
                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                              child: Column(
                                children: [
                                  MedicalIdCard(
                                    user: user,
                                    primaryContactName: contact?['name'],
                                    primaryContactPhone: contact?['phone'],
                                    onCallContact: contact?['phone'] == null
                                        ? null
                                        : () => _call(contact!['phone']!),
                                  ),
                                  const SizedBox(height: 18),
                                  if (widget.uid == null)
                                    Text(
                                      'Show this screen to first responders.\n'
                                      'Accessible from the lock screen.',
                                      textAlign: TextAlign.center,
                                      style: LL.body(12.5,
                                          color: LL.muted, height: 1.5),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 24, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: LL.ink, size: 20),
          ),
          const SizedBox(width: 6),
          Text(widget.title ?? 'Medical ID',
              style: LL.display(22, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
