import 'package:flutter/material.dart';

class LegalInformationScreen extends StatefulWidget {
  const LegalInformationScreen({super.key});

  @override
  _LegalInformationScreenState createState() => _LegalInformationScreenState();
}

class _LegalInformationScreenState extends State<LegalInformationScreen> {
  bool isExpandedTerms = false;
  bool isExpandedPrivacy = false;
  bool isExpandedRefund = false;
  bool isExpandedIP = false;
  bool isExpandedDispute = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Legal Information'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildIntroText(),
            buildSection(
              title: 'Terms of Service',
              content: termsOfServiceText(),
              isExpanded: isExpandedTerms,
              toggleExpanded: () {
                setState(() {
                  isExpandedTerms = !isExpandedTerms;
                });
              },
            ),
            buildSection(
              title: 'Privacy Policy',
              content: privacyPolicyText(),
              isExpanded: isExpandedPrivacy,
              toggleExpanded: () {
                setState(() {
                  isExpandedPrivacy = !isExpandedPrivacy;
                });
              },
            ),
            buildSection(
              title: 'Refund Policy',
              content: refundPolicyText(),
              isExpanded: isExpandedRefund,
              toggleExpanded: () {
                setState(() {
                  isExpandedRefund = !isExpandedRefund;
                });
              },
            ),
            buildSection(
              title: 'Intellectual Property',
              content: intellectualPropertyText(),
              isExpanded: isExpandedIP,
              toggleExpanded: () {
                setState(() {
                  isExpandedIP = !isExpandedIP;
                });
              },
            ),
            buildSection(
              title: 'Dispute Resolution',
              content: disputeResolutionText(),
              isExpanded: isExpandedDispute,
              toggleExpanded: () {
                setState(() {
                  isExpandedDispute = !isExpandedDispute;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildIntroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Riendzo\'s Legal Information page.',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        SizedBox(height: 16),
        Text(
          'Below you will find important legal details concerning your use of our services and platform. Please review these policies carefully, as they govern your relationship with Riendzo and your use of our app, website, and services.',
        ),
        SizedBox(height: 16),
        Divider(),
      ],
    );
  }

  Widget buildSection({required String title, required String content, required bool isExpanded, required Function toggleExpanded}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          isExpanded ? content : '${content.substring(0, 100)}...',
          softWrap: true,
        ),
        GestureDetector(
          onTap: () => toggleExpanded(),
          child: Text(
            isExpanded ? 'View Less' : 'View More',
            style: TextStyle(color: Colors.blue),
          ),
        ),
        SizedBox(height: 16),
        Divider(),
      ],
    );
  }

  // Text content for each section
  String termsOfServiceText() {
    return '''By using Riendzo’s platform, you agree to the following terms and conditions. These terms govern your access to our services, including any use of our app, website, and interactions with third-party providers.
    
1. Acceptance of Terms
By registering or using our services, you agree to comply with all applicable laws and the following terms. If you do not agree, please do not use the platform.

2. Service Use
Riendzo provides a platform for users to connect with travel agencies, transport providers, hotels, and other service providers. We are not responsible for any actions, omissions, or errors made by third-party providers.

3. User Accounts
To access our services, users must create an account. You are responsible for maintaining the confidentiality of your account credentials and are liable for all activities that occur under your account.

4. Payments
When you make a booking or a payment through the Riendzo platform, you agree to our payment terms. Payments are processed securely and according to industry standards.

5. Limitation of Liability
Riendzo is not liable for any damages, losses, or issues that arise from your use of third-party services. We act solely as a facilitator and are not responsible for the quality or safety of services booked through our platform.''';
  }

  String privacyPolicyText() {
    return '''Your privacy is very important to us. Our Privacy Policy explains how we collect, use, and protect your personal information when you use our platform and services.

1. Data Collection
We collect personal information, such as your name, email address, and payment details when you use our services. This data is necessary for providing you with a seamless experience.

2. Use of Data
Your personal information is used to facilitate bookings, improve user experience, and communicate important updates about our services.

3. Data Protection
We use industry-standard security measures to protect your personal data. We do not sell or share your data with third-party companies for marketing purposes without your consent.

4. Cookies
Our website uses cookies to enhance your browsing experience and track website analytics. You can choose to disable cookies in your browser settings, but this may limit your ability to use some features of the platform.''';
  }

  String refundPolicyText() {
    return '''We understand that sometimes plans change. Our Refund Policy explains the conditions under which users may request a refund for services booked through Riendzo.

1. Refund Eligibility
Refunds are subject to the terms and conditions of the third-party providers (e.g., hotels, transport providers). Riendzo does not directly handle refunds but will assist you in contacting the service provider for resolution.

2. Processing Time
Refunds may take up to 7-10 business days to process, depending on the provider’s policies. Riendzo will do its best to ensure a smooth process.

3. No-Refund Circumstances
Certain services may be non-refundable, such as last-minute bookings or services with strict cancellation policies. Please review the provider’s terms before making a reservation.''';
  }

  String intellectualPropertyText() {
    return '''All content on the Riendzo platform, including text, graphics, logos, images, and software, is owned by Riendzo or our licensors and is protected under applicable intellectual property laws.

1. Trademarks
The Riendzo name and logo are registered trademarks of Riendzo. You may not use these without written consent from us.

2. Copyright
All original content on the Riendzo platform is protected by copyright law. Unauthorized use or reproduction of this content is prohibited.

3. Third-Party Content
Any third-party content or trademarks displayed on the Riendzo platform are the property of their respective owners and used with permission.''';
  }

  String disputeResolutionText() {
    return '''In the event of a dispute between you and Riendzo, we aim to resolve the matter quickly and amicably. Any disputes will be subject to the laws and jurisdiction of [Your Country].

1. Informal Resolution
We encourage users to contact us directly to resolve disputes before pursuing formal legal action.

2. Arbitration
If informal resolution is not possible, any legal dispute will be settled through arbitration in accordance with the arbitration laws of [Your Country].''';
  }
}
