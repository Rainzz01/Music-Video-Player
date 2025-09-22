import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_auth/local_auth.dart';
import '../components/my_drawer.dart';
import '../components/neu_box.dart';
import '../theme/theme_provider.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  String? _profileImageUrl;
  bool _isLoading = false;
  bool _advancedModeEnabled = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Load user profile data from Firestore
  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view your profile.')),
      );
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _nameController.text = userDoc.data()?['name'] ?? user.displayName ?? '';
        _profileImageUrl = userDoc.data()?['photoURL'] ?? user.photoURL;
        _advancedModeEnabled = userDoc.data()?['advancedModeEnabled'] ?? false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  // Request permission for photos
  Future<bool> _requestPhotoPermission() async {
    final photoStatus = await Permission.photos.request();
    if (photoStatus.isGranted) {
      return true;
    }
    if (photoStatus.isPermanentlyDenied) {
      await openAppSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable photo access in settings.'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo permission is required to upload a profile picture.')),
      );
    }
    return false;
  }

  // Upload profile picture to Firebase Storage with retry logic
  Future<String?> _uploadProfilePicture(String filePath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to upload a profile picture.')),
      );
      return null;
    }

    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 500);
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(File(filePath));
        return await storageRef.getDownloadURL();
      } catch (e) {
        attempt++;
        if (e.toString().contains('unauthorized')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unauthorized: Please ensure you are logged in and have permission to upload.'),
            ),
          );
          return null;
        }
        if (attempt >= maxRetries) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image after $maxRetries attempts: $e')),
          );
          return null;
        }
        await Future.delayed(retryDelay * attempt);
      }
    }
    return null;
  }

  // Save profile changes
  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to update your profile.')),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid name (1-50 characters).')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await user.updateDisplayName(name);
      await user.updatePhotoURL(_profileImageUrl ?? user.photoURL ?? '');

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'name': name,
          'photoURL': _profileImageUrl ?? user.photoURL ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
          'uid': user.uid,
          'email': user.email ?? '',
          'provider': 'email',
        },
        SetOptions(merge: true),
      );

      await user.reload();
      setState(() {
        _profileImageUrl = FirebaseAuth.instance.currentUser?.photoURL;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      String message = 'Failed to update profile: $e';
      if (e.toString().contains('not-found')) {
        message = 'Profile document not found. Please try again or contact support.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Pick profile picture
  Future<void> _pickProfilePicture() async {
    if (!await _requestPhotoPermission()) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      final imageUrl = await _uploadProfilePicture(result.files.single.path!);
      if (imageUrl != null) {
        setState(() => _profileImageUrl = imageUrl);
      }
      setState(() => _isLoading = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image selected')),
      );
    }
  }

  // Toggle Advanced Mode with fingerprint authentication for enabling
  Future<void> _toggleAdvancedMode(bool value) async {
    if (_isLoading || FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to manage Advanced Mode.')),
      );
      return;
    }

    if (value) {
      try {
        final canAuthenticate = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
        if (!canAuthenticate) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fingerprint authentication is not available on this device.')),
          );
          return;
        }

        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        final isFingerprintAvailable = availableBiometrics.contains(BiometricType.fingerprint);
        final isFaceAvailable = availableBiometrics.contains(BiometricType.face);

        String localizedReason = 'Scan your fingerprint to enable Advanced Mode in MusicVerse';
        if (isFaceAvailable && !isFingerprintAvailable) {
          localizedReason = 'Use Face ID to enable Advanced Mode in MusicVerse';
        }

        final authenticated = await _localAuth.authenticate(
          localizedReason: localizedReason,
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        if (!authenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication failed. Please try again.')),
          );
          return;
        }
      } catch (e) {
        String message = 'Failed to authenticate: $e';
        if (e.toString().contains('no_fragment_activity')) {
          message = 'Authentication is not supported due to a configuration issue. Please contact support.';
        } else if (e.toString().contains('not_enrolled')) {
          message = 'No biometric credentials are enrolled on this device.';
        } else if (e.toString().contains('locked_out')) {
          message = 'Biometric authentication is temporarily locked out. Try again later.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      await _authService.enableAdvancedMode(value, context);
      setState(() => _advancedModeEnabled = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Advanced Mode ${value ? 'enabled' : 'disabled'} successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update Advanced Mode: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "S E T T I N G S",
          style: GoogleFonts.raleway(
            textStyle: TextStyle(
              color: Theme.of(context).colorScheme.inversePrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      drawer: const MyDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // Profile Section
              NeuBox(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Profile',
                        style: GoogleFonts.raleway(
                          textStyle: TextStyle(
                            color: Theme.of(context).colorScheme.inversePrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: GestureDetector(
                          onTap: _isLoading || user == null ? null : _pickProfilePicture,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: _profileImageUrl != null
                                    ? NetworkImage(_profileImageUrl!)
                                    : (user?.photoURL != null
                                    ? NetworkImage(user!.photoURL!)
                                    : const AssetImage('assets/images/default_profile.png')
                                as ImageProvider),
                                child: _profileImageUrl == null && user?.photoURL == null
                                    ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Theme.of(context).colorScheme.secondary,
                                )
                                    : null,
                              ),
                              if (_isLoading)
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.inversePrimary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Name',
                        style: GoogleFonts.raleway(
                          textStyle: TextStyle(
                            color: Theme.of(context).colorScheme.inversePrimary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          hintText: 'Enter your name',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        style: GoogleFonts.raleway(
                          textStyle: TextStyle(
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                        enabled: !_isLoading && user != null,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading || user == null ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff0D6EFD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                          'Save Profile',
                          style: GoogleFonts.raleway(
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Advanced Mode Section
              NeuBox(
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Advanced Mode',
                        style: GoogleFonts.raleway(
                          textStyle: TextStyle(
                            color: Theme.of(context).colorScheme.inversePrimary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Switch(
                        value: _advancedModeEnabled,
                        onChanged: _isLoading || user == null ? null : _toggleAdvancedMode,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Dark Mode Section
              NeuBox(
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Dark Mode',
                        style: GoogleFonts.raleway(
                          textStyle: TextStyle(
                            color: Theme.of(context).colorScheme.inversePrimary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Switch(
                        value: Provider.of<ThemeProvider>(context).isDarkMode,
                        onChanged: (value) =>
                            Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}