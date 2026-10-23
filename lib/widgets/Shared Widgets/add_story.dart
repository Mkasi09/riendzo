import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import for image picking

class AddStoryPopup extends StatefulWidget {
  final File imageFile;

  const AddStoryPopup({super.key, required this.imageFile});

  @override
  State<AddStoryPopup> createState() => _AddStoryPopupState();
}

class _AddStoryPopupState extends State<AddStoryPopup> {
  final TextEditingController _captionController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late File _imageFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.imageFile;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  // Function to post the story
  Future<void> _postStory() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showMessage('Sign in to post a story.');
      return;
    }
    if (_isUploading) return;
    setState(() {
      _isUploading = true;
    });

    try {
      final imageUrl = await _addPictureStory(_imageFile);

      await FirebaseFirestore.instance.collection('stories').add({
        'type': 'image',
        'content': imageUrl,
        'caption': _captionController.text.trim(),
        'userId': user.uid,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showMessage(
        'Your story could not be posted. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Upload image to Firebase Storage and return the download URL
  Future<String> _addPictureStory(File image) async {
    FirebaseStorage storage = FirebaseStorage.instance;
    Reference ref = storage.ref().child(
      'stories/${_auth.currentUser!.uid}/${DateTime.now().microsecondsSinceEpoch}.jpg',
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

    if (pickedFile != null && mounted) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101114),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: _isUploading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'New story',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isUploading ? null : _changePhoto,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Change'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Center(
                  child: Image.file(
                    _imageFile,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1C1D21),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _captionController,
                    enabled: !_isUploading,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 180,
                    decoration: InputDecoration(
                      labelText: 'Caption',
                      hintText: 'Add something about your story',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintStyle: const TextStyle(color: Colors.white38),
                      counterStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.short_text,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _isUploading ? null : _postStory,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_isUploading ? 'Posting story…' : 'Post story'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
