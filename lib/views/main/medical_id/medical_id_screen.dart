import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/models/user_model.dart';
import 'package:lifeline/views/main/medical_id/widgets/medical_id_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fast-access medical summary. Streams the user's profile so it stays current,
/// and loads the primary (oldest) emergency contact alongside.
class MedicalIdScreen extends StatefulWidget {
  const MedicalIdScreen({super.key});

  @override
  State<MedicalIdScreen> createState() => _MedicalIdScreenState();
}

class _MedicalIdScreenState extends State<MedicalIdScreen> {
  late final Future<Map<String, String>?> _primaryContact = _loadPrimary();

  Future<Map<String, String>?> _loadPrimary() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Medical ID',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: uid == null
          ? const Center(child: Text('You are not signed in.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data?.data() ?? <String, dynamic>{};
                final user = UserModel.fromMap(data);

                return FutureBuilder<Map<String, String>?>(
                  future: _primaryContact,
                  builder: (context, contactSnap) {
                    final contact = contactSnap.data;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: MedicalIdCard(
                        user: user,
                        primaryContactName: contact?['name'],
                        primaryContactPhone: contact?['phone'],
                        onCallContact: contact?['phone'] == null
                            ? null
                            : () => _call(contact!['phone']!),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
