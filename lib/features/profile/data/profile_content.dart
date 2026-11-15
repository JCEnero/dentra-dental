/// Static copy for the profile's help, policy and about sheets.
abstract class ProfileContent {
  /// The app's only contact, for support and privacy requests alike.
  static const supportEmail = 'dentra.support@gmail.com';

  /// Keep in step with `version` in pubspec.yaml.
  static const appVersion = '1.0.0 (build 1)';

  static const policyUpdated = 'October 18, 2026';

  static const faqs = <(String, String)>[
    (
      'What is Dentra?',
      'Dentra is a smart dental screening app. You scan your teeth at '
          'home and get preliminary observations before visiting a clinic.',
    ),
    (
      'Is the screening a diagnosis?',
      'No. Dentra gives preliminary observations only and does not replace an '
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
          'you a 6-digit code to confirm the setup. After that, signing in '
          'with your password also asks for a code sent to your email.',
    ),
  ];

  /// Shown above the numbered sections in every privacy policy view.
  static const policyIntro =
      'Dentra Health, Inc. ("Dentra", "we", "us") respects your privacy. '
      'Dentra collects only the information it needs to run the app, and we '
      'handle it in line with the Data Privacy Act of 2012 (Republic Act No. '
      '10173) and its implementing rules. This policy explains what we '
      'collect, why we collect it, who we share it with, and the choices you '
      'have. By creating an account or using Dentra, you acknowledge that you '
      'have read this policy.';

