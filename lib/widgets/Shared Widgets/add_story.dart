import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import for image picking

class AddStoryPopup extends StatefulWidget {
  File imageFile;

  AddStoryPopup({super.key, required this.imageFile});

  @override
  _AddStoryPopupState createState() => _AddStoryPopupState();
}

class _AddStoryPopupState extends State<AddStoryPopup> {
  final TextEditingController _captionController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'stories',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isUploading = false;

  // Function to post the story
  Future<void> _postStory() async {
    setState(() {
      _isUploading = true;
    });

    try {
      // Upload the image to Firebase Storage and get the download URL
      String imageUrl = await _addPictureStory(widget.imageFile);

      // Save the story to Firestore
      await FirebaseFirestore.instance.collection('stories').add({
        'type': 'image',
        'content': imageUrl, // Save the image URL
        'caption': _captionController.text, // Save the caption
        'userId': _auth.currentUser?.uid ?? '', // Save the user ID
        'timestamp':
            DateTime.now().millisecondsSinceEpoch, // Save the timestamp
      });

      // Close the popup after posting
      Navigator.of(context).pop();
    } catch (e) {
      print('Error posting story: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  // Upload image to Firebase Storage and return the download URL
  Future<String> _addPictureStory(File image) async {
    FirebaseStorage storage = FirebaseStorage.instance;
    Reference ref = storage.ref().child(
      "stories/${DateTime.now().millisecondsSinceEpoch}.jpg",
    );
    SettableMetadata metadata = SettableMetadata(
      cacheControl: 'max-age=60',
      contentType: 'image/jpeg',
    );

    UploadTask uploadTask = ref.putFile(image, metadata);
    TaskSnapshot taskSnapshot = await uploadTask;
    return await taskSnapshot.ref.getDownloadURL();
  }

  // Function to change the photo
  Future<void> _changePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        widget.imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.8),
      resizeToAvoidBottomInset:
          true, // Ensures UI adjusts when keyboard appears
      body: SafeArea(
        child: Stack(
          children: [
            // Top row: Cancel and Edit buttons
            Positioned(
              top: 30,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cancel button (closes the popup)
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    iconSize: 30,
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the popup
                    },
                  ),
                  // Edit button (allows to change the photo)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    iconSize: 30,
                    onPressed: _changePhoto, // Change the image
                  ),
                ],
              ),
            ),

            // Center the image and shift it 2 inches down
            Center(
              child: Positioned.fill(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment
                          .center, // Center the content vertically
                      children: [
                        Center(
                          child: Image.file(
                            widget.imageFile,
                            fit: BoxFit
                                .contain, // Maintain aspect ratio without cropping
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Caption input overlaid at the bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(
                    context,
                  ).viewPadding.bottom, // Adjust padding when keyboard is open
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(
                      0.8,
                    ), // Semi-transparent black background
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white), // White text
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      suffixIcon: _isUploading
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed:
                                  _postStory, // Post the story when icon is pressed
                            ),
                    ),
                    maxLines: null, // Allow multiline captions
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
