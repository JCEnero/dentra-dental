/// Static copy for the profile's help, policy and about sheets.
abstract class ProfileContent {
  static const supportEmail = 'support@dentra.health';
  static const privacyEmail = 'privacy@dentra.health';
  static const website = 'www.dentra.health';

  /// Keep in step with `version` in pubspec.yaml.
  static const appVersion = '1.0.0 (build 1)';

  static const policyUpdated = 'September 13, 2026';

  static const faqs = <(String, String)>[
    (
      'What is DENTRA?',
      'DENTRA is an AI-assisted dental screening app. You scan your teeth at '
          'home and get preliminary observations before visiting a clinic.',
    ),
    (
      'Is the screening a diagnosis?',
      'No. DENTRA gives preliminary observations only and does not replace an '
          'examination. Always consult a licensed dentist for diagnosis and '
          'treatment.',
    ),
    (
      'How is my data stored?',
      'Your screening data is stored securely and tied to your account. You '
          'can delete your account and its data at any time from Profile.',
    ),
    (
      'How do I change my password?',
      'Go to Profile, then Change password. If you have forgotten your current '
          'password, use "Forgot password?" there to get a reset code by email.',
    ),
    (
      'How do I turn on two-factor authentication?',
      'Go to Profile and switch on Two-factor authentication. We will email '
          'you a 6-digit code to confirm the setup.',
    ),
  ];

  static const policySections = <(String, String)>[
    (
      'Information we collect',
      'We collect information you give us, such as your name, email address, '
          'phone number, date of birth and dental screening images. We also '
          'collect device and usage information to improve the service.',
    ),
    (
      'How we use your information',
      'We use your information to provide and improve DENTRA, personalize your '
          'experience, send notifications you have agreed to, and help you find '
          'nearby dental clinics.',
    ),
    (
      'Data sharing',
      'We do not sell your personal data. We share information only with '
          'dental professionals you choose to connect with, or when required by '
          'law.',
    ),
    (
      'Data retention',
      'We keep your data while your account is active. You can delete your '
          'account and its data at any time from Profile.',
    ),
    (
      'Security',
      'We use industry-standard encryption and security practices to protect '
          'your data in transit and at rest.',
    ),
    (
      'Contact us',
      'For privacy questions, email $privacyEmail.',
    ),
  ];

  static const problemCategories = [
    'App crash or freeze',
    'Scan result looks wrong',
    'Sign-in or account',
    'Device connection',
    'Something else',
  ];
}
