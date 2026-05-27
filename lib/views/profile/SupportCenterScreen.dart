import 'package:flutter/material.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  _SupportCenterScreenState createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  bool _viewMoreFAQs = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Support Center'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Text
            Text(
              "Welcome to the Riendzo Support Center! We're here to help you make the most out of your experience on our platform.",
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 20),

            // Section: Frequently Asked Questions
            Text(
              "Frequently Asked Questions",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
            ),
            SizedBox(height: 10),

            // Display some initial FAQ items
            faqTile(
              "1. How do I create an account on Riendzo?",
              "Solution: Click on the 'Sign Up' button at the top of the homepage. Enter your email, create a password, and fill in your details. You will receive a confirmation email to activate your account.",
            ),
            faqTile(
              "2. I forgot my password, how can I reset it?",
              "Solution: On the login page, click 'Forgot Password.' Enter your email, and we’ll send you instructions on how to reset your password.",
            ),
            faqTile(
              "3. How do I book a trip or service?",
              "Solution: Log in, use the search function to find a destination or service, then click 'Book Now' and follow the instructions to complete your booking.",
            ),
            faqTile(
              "4. Can I modify or cancel a booking?",
              "Solution: Yes, you can modify or cancel bookings in the 'My Bookings' section of your profile, subject to the service provider's cancellation policy.",
            ),

            // View More Button to expand FAQ list
            if (!_viewMoreFAQs)
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _viewMoreFAQs = true;
                    });
                  },
                  child: Text("View More", style: TextStyle(fontSize: 16.0)),
                ),
              ),

            if (_viewMoreFAQs)
              Column(
                children: [
                  faqTile(
                    "5. How do I pay for bookings?",
                    "Solution: Riendzo supports various secure payment methods, including credit/debit cards, PayPal, and mobile payments.",
                  ),
                  faqTile(
                    "6. What should I do if my booking is not confirmed?",
                    "Solution: Check the 'My Bookings' section for updates. If the issue persists, contact support.",
                  ),
                  faqTile(
                    "7. How do I contact the service provider directly?",
                    "Solution: After making a booking, communicate with the service provider via the messaging feature in 'My Bookings'.",
                  ),
                  faqTile(
                    "8. Can I track my taxi or transport booking in real-time?",
                    "Solution: Go to 'My Bookings' and click 'Track Taxi' to view the real-time location of your driver.",
                  ),
                  faqTile(
                    "9. I’m having trouble using the app. What can I do?",
                    "Solution: Ensure that you have the latest version of the app installed. Restart the app or device if the issue persists.",
                  ),
                  faqTile(
                    "10. How do I collaborate with Riendzo as a business partner?",
                    "Solution: Visit our Partner Program page or contact us at partnerships@riendzo.com.",
                  ),
                ],
              ),

            SizedBox(height: 20),

            // Additional Support Section
            Text(
              "Additional Support Topics",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
            ),
            SizedBox(height: 10),
            faqTile(
              "App is running slow or not loading",
              "Solution: Check your internet connection, and ensure the app is updated. Try clearing the app cache or reinstalling.",
            ),
            faqTile(
              "Payment failure during checkout",
              "Solution: Verify your payment information and check with your bank.",
            ),
            faqTile(
              "Can’t find my booking in 'My Bookings'",
              "Solution: Ensure you're logged into the correct account. Contact support if your booking is still missing.",
            ),

            SizedBox(height: 20),

            // Need More Help Section
            Text(
              "Need More Help?",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
            ),
            SizedBox(height: 10),
            Text(
              "If you didn’t find the answer to your question above, our support team is here to assist you. Click the button below to chat with a consultant.",
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 20),

            // Talk to a Consultant Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate or trigger 'Talk to a Consultant' action
                },
                icon: Icon(Icons.chat_bubble_outline),
                label: Text('Talk to a Consultant'),
                style: ElevatedButton.styleFrom(

                  padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
                  textStyle: TextStyle(fontSize: 16.0),
                ),
              ),
            ),

            SizedBox(height: 20),

            Center(
              child: Text(
                "We’re available 24/7 to assist you.",
                style: TextStyle(fontSize: 16.0, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build an ExpansionTile for each FAQ
  Widget faqTile(String question, String answer) {
    return Column(
      children: [
        ExpansionTile(
          title: Text(
            question,
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                answer,
                style: TextStyle(fontSize: 16.0),
              ),
            ),
            SizedBox(height: 10),
          ],
        ),
        Divider(),
      ],
    );
  }
}