  static const policySections = <(String, String)>[
    (
      'Information we collect',
      'We collect information in three ways.\n\n'
          'Information you give us:\n'
          '• Account details such as your name, email address, phone number, '
          'date of birth and password.\n'
          '• Profile details you choose to add, such as a profile photo.\n'
          '• Dental screening photos and videos you capture or upload.\n'
          '• Answers you give in questionnaires, notes, and messages to our smart '
          'assistant or support team.\n\n'
          'Information collected automatically:\n'
          '• Device information such as model, operating system, app version '
          'and language.\n'
          '• Usage information such as screens viewed, features used, crash '
          'reports and performance logs.\n'
          '• Approximate or precise location, only when you allow it, to show '
          'nearby dental clinics.\n\n'
          'Information from others:\n'
          '• If you sign in with Google, we receive your name, email address '
          'and profile photo from Google.',
    ),
    (
      'Sensitive personal information',
      'Dental images, screening results and oral health details are health '
          'information. The law treats these as sensitive personal '
          'information. We process them only with your consent, only to '
          'provide the features you request, and we apply stricter access '
          'controls to them than to other data.',
    ),
    (
      'How we use your information',
      'We use your information to:\n'
          '• Create and manage your account and keep it secure, including '
          'email verification and two-factor authentication.\n'
          '• Run dental screenings and show your results, history and '
          'progress over time.\n'
          '• Recommend oral-care tips and possible treatment options.\n'
          '• Help you find and contact nearby dental clinics.\n'
          '• Send you service messages such as verification codes, security '
          'alerts and reminders you have turned on.\n'
          '• Send oral-care tips and product news, only if you opt in.\n'
          '• Understand how the app is used so we can fix bugs and improve '
          'features, only if you allow usage analytics.\n'
          '• Prevent fraud and abuse, and meet our legal obligations.',
    ),
    (
      'Smart screening',
      'Dentra uses automated image analysis to review your dental photos and '
          'to power the in-app assistant. To do this, images and messages are '
          'sent securely to our secure processing provider, which analyzes them on '
          'our behalf and is not allowed to use them for its own purposes.\n\n'
          'Screening results are preliminary observations only. They are not a '
          'diagnosis and can be wrong. Always consult a licensed dentist '
          'before making decisions about your dental health.',
    ),
    (
      'Legal basis for processing',
      'We process your personal information when:\n'
          '• You have given your consent, for example for screenings, '
          'analytics and marketing emails.\n'
          '• It is necessary to provide the service you signed up for.\n'
          '• We are required to by law, regulation or a valid court order.\n'
          '• It is needed to protect your vital interests or the security of '
          'our users and systems.\n\n'
          'Where we rely on consent, you can withdraw it at any time. This '
          'does not affect processing that happened before you withdrew it.',
    ),
    (
      'How we share your information',
      'We do not sell your personal information, and we do not share it for '
          'advertising.\n\n'
          'We share information only with:\n'
          '• Service providers that help us run Dentra, such as cloud hosting, '
          'secure file storage, email delivery and image processing. They act on '
          'our instructions and must protect your data.\n'
          '• Dental clinics or professionals, only when you choose to share '
          'your results with them.\n'
          '• Authorities, when required by law or to protect the rights, '
          'safety and property of our users or the public.\n'
          '• A successor company, if Dentra is involved in a merger, '
          'acquisition or sale of assets. We will notify you before your data '
          'becomes subject to a different privacy policy.',
    ),
    (
      'Data retention',
      'We keep your personal information for as long as your account is '
          'active or as needed to provide the service.\n\n'
          'When you delete your account, we delete or anonymize your personal '
          'information within 30 days. Some records may be kept longer when '
          'the law requires it, or to resolve disputes and enforce our '
          'agreements. Backups are overwritten on a regular schedule. '
          'Anonymized data that can no longer identify you may be kept to '
          'improve our service.',
    ),
    (
      'How we protect your information',
      'We use organizational, physical and technical safeguards, including:\n'
          '• Encryption of data in transit (HTTPS/TLS) and at rest.\n'
          '• Hashed passwords that we cannot read.\n'
          '• Secure storage of sign-in tokens on your device.\n'
          '• Optional two-factor authentication.\n'
          '• Limited staff access on a need-to-know basis.\n\n'
          'No system is completely secure. If a breach affects your personal '
          'information, we will notify you and the National Privacy '
          'Commission as required by law.',
    ),
    (
      'Your rights',
      'Under the Data Privacy Act, you have the right to:\n'
          '• Be informed about how your personal information is processed.\n'
          '• Access a copy of your personal information.\n'
          '• Correct inaccurate or incomplete information.\n'
          '• Object to processing, and withdraw consent you have given.\n'
          '• Have your information erased or blocked.\n'
          '• Receive your data in a portable, commonly used format.\n'
          '• Be compensated for damages caused by inaccurate, unlawfully '
          'obtained or misused personal information.\n'
          '• File a complaint with the National Privacy Commission '
          '(www.privacy.gov.ph).\n\n'
          'To use any of these rights, email $supportEmail. We may ask you to '
          'verify your identity first, and we will respond within 30 days.',
    ),
    (
      'Your choices',
      '• Profile, then Privacy & consent: turn usage analytics and marketing '
          'emails on or off.\n'
          '• Your device settings: allow or block camera, photos and location '
          'access at any time.\n'
          '• Profile, then Delete account: permanently remove your account '
          'and its data.\n\n'
          'Turning off some permissions may limit features. For example, '
          'screenings need the camera and the clinic finder works best with '
          'location.',
    ),
    (
      "Children's privacy",
      'Dentra is not intended for children under 13. Users between 13 and 17 '
          'should use Dentra with the consent and supervision of a parent or '
          'guardian. If you believe a child has given us personal information '
          'without that consent, contact us and we will delete it.',
    ),
    (
      'Data stored outside the Philippines',
      'Some of our service providers store or process data on servers outside '
          'the Philippines. When this happens, we make sure your information '
          'receives protection comparable to what Philippine law requires, '
          'through contracts and security measures.',
    ),
    (
      'Third-party services',
      'Dentra works with services such as Google Sign-In and Google Maps. '
          'When you use them, their own privacy policies also apply. Dentra '
          'may also link to clinic websites and other sites we do not control. '
          'We are not responsible for their privacy practices, so please '
          'review their policies.',
    ),
    (
      'Changes to this policy',
      'We may update this policy from time to time. The "Last updated" date '
          'shows when it last changed. If we make significant changes, we will '
          'tell you in the app or by email before they take effect. Continuing '
          'to use Dentra after an update means you accept the revised policy.',
    ),
    (
      'Contact us',
      'For privacy questions, requests or complaints, email us at '
          '$supportEmail.',
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
