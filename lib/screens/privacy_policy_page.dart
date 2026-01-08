import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppColors {
  static const primary = Color(0xFFFF2D8F);
  static const primaryDark = Color(0xFFD81F75);
  static const accent = Color(0xFFFF6FB5);
  static const background = Color(0xFFFFF5FA);
  static const card = Colors.white;
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF9E9E9E);
  static const border = Color(0xFFF2D2E9);
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last updated: 17 December 2024',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildSection(
                        '1. Introduction',
                        'BMS Pro Pty Ltd (ABN 71 608 672 608) ("BMS Pro", "we", "us", or "our") is committed to protecting your privacy in accordance with the Privacy Act 1988 (Cth) ("Privacy Act") and the Australian Privacy Principles ("APPs").\n\n'
                        'This Privacy Policy describes how we collect, hold, use, and disclose your personal information, and how you can access and correct that information or make a complaint about our handling of your personal information.\n\n'
                        'By using our services, website, or providing us with your personal information, you consent to the collection, use, and disclosure of your personal information in accordance with this Privacy Policy.',
                      ),
                      _buildSection(
                        '2. Types of Personal Information We Collect',
                        'The types of personal information we may collect include:\n\n'
                        '• Name, address, email address, and phone number\n'
                        '• Business name and ABN (if applicable)\n'
                        '• Payment and billing information\n'
                        '• Information about your use of our services and website\n'
                        '• Device information, IP addresses, and browser type\n'
                        '• Staff and employee information for businesses using our platform\n'
                        '• Client and customer booking information\n'
                        '• Communication records between you and BMS Pro\n'
                        '• Any other information you choose to provide to us\n\n'
                        'We do not collect sensitive information (such as health information, racial or ethnic origin, political opinions, religious beliefs, or sexual orientation) unless you voluntarily provide it or it is required by law.',
                      ),
                      _buildSection(
                        '3. How We Collect Personal Information',
                        'We collect personal information in a variety of ways, including:\n\n'
                        '• When you register for an account or subscribe to our services\n'
                        '• When you make a booking or transaction through our platform\n'
                        '• When you contact us via email, phone, or our website\n'
                        '• When you complete forms or surveys\n'
                        '• Through cookies and similar technologies when you visit our website\n'
                        '• From third parties such as our business partners, payment processors, and analytics providers\n\n'
                        'Where reasonable and practicable, we will collect personal information directly from you. If we collect personal information from a third party, we will take reasonable steps to ensure you are aware of this Privacy Policy.',
                      ),
                      _buildSection(
                        '4. Purpose of Collection, Use and Disclosure',
                        'We collect, hold, use, and disclose your personal information for the following purposes:\n\n'
                        '• To provide, operate, and maintain our services\n'
                        '• To process payments and manage your account\n'
                        '• To communicate with you about your account, bookings, and our services\n'
                        '• To send you marketing communications (with your consent)\n'
                        '• To improve and personalise our services\n'
                        '• To comply with our legal obligations\n'
                        '• To respond to your inquiries and provide customer support\n'
                        '• To detect, prevent, and address technical issues and security threats\n'
                        '• For any other purpose with your consent\n\n'
                        'We will not use or disclose your personal information for a purpose other than the purpose for which it was collected, unless you have consented, or the use or disclosure is required or authorised by law.',
                      ),
                      _buildSection(
                        '5. Disclosure to Third Parties',
                        'We may disclose your personal information to:\n\n'
                        '• Our employees, contractors, and service providers who assist in operating our business\n'
                        '• Payment processors and financial institutions\n'
                        '• Cloud storage and hosting providers\n'
                        '• Marketing and analytics service providers\n'
                        '• Professional advisers such as lawyers and accountants\n'
                        '• Government authorities when required by law\n'
                        '• Any other parties with your consent\n\n'
                        'We take reasonable steps to ensure that third parties to whom we disclose your personal information are bound by confidentiality and privacy obligations.',
                      ),
                      _buildSection(
                        '6. Cross-Border Disclosure of Personal Information',
                        'Some of our service providers may be located overseas, including in the United States, European Union, and other countries. Before disclosing personal information to an overseas recipient, we take reasonable steps to ensure:\n\n'
                        '• The overseas recipient does not breach the APPs, or\n'
                        '• You consent to the disclosure, or\n'
                        '• The disclosure is required or authorised by law\n\n'
                        'By providing your personal information, you consent to the disclosure of your personal information to overseas recipients for the purposes described in this Privacy Policy.',
                      ),
                      _buildSection(
                        '7. Data Quality and Security',
                        'We take reasonable steps to ensure that:\n\n'
                        '• The personal information we collect is accurate, up-to-date, complete, and relevant\n'
                        '• Personal information is protected from misuse, interference, loss, unauthorised access, modification, or disclosure\n\n'
                        'Our security measures include:\n\n'
                        '• Encryption of data in transit and at rest\n'
                        '• Secure data centres with physical access controls\n'
                        '• Regular security assessments and penetration testing\n'
                        '• Access controls and authentication measures\n'
                        '• Staff training on data protection and privacy\n\n'
                        'We will destroy or de-identify personal information when it is no longer needed for the purpose for which it was collected, unless we are required by law to retain it.',
                      ),
                      _buildSection(
                        '8. Access to and Correction of Personal Information',
                        'You have the right to request access to your personal information held by us and to request correction of any inaccurate, out-of-date, incomplete, or misleading information.\n\n'
                        'To request access to or correction of your personal information, please contact us using the details provided below. We will respond to your request within a reasonable period (generally within 30 days).\n\n'
                        'We may refuse to provide access or make corrections in certain circumstances permitted by law, such as where access would pose a serious threat to health or safety, or where the request is frivolous or vexatious. If we refuse your request, we will provide you with written reasons for our decision.\n\n'
                        'There is no fee for making a request, but we may charge a reasonable fee for providing access to your personal information.',
                      ),
                      _buildSection(
                        '9. Direct Marketing',
                        'We may use your personal information to send you marketing communications about our products, services, and promotions that may be of interest to you. This includes communications by email, SMS, phone, and post.\n\n'
                        'You can opt out of receiving marketing communications at any time by:\n\n'
                        '• Clicking the "unsubscribe" link in our emails\n'
                        '• Contacting us using the details provided below\n'
                        '• Updating your preferences in your account settings\n\n'
                        'Please note that even if you opt out of marketing communications, we may still send you transactional or administrative communications related to your account and use of our services.',
                      ),
                      _buildSection(
                        '10. Cookies and Tracking Technologies',
                        'Our website uses cookies and similar tracking technologies to collect information about your browsing activities. Cookies are small data files stored on your device that help us improve your experience and our services.\n\n'
                        'We use the following types of cookies:\n\n'
                        '• Essential cookies: Required for the operation of our website\n'
                        '• Performance cookies: Help us understand how visitors interact with our website\n'
                        '• Functional cookies: Remember your preferences and settings\n'
                        '• Marketing cookies: Track your activity to deliver relevant advertising\n\n'
                        'You can manage your cookie preferences through your browser settings. However, disabling certain cookies may affect the functionality of our website.',
                      ),
                      _buildSection(
                        '11. Anonymity and Pseudonymity',
                        'Where practicable, you have the option of dealing with us anonymously or using a pseudonym. However, in many cases, we will need your personal information to provide our services to you. If you do not provide us with the personal information we request, we may not be able to provide you with our services, respond to your inquiries, or process your transactions.',
                      ),
                      _buildSection(
                        '12. Data Retention',
                        'We retain your personal information for as long as necessary to:\n\n'
                        '• Provide our services to you\n'
                        '• Comply with our legal and regulatory obligations\n'
                        '• Resolve disputes and enforce our agreements\n'
                        '• Fulfil the purposes described in this Privacy Policy\n\n'
                        'When personal information is no longer required, we will securely destroy or de-identify it in accordance with our data retention policies.',
                      ),
                      _buildSection(
                        '13. Complaints',
                        'If you believe that we have breached the APPs or this Privacy Policy, you may lodge a complaint with us. Please contact us using the details below and provide details of your complaint.\n\n'
                        'We will investigate your complaint and respond to you within 30 days. If you are not satisfied with our response, you may escalate your complaint to the Office of the Australian Information Commissioner (OAIC):\n\n'
                        'Office of the Australian Information Commissioner\n\n'
                        'GPO Box 5288\n'
                        'Sydney NSW 2001\n'
                        'Phone: 1300 363 992\n'
                        'Website: www.oaic.gov.au',
                      ),
                      _buildSection(
                        '14. Changes to This Privacy Policy',
                        'We may update this Privacy Policy from time to time to reflect changes in our practices or applicable laws. We will notify you of any material changes by posting the updated policy on our website with a new "Last updated" date. We encourage you to review this Privacy Policy periodically. Your continued use of our services after any changes constitutes your acceptance of the updated Privacy Policy.',
                      ),
                      _buildSection(
                        '15. Contact Us',
                        'If you have any questions about this Privacy Policy, wish to access or correct your personal information, or want to make a complaint, please contact our Privacy Officer:\n\n'
                        'BMS Pro Privacy Officer\n\n'
                        'Email: admin@softdev.global\n'
                        'Phone: 03 8797 3795\n'
                        'Address: 12 Stelvio Close, Lynbrook VIC 3975, Australia',
                      ),
                      _buildSection(
                        '16. Definitions',
                        'In this Privacy Policy:\n\n'
                        '"Personal information" has the meaning given to it in the Privacy Act 1988 (Cth) and includes information or an opinion about an identified individual, or an individual who is reasonably identifiable.\n\n'
                        '"Sensitive information" has the meaning given to it in the Privacy Act 1988 (Cth) and includes information about health, racial or ethnic origin, political opinions, religious beliefs, and sexual orientation.\n\n'
                        '"APPs" means the Australian Privacy Principles set out in Schedule 1 of the Privacy Act 1988 (Cth).',
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(color: AppColors.background),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    FontAwesomeIcons.chevronLeft,
                    size: 20,
                    color: AppColors.text,
                  ),
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.text,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
