import 'package:flutter/material.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contact Us'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Text
            Text(
              "We’d love to hear from you! Whether you have a question, need assistance, or just want to share your travel stories with us, feel free to reach out. Our team is here to make your Riendzo experience seamless and enjoyable.",
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 20),

            // Get In Touch Section
            Text(
              "Get In Touch",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
            ),
            SizedBox(height: 10),

            contactSection(
              "Customer Support",
              "Have a question or need help with your bookings? Our support team is ready to assist you.",
              "support@riendzo.com",
              "+1 (800) 123-4567",
              "Monday – Friday: 9:00 AM – 6:00 PM (GMT)",
            ),
            Divider(),

            contactSection(
              "Business Inquiries",
              "Interested in collaborating with Riendzo? We’re always looking for partners in the travel industry.",
              "business@riendzo.com",
              null,
              "Monday – Friday: 9:00 AM – 6:00 PM (GMT)",
            ),
            Divider(),

            contactSection(
              "Media and Press",
              "For media inquiries, interviews, or press coverage, please contact our press team.",
              "media@riendzo.com",
              null,
              "Monday – Friday: 9:00 AM – 6:00 PM (GMT)",
            ),

            SizedBox(height: 20),

            // Contact Form Section
            Text(
              "Send Us a Message",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
            ),
            SizedBox(height: 10),
            buildStyledContactForm(),

            SizedBox(height: 20),

            // Office Information Section
            Text(
              "Our Office",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
            ),
            SizedBox(height: 10),
            Text(
              "Want to visit us in person? We’d be happy to welcome you!",
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 10),
            Text(
              "📍 Address:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Riendzo Headquarters\n123 Traveler’s Lane,\nAdventure City, AC 45678,\nCountry",
              style: TextStyle(fontSize: 16.0),
            ),

            SizedBox(height: 20),

            // Social Media Section
            Text(
              "Stay Connected",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                socialIcon(Icons.facebook, "Facebook"),
                socialIcon(Icons.photo_camera, "Instagram"),
                socialIcon(Icons.camera, "Twitter"),
                socialIcon(Icons.business, "LinkedIn"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Method to build the contact section
  Widget contactSection(
      String title, String description, String email, String? phone, String hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        ),
        SizedBox(height: 5),
        Text(
          description,
          style: TextStyle(fontSize: 16.0),
        ),
        SizedBox(height: 5),
        Text("📧 Email: $email", style: TextStyle(fontSize: 16.0)),
        if (phone != null)
          Text("📞 Phone: $phone", style: TextStyle(fontSize: 16.0)),
        Text("📍 Office Hours: $hours", style: TextStyle(fontSize: 16.0)),
      ],
    );
  }

  // Styled Contact Form
  Widget buildStyledContactForm() {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(

        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          buildStyledTextField("Name"),
          SizedBox(height: 15),
          buildStyledTextField("Email"),
          SizedBox(height: 15),
          buildStyledTextField("Subject"),
          SizedBox(height: 15),
          buildStyledTextField("Message", maxLines: 5),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Submit button logic
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              "Submit",
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Method to create a styled text input field
  Widget buildStyledTextField(String labelText, {int maxLines = 1}) {
    return TextField(
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          fontSize: 16.0,
          color: Colors.grey[800],
        ),
        filled: true,
        fillColor: Colors.grey[100],
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(10.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blueAccent, width: 2),
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      maxLines: maxLines,
    );
  }

  // Method to create social media icons
  Widget socialIcon(IconData icon, String tooltip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, size: 30),
      ),
    );
  }
}
