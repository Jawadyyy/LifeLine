import 'package:lifeline/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lifeline/services/auth_result.dart';
import 'package:lifeline/services/call_service.dart';
import 'package:lifeline/services/chat_service.dart';
import 'package:lifeline/services/presence_service.dart';
import 'package:lifeline/services/push_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get currentUser => _auth.currentUser;

  Future<AuthResult<User>> signup({
    required String email,
    required String password,
    required String username,
    required String phone,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'username': username,
          'email': email,
          'phone': phone,
          'isProfileComplete': false,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      return AuthResult.success(user, 'Signup successful');
    } on FirebaseAuthException catch (e) {
      String message = 'Signup failed';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists with that email.';
      }
      return AuthResult.failure(message);
    } catch (e) {
      return AuthResult.failure('An error occurred. Please try again.');
    }
  }

  Future<AuthResult<User>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return AuthResult.success(credential.user, 'Login successful');
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid credentials. Please check your email and password.';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error. Check your connection and try again.';
      }
      return AuthResult.failure(message);
    } catch (e) {
      return AuthResult.failure('An error occurred. Please try again.');
    }
  }

  String getCurrentUserId() {
    final User? user = _auth.currentUser;
    if (user != null) {
      return user.uid;
    } else {
      throw Exception("No user is currently logged in.");
    }
  }

  Future<AuthResult<User>> signInWithGoogle() async {
    try {
      logDebug('🔍 Starting Google Sign-In...');

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      logDebug('✅ Google User: ${googleUser != null ? "received" : "null"}');

      if (googleUser == null) {
        logDebug('❌ User cancelled sign-in');
        return AuthResult.failure('Sign-in cancelled');
      }

      logDebug('🔑 Getting authentication...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      logDebug(
          '🎫 Access Token: ${googleAuth.accessToken != null ? "✅ Present" : "❌ Missing"}');
      logDebug(
          '🎫 ID Token: ${googleAuth.idToken != null ? "✅ Present" : "❌ Missing"}');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      logDebug('🔐 Signing in with credential...');
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      User? user = userCredential.user;
      logDebug('👤 User: ${user != null ? "signed in" : "No user"}');

      if (user != null) {
        logDebug('💾 Checking/Creating Firestore document...');
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        // The doc may already exist with only presence/push fields: the
        // auth-state listener starts PresenceService/PushService the moment
        // signInWithCredential completes, and their merge-writes can land
        // before this check. So key off the username field, not doc.exists,
        // or a new Google user ends up with no username ("Loading..." in UI).
        final existingData = doc.data();
        final existingUsername =
            (existingData?['username'] as String?)?.trim();

        if (!doc.exists) {
          logDebug('📝 Creating new user document');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'username': user.displayName ?? 'No name',
            'email': user.email,
            'phone': '',
            'profileImageUrl': user.photoURL ?? '',
            'created_at': FieldValue.serverTimestamp(),
            'isProfileComplete': false,
          }, SetOptions(merge: true));
        } else {
          // Repair docs created by the old race (or corrupted by the
          // profile-setup fallback persisting placeholders): backfill a
          // missing username and/or profile picture from the Google account.
          final patch = <String, dynamic>{};
          if (existingUsername == null ||
              existingUsername.isEmpty ||
              existingUsername == 'Loading...') {
            patch['username'] = user.displayName ?? 'No name';
            patch['email'] = existingData?['email'] ?? user.email;
          }
          final existingImage =
              (existingData?['profileImageUrl'] as String?) ?? '';
          final hasRealImage = existingImage.isNotEmpty &&
              !existingImage.contains('via.placeholder.com');
          if (!hasRealImage && (user.photoURL ?? '').isNotEmpty) {
            patch['profileImageUrl'] = user.photoURL;
          }
          if (patch.isNotEmpty) {
            logDebug('🩹 Backfilling ${patch.keys} on existing document');
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set(patch, SetOptions(merge: true));
          } else {
            logDebug('✅ User document already exists');
          }
        }
      }

      logDebug('🎉 Google Sign-In successful!');
      return AuthResult.success(user, 'Login successful');
    } catch (e) {
      logDebug('💥 Google Sign-In Error: $e');
      logDebug('💥 Error Type: ${e.runtimeType}');
      return AuthResult.failure('Google sign-in failed: ${e.toString()}');
    }
  }

  /// Sentinel message returned by [deleteAccount] when Firebase requires a
  /// recent sign-in before the auth user can be deleted. The caller should
  /// re-authenticate ([reauthenticateWithPassword] / [reauthenticateWithGoogle])
  /// and call [deleteAccount] again.
  static const String requiresRecentLogin = 'requires-recent-login';

  /// Sentinel message returned by [reauthenticateWithPassword] when the
  /// entered password is wrong (as opposed to a network/other failure).
  static const String wrongPasswordCode = 'wrong-password';

  /// Whether the current user signed in with Google (drives which
  /// re-authentication flow to offer before account deletion).
  bool get isGoogleUser =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  /// Permanently deletes the signed-in user's account: their Firestore data
  /// (contacts, donation posts, live-location sessions, user doc) and the
  /// Firebase Auth user. Chat messages are intentionally kept, and Supabase
  /// media is left in place — both documented on the delete-account page.
  ///
  /// Safe to call again after a [requiresRecentLogin] failure: the service
  /// shutdown and data purge are idempotent.
  Future<AuthResult<void>> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return AuthResult.failure('No user is currently logged in.');
    }
    final uid = user.uid;

    try {
      // Stop services BEFORE deleting the user doc, mirroring signOut():
      // presence/push merge-writes would otherwise recreate it.
      await PushService().clearForUser(uid);
      await PresenceService.instance.stop();
      ChatProviderCache.instance.clear();
      CallService.instance.stopListening();
      await CallService.instance.releaseEngine();

      await _purgeUserData(uid);

      await user.delete();
      await _googleSignIn.signOut();
      logDebug('✅ Account deleted for $uid');
      return AuthResult.success(null, 'Account deleted');
    } on FirebaseAuthException catch (e) {
      logDebug('Account deletion auth error: ${e.code}');
      if (e.code == 'requires-recent-login') {
        return AuthResult.failure(requiresRecentLogin);
      }
      return AuthResult.failure('Failed to delete account.');
    } catch (e) {
      logDebug('Account deletion error: $e');
      return AuthResult.failure('Failed to delete account.');
    }
  }

  /// Deletes the Firestore documents owned by [uid]. Subcollections are not
  /// removed by deleting the parent doc, so contacts and donation posts are
  /// deleted explicitly before the user doc itself.
  Future<void> _purgeUserData(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);

    final contacts = await userRef.collection('contacts').get();
    for (final doc in contacts.docs) {
      await doc.reference.delete();
    }

    final posts = await userRef.collection('donation_posts').get();
    for (final doc in posts.docs) {
      await doc.reference.delete();
    }

    final sessions = await _firestore
        .collection('live_locations')
        .where('ownerUid', isEqualTo: uid)
        .get();
    for (final doc in sessions.docs) {
      await doc.reference.delete();
    }

    await userRef.delete();
  }

  /// Re-authenticates an email/password user (needed before account deletion
  /// when the session is too old).
  Future<AuthResult<void>> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      return AuthResult.failure('No user is currently logged in.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return AuthResult.failure(wrongPasswordCode);
      }
      return AuthResult.failure('Re-authentication failed.');
    } catch (e) {
      return AuthResult.failure('Re-authentication failed.');
    }
  }

  /// Re-authenticates a Google user via a fresh Google sign-in.
  Future<AuthResult<void>> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      return AuthResult.failure('No user is currently logged in.');
    }
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure('Sign-in cancelled');
      }
      final googleAuth = await googleUser.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
      return AuthResult.success();
    } catch (e) {
      logDebug('Google re-authentication error: $e');
      return AuthResult.failure('Re-authentication failed.');
    }
  }

  Future<void> signOut() async {
    try {
      logDebug('🚪 Signing out...');
      // Drop this device's push token before we lose the uid (best-effort).
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await PushService().clearForUser(uid);
      }
      // Mark offline while the uid is still available (the auth-state listener
      // fires after sign-out, when there's no uid left to write).
      await PresenceService.instance.stop();
      // Drop cached chat streams so the next user starts clean.
      ChatProviderCache.instance.clear();
      CallService.instance.stopListening();
      await CallService.instance.releaseEngine();
      await _auth.signOut();
      await _googleSignIn.signOut();
      logDebug('✅ Sign out complete');
    } catch (e) {
      logDebug('Error during sign out: $e');
    }
  }
}
