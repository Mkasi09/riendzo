import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

class PostCreationScreen extends StatefulWidget {
  final List<XFile> media;

  const PostCreationScreen({super.key, required this.media});

  @override
  State<PostCreationScreen> createState() => _PostCreationScreenState();
}

class _PostCreationScreenState extends State<PostCreationScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<XFile> _selectedMedia = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final Map<String, VideoPlayerController> _videoControllers = {};

  bool _isPosting = false;
  String _postingStatus = '';

  @override
  void initState() {
    super.initState();
    _selectedMedia.addAll(widget.media);
    _initializeVideoControllers();
  }

  @override
  void dispose() {
    _textController.dispose();
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    VideoCompress.cancelCompression();
    super.dispose();
  }

  Future<void> _initializeVideoControllers() async {
    for (final file in _selectedMedia.where(_isVideo)) {
      if (_videoControllers.containsKey(file.path)) continue;
      final controller = VideoPlayerController.file(File(file.path));
      _videoControllers[file.path] = controller;
      await controller.initialize();
    }
    if (mounted) setState(() {});
  }

  bool _isVideo(XFile file) {
    final path = file.path.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v') ||
        path.endsWith('.webm') ||
        path.endsWith('.avi');
  }

  Future<File> _compressImage(File file) async {
    final filePath = file.absolute.path;
    final extension = filePath.split('.').last;
    final targetPath = filePath.replaceFirst('.$extension', '_compressed.jpg');
    final compressedImage = await FlutterImageCompress.compressAndGetFile(
      filePath,
      targetPath,
      quality: 72,
      minWidth: 1280,
      minHeight: 1280,
    );
    return File(compressedImage?.path ?? file.path);
  }

  Future<File> _compressVideo(File file) async {
    final mediaInfo = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.LowQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    final compressedFile = mediaInfo?.file;
    if (compressedFile == null || !await compressedFile.exists()) {
      throw Exception(
        'Video could not be compressed. Please try another video.',
      );
    }
    return compressedFile;
  }

  void _setPostingStatus(String status) {
    if (!mounted) return;
    setState(() => _postingStatus = status);
  }

  Future<_UploadedMedia?> _uploadFileToStorage(XFile file) async {
    final isVideo = _isVideo(file);
    File mediaFile = File(file.path);

    try {
      _setPostingStatus(
        isVideo ? 'Compressing video...' : 'Preparing photo...',
      );

      if (isVideo) {
        mediaFile = await _compressVideo(mediaFile);
      } else {
        mediaFile = await _compressImage(mediaFile);
      }

      _setPostingStatus('Uploading media...');

      final extension = isVideo ? 'mp4' : 'jpg';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _firebaseStorage.ref().child('posts/$timestamp.$extension');

      final metadata = SettableMetadata(
        cacheControl: 'public,max-age=31536000',
        contentType: isVideo ? 'video/mp4' : 'image/jpeg',
        customMetadata: {
          'mediaType': isVideo ? 'video' : 'image',
          'compressed': 'true',
        },
      );

      final uploadTask = ref.putFile(mediaFile, metadata);
      final taskSnapshot = await uploadTask;
      final url = await taskSnapshot.ref.getDownloadURL();

      return _UploadedMedia(url: url, type: isVideo ? 'video' : 'image');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not upload media: $e')));
      }
      return null;
    }
  }

  Future<void> _addPostToFirebase(List<_UploadedMedia> media) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await _firestore.collection('posts').add({
      'content': _textController.text.trim(),
      'mediaUrls': media.map((item) => item.url).toList(),
      'mediaTypes': media.map((item) => item.type).toList(),
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
      'likeCount': 0,
    });
  }

  Future<void> _addPost() async {
    if (_textController.text.trim().isEmpty && _selectedMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something or select media.')),
      );
      return;
    }

    setState(() {
      _isPosting = true;
      _postingStatus = 'Starting upload...';
    });

    final uploadedMedia = <_UploadedMedia>[];
    for (final media in _selectedMedia) {
      final uploaded = await _uploadFileToStorage(media);
      if (uploaded == null) {
        if (mounted) {
          setState(() {
            _isPosting = false;
            _postingStatus = '';
          });
        }
        return;
      }
      uploadedMedia.add(uploaded);
    }

    await _addPostToFirebase(uploadedMedia);

    if (!mounted) return;
    setState(() {
      _isPosting = false;
      _postingStatus = '';
      _selectedMedia.clear();
    });
    Navigator.pop(context);
  }

  Future<void> _pickImages() async {
    if (_selectedMedia.length >= 5) {
      _showLimitMessage();
      return;
    }

    final pickedFiles = await _picker.pickMultiImage();
    setState(() {
      _selectedMedia.addAll(pickedFiles.take(5 - _selectedMedia.length));
    });
    await _initializeVideoControllers();
  }

  Future<void> _pickVideo() async {
    if (_selectedMedia.length >= 5) {
      _showLimitMessage();
      return;
    }

    final pickedFile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (pickedFile == null) return;

    setState(() => _selectedMedia.add(pickedFile));
    await _initializeVideoControllers();
  }

  void _showLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You can upload up to 5 items only.')),
    );
  }

  void _removeMedia(int index) {
    final file = _selectedMedia[index];
    _videoControllers.remove(file.path)?.dispose();
    setState(() => _selectedMedia.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 16),
            if (_selectedMedia.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedMedia.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final file = _selectedMedia[index];
                  return _MediaPreview(
                    file: file,
                    isVideo: _isVideo(file),
                    controller: _videoControllers[file.path],
                    onRemove: () => _removeMedia(index),
                  );
                },
              ),
            const SizedBox(height: 16),
            if (_isPosting && _postingStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _postingStatus,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPosting ? null : _addPost,
                    icon: _isPosting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_isPosting ? 'Posting...' : 'Post'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Add photos',
                  icon: const Icon(Icons.photo_outlined),
                  onPressed: _isPosting ? null : _pickImages,
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Add video',
                  icon: const Icon(Icons.videocam_outlined),
                  onPressed: _isPosting ? null : _pickVideo,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  final XFile file;
  final bool isVideo;
  final VideoPlayerController? controller;
  final VoidCallback onRemove;

  const _MediaPreview({
    required this.file,
    required this.isVideo,
    required this.controller,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isVideo)
            _VideoPreview(controller: controller)
          else
            Image.file(File(file.path), fit: BoxFit.cover),
          Positioned(
            right: 6,
            top: 6,
            child: IconButton.filled(
              icon: const Icon(Icons.close_rounded),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  final VideoPlayerController? controller;

  const _VideoPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: const Center(child: Icon(Icons.videocam_rounded, size: 42)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller!.value.size.width,
            height: controller!.value.size.height,
            child: VideoPlayer(controller!),
          ),
        ),
        const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
      ],
    );
  }
}

class _UploadedMedia {
  final String url;
  final String type;

  const _UploadedMedia({required this.url, required this.type});
}
