import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../core/models/screening_model.dart';
import '../../../core/services/mock_data.dart';
import '../../onboarding/screens/onboarding_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Rommel Jose';
  String _email = 'john.doe@email.com';
  Uint8List? _avatarBytes;

  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        setState(() => _avatarBytes = bytes);
      }
    } catch (_) {
      if (mounted) _showSnack(context, 'Could not access photos');
    }
  }

  // ── helpers ────────────────────────────────────────────────────

  /// Generic labelled info row used inside sheets.
  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
      );

  /// Standard bottom-sheet scaffold with title + body.
  void _showSheet(
    BuildContext context, {
    required String title,
    required Widget body,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── avatar / photo ─────────────────────────────────────────────

  void _showAvatarSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Profile Photo',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how to update your profile picture.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            _SheetActionTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take a photo',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
            _SheetActionTile(
              icon: Icons.photo_library_outlined,
              label: 'Choose from library',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
            _SheetActionTile(
              icon: Icons.delete_outline,
              label: 'Remove photo',
              destructive: true,
              onTap: () {
                Navigator.pop(context);
                setState(() => _avatarBytes = null);
                _showSnack(context, 'Photo removed');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── edit name ──────────────────────────────────────────────────

  void _showEditNameSheet(BuildContext context) {
    final nameCtrl = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Edit Profile',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 20),
              _LabeledField(label: 'Full Name', controller: nameCtrl),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Email',
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _PrimaryBtn(
                  label: 'Save Changes',
                  onTap: () {
                    setState(() {
                      _name = nameCtrl.text.trim().isEmpty
                          ? _name
                          : nameCtrl.text.trim();
                      _email = emailCtrl.text.trim().isEmpty
                          ? _email
                          : emailCtrl.text.trim();
                    });
                    Navigator.pop(context);
                    _showSnack(context, 'Profile updated');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Personal Information ───────────────────────────────────────

  void _showPersonalInfo(BuildContext context) {
    _showSheet(
      context,
      title: 'Personal Information',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Full Name', _name),
          const Divider(color: AppColors.border),
          _infoRow('Email', _email),
          const Divider(color: AppColors.border),
          _infoRow('Date of Birth', 'Jan 15, 1990'),
          const Divider(color: AppColors.border),
          _infoRow('Phone', '+63 912 345 6789'),
          const Divider(color: AppColors.border),
          _infoRow('Gender', 'Male'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _PrimaryBtn(
              label: 'Edit Information',
              onTap: () {
                Navigator.pop(context);
                _showEditNameSheet(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Privacy & Consent ──────────────────────────────────────────

  void _showPrivacyConsent(BuildContext context) {
    _showSheet(
      context,
      title: 'Privacy & Consent',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your data preferences',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          _ConsentToggle(
            label: 'Analytics & Diagnostics',
            subtitle: 'Help improve DENTRA with anonymous usage data.',
            initialValue: true,
          ),
          const SizedBox(height: 10),
          _ConsentToggle(
            label: 'Marketing Communications',
            subtitle: 'Receive tips, offers, and updates via email.',
            initialValue: false,
          ),
          const SizedBox(height: 10),
          _ConsentToggle(
            label: 'Location Access',
            subtitle: 'Used for finding nearby clinics.',
            initialValue: true,
          ),
          const SizedBox(height: 10),
          _ConsentToggle(
            label: 'Camera Access',
            subtitle: 'Required for dental screenings.',
            initialValue: true,
          ),
        ],
      ),
    );
  }

  // ── Privacy Policy ─────────────────────────────────────────────

  void _showPrivacyPolicy(BuildContext context) {
    _showSheet(
      context,
      title: 'Privacy Policy',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last updated: September 13, 2026',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          ..._policySection('1. Information We Collect',
              'We collect information you provide directly to us, including name, email address, date of birth, and dental screening images. We also collect device information and usage data to improve our services.'),
          ..._policySection('2. How We Use Your Information',
              'Your information is used to provide and improve the DENTRA service, personalise your experience, send you relevant notifications, and connect you with nearby dental clinics.'),
          ..._policySection('3. Data Sharing',
              'We do not sell your personal data. Information may be shared with dental professionals you choose to connect with, or as required by law.'),
          ..._policySection('4. Data Retention',
              'Your data is retained for as long as your account is active. You may request deletion at any time through the Screening Data section.'),
          ..._policySection('5. Security',
              'We use industry-standard encryption and security practices to protect your data both in transit and at rest.'),
          ..._policySection('6. Contact Us',
              'For privacy-related questions, contact us at privacy@dentra.health'),
        ],
      ),
    );
  }

  List<Widget> _policySection(String heading, String body) => [
        Text(
          heading,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.secondaryText,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
      ];

  // ── View All Screenings ────────────────────────────────────────

  void _showAllScreenings(BuildContext context, {BuildContext? rootContext}) {
    final screenings = MockData.screenings;
    _showSheet(
      context,
      title: 'All Screenings',
      body: Column(
        children: List.generate(screenings.length, (i) {
          final s = screenings[i];
          return Column(
            children: [
              if (i > 0) const Divider(color: AppColors.border),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final ctx = rootContext ?? context;
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 300), () {
                      _showScreeningDetail(ctx, s);
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.lightLavender,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.document_scanner_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.fullDate,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy,
                                ),
                              ),
                              Text(
                                s.region,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.secondaryText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Screening Detail ───────────────────────────────────────────

  void _showScreeningDetail(BuildContext context, ScreeningModel s) {
    _showSheet(
      context,
      title: 'Screening Report',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.fullDate,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.weekday} · ${s.region}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.photo_library_outlined,
                  value: '${s.images}',
                  label: 'Images',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.grid_view_rounded,
                  value: '${s.teeth}',
                  label: 'Teeth Scanned',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Details section
          Text(
            'DETAILS',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _DetailRow(label: 'Region', value: s.region),
                const Divider(height: 1, indent: 16, color: AppColors.border),
                _DetailRow(label: 'Date', value: s.fullDate),
                const Divider(height: 1, indent: 16, color: AppColors.border),
                _DetailRow(label: 'Day', value: s.weekday),
                const Divider(height: 1, indent: 16, color: AppColors.border),
                _DetailRow(label: 'Images Captured', value: '${s.images} photos'),
                const Divider(height: 1, indent: 16, color: AppColors.border),
                _DetailRow(label: 'Teeth Analysed', value: '${s.teeth} teeth'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Observations section
          Text(
            'OBSERVATIONS',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          _ObservationTile(
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF4CAF50),
            label: 'No cavities detected',
            subtitle: 'All scanned surfaces appear healthy.',
          ),
          const SizedBox(height: 8),
          _ObservationTile(
            icon: Icons.info_outline_rounded,
            color: const Color(0xFFFFC107),
            label: 'Mild plaque in ${s.region}',
            subtitle: 'Consider extra brushing in this area.',
          ),
          const SizedBox(height: 8),
          _ObservationTile(
            icon: Icons.info_outline_rounded,
            color: const Color(0xFFFFC107),
            label: 'Gum line slightly receded',
            subtitle: 'Monitor and consult a dentist if worsening.',
          ),
          const SizedBox(height: 20),
          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightLavender,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These observations are AI-generated and for informational purposes only. Always consult a licensed dentist.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.primary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _PrimaryBtn(
              label: 'Share Report',
              onTap: () => _showSnack(context, 'Sharing coming soon'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showSnack(context, 'Download coming soon'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Download PDF',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Delete Account ─────────────────────────────────────────────

  void _showDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Account',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        content: Text(
          'This will permanently delete your account and all associated screening data. This action cannot be undone.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.secondaryText,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnack(context, 'Deletion request submitted');
            },
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                color: const Color(0xFFE05252),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Security state ─────────────────────────────────────────────
  bool _biometricEnabled = false;
  bool _twoFactorEnabled = false;

  // ── Security Settings hub ──────────────────────────────────────

  void _showSecuritySettings(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, sc) => StatefulBuilder(
          builder: (context, setLocal) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text('Security Settings',
                    style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    )),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: SingleChildScrollView(
                    controller: sc,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Biometric ──────────────────────────
                        _SecurityToggle(
                          icon: Icons.fingerprint_rounded,
                          label: 'Biometric Login',
                          subtitle: 'Use Face ID or fingerprint to sign in.',
                          value: _biometricEnabled,
                          onChanged: (v) {
                            setLocal(() => _biometricEnabled = v);
                            setState(() => _biometricEnabled = v);
                            _showSnack(ctx, v
                              ? 'Biometric login enabled'
                              : 'Biometric login disabled');
                          },
                        ),
                        const SizedBox(height: 12),
                        // ── 2FA ────────────────────────────────
                        _SecurityToggle(
                          icon: Icons.shield_outlined,
                          label: 'Two-Factor Authentication',
                          subtitle: 'Require a code from your email on login.',
                          value: _twoFactorEnabled,
                          onChanged: (v) {
                            if (v) {
                              Navigator.pop(ctx);
                              _showSetup2FA(ctx, onSuccess: () {
                                setState(() => _twoFactorEnabled = true);
                              });
                            } else {
                              setLocal(() => _twoFactorEnabled = false);
                              setState(() => _twoFactorEnabled = false);
                              _showSnack(ctx, 'Two-factor authentication disabled');
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        Text('ACCOUNT ACTIONS',
                          style: GoogleFonts.outfit(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: AppColors.secondaryText,
                          )),
                        const SizedBox(height: 10),
                        // ── Change Password ────────────────────
                        _SecurityCard(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                          subtitle: 'Update your account password',
                          onTap: () {
                            Navigator.pop(ctx);
                            _showChangePassword(ctx);
                          },
                        ),
                        const SizedBox(height: 10),
                        // ── Active Sessions ────────────────────
                        _SecurityCard(
                          icon: Icons.devices_outlined,
                          label: 'Active Sessions',
                          subtitle: 'View and revoke logged-in devices',
                          onTap: () {
                            Navigator.pop(ctx);
                            _showActiveSessions(ctx);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Change Password ────────────────────────────────────────────

  void _showChangePassword(BuildContext ctx) {
    final currentCtrl  = TextEditingController();
    final newCtrl      = TextEditingController();
    final confirmCtrl  = TextEditingController();

    _showSheet(ctx, title: 'Change Password',
      body: StatefulBuilder(builder: (context, setLocal) {
        bool hideCurrent = true, hideNew = true, hideConfirm = true;
        String? errorMsg;

        return StatefulBuilder(builder: (context, setInner) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter your current password, then choose a new one.',
              style: GoogleFonts.outfit(
                fontSize: 13, color: AppColors.secondaryText)),
            const SizedBox(height: 20),

            // Current password
            _PwField(label: 'Current Password', controller: currentCtrl,
              obscure: hideCurrent,
              onToggle: () => setInner(() => hideCurrent = !hideCurrent)),
            const SizedBox(height: 14),

            // New password
            _PwField(label: 'New Password', controller: newCtrl,
              obscure: hideNew,
              onToggle: () => setInner(() => hideNew = !hideNew)),
            const SizedBox(height: 8),

            // Strength hints — update live as user types
            ValueListenableBuilder(
              valueListenable: newCtrl,
              builder: (_, val, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PwHint('At least 8 characters',
                    met: val.text.length >= 8),
                  _PwHint('Contains a number',
                    met: val.text.contains(RegExp(r'\d'))),
                  _PwHint('Uppercase & lowercase',
                    met: val.text.contains(RegExp(r'[A-Z]')) &&
                         val.text.contains(RegExp(r'[a-z]'))),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Confirm password
            _PwField(label: 'Confirm New Password', controller: confirmCtrl,
              obscure: hideConfirm,
              onToggle: () => setInner(() => hideConfirm = !hideConfirm)),

            if (errorMsg != null) ...[
              const SizedBox(height: 10),
              Text(errorMsg!,
                style: GoogleFonts.outfit(
                  fontSize: 12, color: const Color(0xFFE05252))),
            ],
            const SizedBox(height: 24),

            SizedBox(width: double.infinity,
              child: _PrimaryBtn(label: 'Update Password', onTap: () {
                if (currentCtrl.text.isEmpty ||
                    newCtrl.text.isEmpty ||
                    confirmCtrl.text.isEmpty) {
                  setInner(() => errorMsg = 'Please fill in all fields.');
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  setInner(() => errorMsg = 'New passwords do not match.');
                  return;
                }
                if (newCtrl.text.length < 8) {
                  setInner(() => errorMsg =
                    'Password must be at least 8 characters.');
                  return;
                }
                Navigator.pop(ctx);
                _showSnack(ctx, 'Password updated successfully');
              })),
          ],
        ));
      }),
    );
  }

  // ── Active Sessions ────────────────────────────────────────────

  void _showActiveSessions(BuildContext ctx) {
    _showSheet(ctx, title: 'Active Sessions',
      body: StatefulBuilder(builder: (context, setLocal) {
        final sessions = <Map<String, dynamic>>[
          {
            'device': 'iPhone 15 Pro',
            'location': 'Manila, Philippines',
            'time': 'Active now',
            'icon': Icons.phone_iphone_rounded,
            'current': true,
          },
          {
            'device': 'Chrome · Windows',
            'location': 'Makati, Philippines',
            'time': '2 hours ago',
            'icon': Icons.laptop_rounded,
            'current': false,
          },
          {
            'device': 'iPad Air',
            'location': 'Quezon City, Philippines',
            'time': 'Yesterday, 3:45 PM',
            'icon': Icons.tablet_mac_rounded,
            'current': false,
          },
        ];

        // keep a mutable list so revoke updates the UI
        return StatefulBuilder(builder: (context2, setInner) {
          final live = List<Map<String, dynamic>>.from(sessions);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Devices currently signed in to your account.',
                style: GoogleFonts.outfit(
                  fontSize: 13, color: AppColors.secondaryText)),
              const SizedBox(height: 16),
              ...live.map((s) {
                final isCurrent = s['current'] as bool;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? AppColors.primary : AppColors.border,
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isCurrent
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.lightLavender,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(s['icon'] as IconData,
                        size: 20,
                        color: isCurrent
                          ? AppColors.primary
                          : AppColors.secondaryText),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(child: Text(s['device'] as String,
                            style: GoogleFonts.outfit(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: AppColors.navy))),
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10)),
                              child: Text('This device',
                                style: GoogleFonts.outfit(
                                  fontSize: 10, fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Text('${s['location']} · ${s['time']}',
                          style: GoogleFonts.outfit(
                            fontSize: 11, color: AppColors.secondaryText)),
                      ],
                    )),
                    if (!isCurrent)
                      TextButton(
                        onPressed: () {
                          setInner(() => sessions.remove(s));
                          _showSnack(ctx,
                            '${s['device']} has been signed out');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFE05252),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Revoke',
                          style: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showSnack(ctx, 'All other sessions signed out');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE05252),
                    side: const BorderSide(color: Color(0xFFE05252)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Sign Out All Other Sessions',
                    style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w600)),
                )),
            ],
          );
        });
      }),
    );
  }

  // ── 2FA Setup ──────────────────────────────────────────────────

  void _showSetup2FA(BuildContext ctx, {required VoidCallback onSuccess}) {
    final codeCtrl = TextEditingController();

    _showSheet(ctx, title: 'Two-Factor Authentication',
      body: StatefulBuilder(builder: (context, setLocal) {
        String? errorMsg;
        return StatefulBuilder(builder: (context2, setInner) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step dots
            Row(children: [
              _TFADot(n: '1', active: true),
              Expanded(child: Container(height: 2,
                color: AppColors.primary.withValues(alpha: 0.3))),
              _TFADot(n: '2', active: false),
              Expanded(child: Container(height: 2, color: AppColors.border)),
              _TFADot(n: '3', active: false),
            ]),
            const SizedBox(height: 20),
            Text('Verify your email',
              style: GoogleFonts.outfit(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: AppColors.navy)),
            const SizedBox(height: 6),
            Text(
              'We\'ve sent a 6-digit code to $_email. '
              'Enter it below to enable 2FA.',
              style: GoogleFonts.outfit(
                fontSize: 13, color: AppColors.secondaryText, height: 1.5)),
            const SizedBox(height: 24),
            // OTP box
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 26, fontWeight: FontWeight.w700,
                color: AppColors.navy, letterSpacing: 10),
              decoration: InputDecoration(
                counterText: '',
                hintText: '• • • • • •',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 20, color: AppColors.border, letterSpacing: 8),
                contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.primary, width: 1.5)),
              ),
            ),
            if (errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(errorMsg!,
                style: GoogleFonts.outfit(
                  fontSize: 12, color: const Color(0xFFE05252))),
            ],
            const SizedBox(height: 8),
            Center(child: TextButton(
              onPressed: () =>
                _showSnack(ctx, 'Code resent to $_email'),
              child: Text('Resend code',
                style: GoogleFonts.outfit(
                  fontSize: 13, color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
            )),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: _PrimaryBtn(label: 'Verify & Enable', onTap: () {
                if (codeCtrl.text.trim().length < 6) {
                  setInner(() =>
                    errorMsg = 'Please enter the full 6-digit code.');
                  return;
                }
                Navigator.pop(ctx);
                onSuccess();
                _showSnack(ctx, 'Two-factor authentication enabled!');
              })),
          ],
        ));
      }),
    );
  }

  // ── Help & Support ─────────────────────────────────────────────

  void _showHelpSupport(BuildContext ctx) {
    _showSheet(
      ctx,
      title: 'Help & Support',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SupportTile(
            icon: Icons.help_outline_rounded,
            label: 'FAQs',
            subtitle: 'Common questions answered',
            onTap: () {
              Navigator.pop(ctx);
              _showFAQs(ctx);
            },
          ),
          const SizedBox(height: 10),
          _SupportTile(
            icon: Icons.mail_outline_rounded,
            label: 'Contact Support',
            subtitle: 'Send us a message',
            onTap: () {
              Navigator.pop(ctx);
              _showContactSupport(ctx);
            },
          ),
          const SizedBox(height: 10),
          _SupportTile(
            icon: Icons.flag_outlined,
            label: 'Report a Problem',
            subtitle: 'Tell us what went wrong',
            onTap: () {
              Navigator.pop(ctx);
              _showReportProblem(ctx);
            },
          ),
          const SizedBox(height: 10),
          _SupportTile(
            icon: Icons.star_outline_rounded,
            label: 'Rate the App',
            subtitle: 'Share your feedback on the store',
            onTap: () {
              Navigator.pop(ctx);
              _showRateApp(ctx);
            },
          ),
        ],
      ),
    );
  }

  // ── FAQs ───────────────────────────────────────────────────────

  void _showFAQs(BuildContext ctx) {
    final faqs = [
      {
        'q': 'What is DENTRA?',
        'a': 'DENTRA is an AI-powered dental screening app that lets you scan your teeth at home and get preliminary insights before visiting a clinic.',
      },
      {
        'q': 'Is the screening medically accurate?',
        'a': 'DENTRA provides preliminary observations only. Results are not a substitute for a professional dental examination. Always consult a licensed dentist for diagnosis and treatment.',
      },
      {
        'q': 'How is my data stored?',
        'a': 'Your screening images and personal data are encrypted and stored securely. You can delete all your data at any time from the Screening Data section.',
      },
      {
        'q': 'Can I share results with my dentist?',
        'a': 'Yes. Each screening report can be exported as a PDF or shared directly with a clinic through the app.',
      },
      {
        'q': 'How do I change my password?',
        'a': 'Go to Profile → Security Settings → Change Password. A reset link will be sent to your registered email.',
      },
      {
        'q': 'Is DENTRA free to use?',
        'a': 'Basic screenings are free. A premium plan unlocks unlimited history, detailed AI reports, and priority clinic matching.',
      },
    ];

    _showSheet(
      ctx,
      title: 'FAQs',
      body: Column(
        children: List.generate(faqs.length, (i) {
          return _FaqItem(
            question: faqs[i]['q']!,
            answer: faqs[i]['a']!,
          );
        }),
      ),
    );
  }

  // ── Contact Support ────────────────────────────────────────────

  void _showContactSupport(BuildContext ctx) {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    _showSheet(
      ctx,
      title: 'Contact Support',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Our team usually responds within 24 hours.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          _LabeledField(label: 'Subject', controller: subjectCtrl),
          const SizedBox(height: 14),
          // Multi-line message field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Message',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: messageCtrl,
                maxLines: 5,
                style: GoogleFonts.outfit(fontSize: 14, color: AppColors.navy),
                decoration: InputDecoration(
                  hintText: 'Describe your issue…',
                  hintStyle: GoogleFonts.outfit(
                      fontSize: 13, color: AppColors.secondaryText),
                  contentPadding: const EdgeInsets.all(14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Contact options
          Row(
            children: [
              const Icon(Icons.mail_outline_rounded,
                  size: 14, color: AppColors.secondaryText),
              const SizedBox(width: 6),
              Text(
                'support@dentra.health',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _PrimaryBtn(
              label: 'Send Message',
              onTap: () {
                Navigator.pop(ctx);
                _showSnack(ctx, 'Message sent — we\'ll be in touch soon!');
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Report a Problem ───────────────────────────────────────────

  void _showReportProblem(BuildContext ctx) {
    final descCtrl = TextEditingController();
    String selectedCategory = 'App crash / freeze';

    final categories = [
      'App crash / freeze',
      'Incorrect scan result',
      'Login / account issue',
      'Payment issue',
      'Missing feature',
      'Other',
    ];

    _showSheet(
      ctx,
      title: 'Report a Problem',
      body: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help us improve DENTRA by describing the issue.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Category',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final selected = selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setSheetState(() => selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.lightLavender,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            selected ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Description',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: descCtrl,
              maxLines: 4,
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.navy),
              decoration: InputDecoration(
                hintText: 'Tell us what happened…',
                hintStyle: GoogleFonts.outfit(
                    fontSize: 13, color: AppColors.secondaryText),
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: _PrimaryBtn(
                label: 'Submit Report',
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnack(ctx, 'Report submitted — thank you!');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Rate the App ───────────────────────────────────────────────

  void _showRateApp(BuildContext ctx) {
    int stars = 0;

    _showSheet(
      ctx,
      title: 'Rate DENTRA',
      body: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'How are we doing?',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your feedback helps us make DENTRA better for everyone.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Star row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setSheetState(() => stars = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 44,
                      color: i < stars
                          ? const Color(0xFFFFC107)
                          : AppColors.secondaryText,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            if (stars > 0)
              Text(
                [
                  '',
                  'Poor',
                  'Fair',
                  'Good',
                  'Great',
                  'Excellent!'
                ][stars],
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            const SizedBox(height: 28),
            if (stars > 0)
              SizedBox(
                width: double.infinity,
                child: _PrimaryBtn(
                  label: stars >= 4
                      ? 'Leave a Review'
                      : 'Send Feedback',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSnack(
                      ctx,
                      stars >= 4
                          ? 'Thank you! Opening the app store…'
                          : 'Thanks for the feedback!',
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── About DENTRA ───────────────────────────────────────────────

  void _showAbout(BuildContext context) {
    _showSheet(
      context,
      title: 'About DENTRA',
      body: Column(
        children: [
          // App icon placeholder
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.medical_services_outlined,
                size: 32, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'DENTRA',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0 (build 1)',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 24),
          _infoRow('Developer', 'DENTRA Health, Inc.'),
          const Divider(color: AppColors.border),
          _infoRow('Website', 'www.dentra.health'),
          const Divider(color: AppColors.border),
          _infoRow('Support', 'support@dentra.health'),
          const Divider(color: AppColors.border),
          _infoRow('Platform', 'Flutter / iOS · Android · Web'),
          const SizedBox(height: 24),
          Text(
            '© 2026 DENTRA Health, Inc. All rights reserved.',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Log Out ────────────────────────────────────────────────────

  void _showLogOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log Out',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnack(context, 'Logged out');
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.outfit(
                color: const Color(0xFFE05252),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── snack ──────────────────────────────────────────────────────

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── route tap by label ─────────────────────────────────────────

  void _handleTap(BuildContext context, String label) {
    switch (label) {
      case 'Personal Information':
        _showPersonalInfo(context);
        break;
      case 'Privacy & Consent':
        _showPrivacyConsent(context);
        break;
      case 'Privacy Policy':
        _showPrivacyPolicy(context);
        break;
      case 'View All Screenings':
        _showAllScreenings(context, rootContext: context);
        break;
      case 'Delete Account / Data':
        _showDeleteAccount(context);
        break;
      case 'Security Settings':
        _showSecuritySettings(context);
        break;
      case 'Help & Support':
        _showHelpSupport(context);
        break;
      case 'About DENTRA':
        _showAbout(context);
        break;
      case 'View Introduction':
        Navigator.of(context, rootNavigator: true)
            .push(OnboardingScreen.replayRoute());
        break;
    }
  }

  // ── build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sections = [
      {
        'title': 'Account',
        'items': ['Personal Information', 'Privacy & Consent', 'Privacy Policy'],
      },
      {
        'title': 'Screening Data',
        'items': ['View All Screenings', 'Delete Account / Data'],
      },
      {
        'title': 'Security',
        'items': ['Security Settings'],
      },
      {
        'title': 'Support',
        'items': ['Help & Support', 'About DENTRA', 'View Introduction'],
      },
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          // ── Profile header ──────────────────────────────────────
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, 52, AppSpacing.screenH, 24),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Tappable avatar
                  GestureDetector(
                    onTap: () => _showAvatarSheet(context),
                    child: Stack(
                      children: [
                        AvatarWidget(
                          size: 64,
                          imageBytes: _avatarBytes,
                          initials: _name
                              .trim()
                              .split(' ')
                              .where((w) => w.isNotEmpty)
                              .take(2)
                              .map((w) => w[0].toUpperCase())
                              .join(),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tappable name
                  GestureDetector(
                    onTap: () => _showEditNameSheet(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _name,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.secondaryText,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _email,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),

          // ── Sections ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...sections.map((sec) => _SettingsSection(
                        title: sec['title'] as String,
                        items: sec['items'] as List<String>,
                        onTap: (label) => _handleTap(context, label),
                      )),

                  const SizedBox(height: 4),

                  // Log out button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showLogOut(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Center(
                            child: Text(
                              'Log Out',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFE05252),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsSection
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final void Function(String label) onTap;

  const _SettingsSection({
    required this.title,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: List.generate(items.length, (i) {
                return Column(
                  children: [
                    if (i > 0)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 0,
                        color: AppColors.border,
                      ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onTap(items[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                items[i],
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: items[i] == 'Delete Account / Data'
                                      ? const Color(0xFFE05252)
                                      : AppColors.navy,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: items[i] == 'Delete Account / Data'
                                    ? const Color(0xFFE05252)
                                    : AppColors.secondaryText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sheet sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// A toggleable row for consent/settings sheets.
class _ConsentToggle extends StatefulWidget {
  final String label;
  final String subtitle;
  final bool initialValue;

  const _ConsentToggle({
    required this.label,
    required this.subtitle,
    required this.initialValue,
  });

  @override
  State<_ConsentToggle> createState() => _ConsentToggleState();
}

class _ConsentToggleState extends State<_ConsentToggle> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _value,
            onChanged: (v) => setState(() => _value = v),
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

/// An action tile used inside sheets (icon + label + arrow).
class _SheetActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _SheetActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFE05252) : AppColors.navy;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
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

/// Labelled text field for edit sheets.
class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.navy,
          ),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Filled primary button.
class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Support sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Card-style tile used inside the Help & Support sheet.
class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.lightLavender,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable FAQ accordion item.
class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded ? AppColors.primary : AppColors.border,
          width: _expanded ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.question,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.secondaryText,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 10),
                  Text(
                    widget.answer,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Security sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Toggle tile with icon, used in Security Settings.
class _SecurityToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SecurityToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.primary : AppColors.border,
          width: value ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: value
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.lightLavender,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18,
            color: value ? AppColors.primary : AppColors.secondaryText),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
              style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.navy)),
            const SizedBox(height: 2),
            Text(subtitle,
              style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.secondaryText)),
          ],
        )),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
        ),
      ]),
    );
  }
}

/// Tappable card for security actions (Change Password, Active Sessions).
class _SecurityCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SecurityCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.lightLavender,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.navy)),
                const SizedBox(height: 1),
                Text(subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12, color: AppColors.secondaryText)),
              ],
            )),
            const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.secondaryText),
          ]),
        ),
      ),
    );
  }
}

/// Password field with show/hide toggle.
class _PwField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  const _PwField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.outfit(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.secondaryText)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.navy),
          decoration: InputDecoration(
            contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
                size: 18, color: AppColors.secondaryText),
              onPressed: onToggle,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

/// Password strength requirement hint row.
class _PwHint extends StatelessWidget {
  final String text;
  final bool met;
  const _PwHint(this.text, {required this.met});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 14,
          color: met ? const Color(0xFF4CAF50) : AppColors.secondaryText),
        const SizedBox(width: 6),
        Text(text,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: met ? const Color(0xFF4CAF50) : AppColors.secondaryText)),
      ]),
    );
  }
}

/// Numbered step dot for the 2FA flow.
class _TFADot extends StatelessWidget {
  final String n;
  final bool active;
  const _TFADot({required this.n, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.lightLavender,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(n,
        style: GoogleFonts.outfit(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppColors.secondaryText)),
    );
  }
}

/// Stat card for screening detail (icon + big number + label).
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label + value row inside a details card.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

/// Observation tile with coloured icon, label and subtitle.
class _ObservationTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;

  const _ObservationTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
