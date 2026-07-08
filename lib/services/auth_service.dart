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
            'created_at': FieldValue.serverTimestamp(),
            'isProfileComplete': false,
          }, SetOptions(merge: true));
        } else if (existingUsername == null ||
            existingUsername.isEmpty ||
            existingUsername == 'Loading...') {
          // Repair docs created by the old race (or corrupted by the
          // profile-setup fallback persisting the 'Loading...' placeholder).
          logDebug('🩹 Backfilling missing username on existing document');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'username': user.displayName ?? 'No name',
            'email': existingData?['email'] ?? user.email,
          }, SetOptions(merge: true));
        } else {
          logDebug('✅ User document already exists');
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
