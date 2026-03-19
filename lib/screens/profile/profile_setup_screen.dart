import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tuchat/providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUser = context.read<AuthProvider>().currentUser;
    if (_usernameController.text.isEmpty && currentUser != null) {
      _usernameController.text = currentUser.username;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageName = image.name;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    authProvider.clearError();

    try {
      await authProvider.completeProfile(
        username: _usernameController.text.trim(),
        profileImageBytes: _selectedImageBytes,
        profileImageName: _selectedImageName,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully.')),
      );

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Profile setup failed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final ImageProvider<Object>? profileImage = _selectedImageBytes != null
        ? MemoryImage(_selectedImageBytes!)
        : (currentUser?.profilePicUrl.isNotEmpty == true
              ? NetworkImage(currentUser!.profilePicUrl)
              : null);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentUser?.isProfileComplete == true
              ? 'Edit Profile'
              : 'Profile Setup',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      currentUser?.isProfileComplete == true
                          ? 'Update your TuChat profile.'
                          : 'Choose your username and photo to finish setting up your profile.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 54,
                            backgroundImage: profileImage,
                            child:
                                _selectedImageBytes == null &&
                                    (currentUser?.profilePicUrl.isEmpty ?? true)
                                ? const Icon(Icons.person, size: 54)
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: FilledButton(
                              onPressed: _pickImage,
                              style: FilledButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(12),
                              ),
                              child: const Icon(Icons.camera_alt),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'e.g. alex_ken',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        final username = value?.trim() ?? '';
                        if (username.isEmpty) {
                          return 'Enter a username.';
                        }
                        if (username.length < 3 || username.length > 20) {
                          return 'Username must be 3-20 characters.';
                        }
                        final usernameRegex = RegExp(r'^[a-zA-Z0-9._]+$');
                        if (!usernameRegex.hasMatch(username)) {
                          return 'Use only letters, numbers, dots, or underscores.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: authProvider.isBusy ? null : _submit,
                        child: authProvider.isBusy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Text('Save Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
