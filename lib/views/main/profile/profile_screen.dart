import 'package:lifeline/utils/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lifeline/services/auth_service.dart';
import 'package:lifeline/services/locale_controller.dart';
import 'package:lifeline/services/push_service.dart';
import 'package:lifeline/views/auth/change_password.dart';
import 'package:lifeline/views/main/profile/profile_setting_screen.dart';
import 'package:lifeline/views/main/medical_id/medical_id_screen.dart';
import 'package:lifeline/views/main/profile/controller/profile_controller.dart';
import 'package:lifeline/views/main/profile/controller/profile_widgets.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lifeline/services/global_data_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileController _profileController;
  final GlobalDataService _globalDataService = GlobalDataService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    _profileController = ProfileController();
    _profileController.addListener(_onProfileControllerChanged);

    // Listen to global data service for user data updates
    _globalDataService.addListener(_onGlobalDataChanged);

    // Initialize data once
    _initializeData();
  }

  void _onProfileControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeData() async {
    if (_isInitialized) return;

    // Get user data from global service (already loaded)
    _updateUserFromGlobal();

    // If global service doesn't have user data yet, fetch it directly
    if (_globalDataService.currentUser == null) {
      logDebug('ProfileScreen: No global data, fetching directly...');
      await _profileController.fetchUserData();
    }

    _isInitialized = true;
  }

  void _onGlobalDataChanged() {
    if (mounted) {
      _updateUserFromGlobal();
    }
  }

  void _updateUserFromGlobal() {
    if (_globalDataService.currentUser != null) {
      // Only update if the user data is different to prevent infinite loops
      final globalUser = _globalDataService.currentUser!;
      final currentUser = _profileController.currentUser;

      if (currentUser == null ||
          currentUser.name != globalUser.name ||
          currentUser.email != globalUser.email ||
          currentUser.profileImage != globalUser.profileImage) {
        logDebug('ProfileScreen: Updating user data from global service');
        _profileController.setCurrentUser(globalUser);
      }
    }
  }

  @override
  void dispose() {
    _profileController.removeListener(_onProfileControllerChanged);
    _globalDataService.removeListener(_onGlobalDataChanged);
    _profileController.dispose();
    super.dispose();
  }

  Future<void> _updateProfileImage(ImageSource source) async {
    final success = await _profileController.updateProfileImage(source);
    if (success) {
      // Force refresh user data from GlobalDataService to ensure consistency
      await _globalDataService.updateUserData();
      if (mounted) setState(() {}); // Trigger rebuild to show updated image
    }
  }

  @override
  Widget build(BuildContext context) {
    final DynamicColors colors = DynamicColors(false);
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    l.navProfile,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _showProfileImageOptions(context),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.surface,
                          child: _buildProfileImage(),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.surface, width: 2),
                            ),
                            child: Icon(Icons.edit,
                                color: AppColors.textTertiary, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _profileController.currentUser?.name ?? l.unknownUser,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _profileController.currentUser?.email ??
                        'No email available',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.textTertiary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ProfileWidgets.buildStatCard(
                      icon: Icons.cake_outlined,
                      label: l.age,
                      value: _profileController.currentUser?.age ?? 'N/A',
                      colors: colors),
                  ProfileWidgets.buildStatCard(
                      icon: Icons.monitor_heart_outlined,
                      label: l.bmiLabel,
                      value: _profileController.currentUser?.bmi ?? '0.0',
                      isBmi: true,
                      colors: colors,
                      bmiColor: _getBmiColor(double.tryParse(
                              _profileController.currentUser?.bmi ?? '0.0') ??
                          0.0)),
                  ProfileWidgets.buildStatCard(
                      icon: Icons.bloodtype_outlined,
                      label: l.bloodType,
                      value: _profileController.currentUser?.bloodType ?? 'N/A',
                      colors: colors),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.person_outline,
                    title: l.editProfile,
                    subtitle: l.editProfileSubtitle,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ProfileSettingScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                      // Refresh from global service after returning
                      _updateUserFromGlobal();
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.medical_information_outlined,
                    title: l.medicalId,
                    subtitle: l.medicalIdSubtitle,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MedicalIdScreen()),
                    ),
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.language,
                    title: l.language,
                    subtitle: l.languageSubtitle,
                    onTap: () => _showLanguageDialog(context),
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.help_outline,
                    title: l.helpFaqs,
                    subtitle: l.helpFaqsSubtitle,
                    onTap: () {
                      _showFAQDialog(context);
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.lock_outline,
                    title: l.changePassword,
                    subtitle: l.changePasswordSubtitle,
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ChangePasswordScreen(),
                          transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) =>
                              FadeTransition(opacity: animation, child: child),
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.logout,
                    title: l.logout,
                    subtitle: l.logoutSubtitle,
                    onTap: () async {
                      await _profileController.signOut();
                      if (!mounted) return;
                      // Back to the root route: AuthWrapper lives there and
                      // now shows the welcome screen. Replacing the whole
                      // stack with a LoginScreen removed AuthWrapper, which
                      // broke navigation on the next login.
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.delete_forever_outlined,
                    title: l.deleteAccount,
                    subtitle: l.deleteAccountSubtitle,
                    accentColor: AppColors.error,
                    onTap: () => _confirmDeleteAccount(context),
                    colors: colors,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Build profile image with caching
  Widget _buildProfileImage() {
    final imageUrl = _profileController.currentUser?.profileImage ?? '';

    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundColor: AppColors.background,
        child: Icon(Icons.person, color: AppColors.primary, size: 48),
      );
    }

    return CircleAvatar(
      radius: 48,
      backgroundColor: AppColors.background,
      // Cached provider keeps the image in memory + on disk, so revisiting
      // the profile reuses it instead of re-downloading every time.
      backgroundImage: CachedNetworkImageProvider(imageUrl),
      onBackgroundImageError: (exception, stackTrace) {
        logDebug('Error loading profile image: $exception');
      },
      child: null,
    );
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.amber;
    return Colors.red;
  }

  // ─── Delete account ───────────────────────────────────────────────────────
  // Everything past the initial confirmation runs on the ROOT navigator
  // (PushService.navigatorKey): deleting the Firestore user doc makes
  // AuthWrapper swap its child, which unmounts this page mid-flow, so this
  // State's context cannot be used once deletion has started.

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: 0,
        backgroundColor: AppColors.transparent,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever_outlined,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l.deleteAccountConfirmTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.deleteAccountConfirmBody,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                    shadowColor: AppColors.error.withOpacity(0.3),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    l.deleteCaps,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    l.cancel,
                    style: GoogleFonts.poppins(
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _runDeleteAccount();
    }
  }

  Future<void> _runDeleteAccount() async {
    final navigator = PushService.navigatorKey.currentState;
    if (navigator == null) return;
    final authService = AuthService();

    // Email/password users confirm their password before anything is
    // deleted. A correct password also refreshes the session, so the
    // requires-recent-login fallback below only applies to Google users.
    if (!authService.isGoogleUser) {
      final verified =
          await _promptPasswordAndReauth(navigator.context, authService);
      if (!verified) return;
    }

    _showDeletingDialog(navigator.context);
    var result = await authService.deleteAccount();
    navigator.pop(); // close the progress dialog

    // Firebase refuses to delete a stale session: re-authenticate, retry.
    if (!result.isSuccess &&
        result.message == AuthService.requiresRecentLogin) {
      final reauthed = await _reauthenticate(navigator.context, authService);
      if (!reauthed) return;
      _showDeletingDialog(navigator.context);
      result = await authService.deleteAccount();
      navigator.pop();
    }

    final l = AppLocalizations.of(navigator.context);
    final messenger = PushService.messengerKey.currentState;
    if (result.isSuccess) {
      // Auth state is now null, so AuthWrapper shows the welcome screen at
      // the root route; clear everything stacked above it.
      navigator.popUntil((route) => route.isFirst);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l.accountDeleted),
          backgroundColor: AppColors.secondary,
        ),
      );
    } else {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l.deleteAccountFailed),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showDeletingDialog(BuildContext rootContext) {
    final l = AppLocalizations.of(rootContext);
    showDialog(
      context: rootContext,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(width: 20),
              Expanded(child: Text(l.deletingAccount)),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _reauthenticate(
      BuildContext rootContext, AuthService authService) async {
    final l = AppLocalizations.of(rootContext);
    final messenger = PushService.messengerKey.currentState;

    if (authService.isGoogleUser) {
      final proceed = await showDialog<bool>(
        context: rootContext,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l.deleteAccountReauthTitle),
          content: Text(l.deleteAccountReauthGoogleBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                l.cancel,
                style: GoogleFonts.poppins(color: AppColors.textGrey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                l.continueWithGoogle,
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (proceed != true) return false;

      final result = await authService.reauthenticateWithGoogle();
      if (!result.isSuccess) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(l.deleteAccountFailed),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return result.isSuccess;
    }

    return _promptPasswordAndReauth(rootContext, authService);
  }

  /// Asks for the account password and verifies it via re-authentication.
  /// A wrong password shows an inline error and lets the user retry; the
  /// dialog only closes on success or cancel. Returns true when verified.
  Future<bool> _promptPasswordAndReauth(
      BuildContext rootContext, AuthService authService) async {
    final l = AppLocalizations.of(rootContext);
    final passwordController = TextEditingController();

    final verified = await showDialog<bool>(
      context: rootContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? errorText;
        bool checking = false;
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              if (checking) return;
              final password = passwordController.text.trim();
              if (password.isEmpty) return;
              setState(() {
                checking = true;
                errorText = null;
              });
              final result =
                  await authService.reauthenticateWithPassword(password);
              if (result.isSuccess) {
                Navigator.pop(dialogContext, true);
                return;
              }
              setState(() {
                checking = false;
                errorText = result.message == AuthService.wrongPasswordCode
                    ? l.wrongPassword
                    : l.deleteAccountFailed;
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              elevation: 0,
              backgroundColor: AppColors.transparent,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        color: AppColors.error,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l.deleteAccountReauthTitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.deleteAccountReauthBody,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      autofocus: true,
                      enabled: !checking,
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: l.password,
                        labelStyle:
                            GoogleFonts.poppins(color: AppColors.textGrey),
                        errorText: errorText,
                        errorStyle:
                            GoogleFonts.poppins(color: AppColors.error),
                        prefixIcon:
                            Icon(Icons.key, color: AppColors.textGrey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 2,
                          shadowColor: AppColors.error.withOpacity(0.3),
                        ),
                        onPressed: checking ? null : submit,
                        child: checking
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                l.deleteCaps,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: checking
                            ? null
                            : () => Navigator.pop(dialogContext, false),
                        child: Text(
                          l.cancel,
                          style: GoogleFonts.poppins(
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    passwordController.dispose();
    return verified == true;
  }

  void _showProfileImageOptions(BuildContext context) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.updateProfilePicture,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ProfileWidgets.buildImageOption(
                icon: Icons.camera_alt,
                color: AppColors.primary,
                label: l.takePhoto,
                onTap: () {
                  Navigator.pop(context);
                  _updateProfileImage(ImageSource.camera);
                },
              ),
              ProfileWidgets.buildImageOption(
                icon: Icons.photo_library,
                color: AppColors.primary,
                label: l.chooseFromGallery,
                onTap: () {
                  Navigator.pop(context);
                  _updateProfileImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l.cancel,
                  style: GoogleFonts.poppins(
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final controller = context.read<LocaleController>();
    final l = AppLocalizations.of(context);
    final current = controller.locale.languageCode;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'en',
              groupValue: current,
              title: Text(l.english),
              activeColor: AppColors.primary,
              onChanged: (v) {
                controller.setLocale(const Locale('en'));
                Navigator.pop(dialogContext);
              },
            ),
            RadioListTile<String>(
              value: 'ur',
              groupValue: current,
              title: Text(l.urdu),
              activeColor: AppColors.primary,
              onChanged: (v) {
                controller.setLocale(const Locale('ur'));
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFAQDialog(BuildContext context) {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 0,
        backgroundColor: AppColors.transparent,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.aboutLifeline,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                l.aboutLifelineBody,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ProfileWidgets.buildTeamInfo(
                name: 'Jawad Mansoor',
                role: l.leadDeveloper,
                developedByLabel: l.developedBy,
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l.versionLabel('1.0.0'),
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l.close,
                  style: GoogleFonts.poppins(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
