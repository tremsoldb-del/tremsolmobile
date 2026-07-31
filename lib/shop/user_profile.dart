import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _shippingAddressController =
      TextEditingController();

  String profilePicUrl = ""; // URL to display the profile picture
  File? _selectedImage; // Selected image file
  late final String userId;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid; // Get current user UID
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _fullNameController.text = userData?['fullname'] ?? "";
          _emailController.text = userData?['email'] ?? "";
          _phoneController.text = userData?['phone'] ?? "";
          _usernameController.text = userData?['username'] ?? "";
          _shippingAddressController.text = userData?['shippingaddress'] ?? "";
          profilePicUrl = userData?['profilepic'] ?? "";
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
    }
  }

  /*Future<void> _pickProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(context: context, builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("Take a photo"),
            onTap: () async {
              final XFile? image = await picker.pickImage(source: ImageSource.camera);
              Navigator.pop(context, image);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text("Choose from gallery"),
            onTap: () async {
              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
              Navigator.pop(context, image);
            },
          ),
        ],
      );
    });

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path); // Save the selected image file
      });
    }
  }*/



Future<void> _pickProfilePicture() async {
  final ImagePicker picker = ImagePicker();

  // Step 1: Pick image from gallery
  final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery);
  if (pickedImage == null) return;

  // Step 2: Crop to square aspect ratio
  final CroppedFile? croppedFile = await ImageCropper().cropImage(
    sourcePath: pickedImage.path,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop Image',
        toolbarColor: const Color(0xFF002A5C),
        toolbarWidgetColor: Colors.white,
        initAspectRatio: CropAspectRatioPreset.square,
        lockAspectRatio: true,
      ),
      IOSUiSettings(
        title: 'Crop Image',
        aspectRatioLockEnabled: true,
      ),
    ],
  );

  // Step 3: Save the result if cropping wasn't canceled
  if (croppedFile != null) {
    _selectedImage = File(croppedFile.path);
    // If this is inside a StatefulWidget, call setState()
  }
}

  Future<String> _uploadProfilePicture(File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('tremsol/${userId}_profilepic.jpg');
      final uploadTask = await storageRef.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading profile picture: $e");
      rethrow;
    }
  }

  Future<void> _updateUserProfile() async {
    // Trim input values
    String fullName = _fullNameController.text.trim();
    String phone = _phoneController.text.trim();
    String username = _usernameController.text.trim();
    String shippingAddress = _shippingAddressController.text.trim();

    // Validation checks
    if (fullName.isEmpty) {
      _showError("Full Name cannot be empty.");
      return;
    }
    if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(fullName)) {
      _showError("Full Name can only contain letters and spaces.");
      return;
    }

    if (phone.isEmpty) {
      _showError("Phone number cannot be empty.");
      return;
    }
    if (!RegExp(r"^\d{10,15}$").hasMatch(phone)) {
      _showError("Enter a valid phone number (10-15 digits).");
      return;
    }

    if (username.isEmpty) {
      _showError("Username cannot be empty.");
      return;
    }
    if (!RegExp(r"^[a-zA-Z0-9._]+$").hasMatch(username)) {
      _showError("Username can only contain letters, numbers, underscores, or dots.");
      return;
    }

    if (shippingAddress.isEmpty) {
      _showError("Shipping Address cannot be empty.");
      return;
    }

    try {
      // Upload profile picture if a new one is selected
      if (_selectedImage != null) {
        profilePicUrl = await _uploadProfilePicture(_selectedImage!);
      }

      // Update Firestore document
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fullname': fullName,
        'phone': phone,
        'username': username,
        'shippingaddress': shippingAddress,
        'profilepic': profilePicUrl,
      });

      // Show success message
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Profile Updated"),
          content: const Text("Your profile has been successfully updated."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      print("Error updating profile: $e");
      _showError("An error occurred while updating your profile. Please try again.");
    }
  }

  // Delete user profile
 Future<void> _deleteUserProfile() async {
  // Show confirmation dialog
  bool? confirmDelete = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text("Are you sure you want to delete your profile? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      );
    },
  );

  if (confirmDelete == true) {
    try {
      // Log the profile deletion in the audit_trail collection
      await FirebaseFirestore.instance.collection('audit_trail').add({
        'product_id': 'deleted_user_profile',
        'details': {
          'user_id': userId,
          'deleted_at': Timestamp.now(),
          'reason': 'User requested account deletion', // Customize this if needed
        },
        'timestamp': Timestamp.now(),
        'user_id': FirebaseAuth.instance.currentUser!.uid, // UID of the user who deleted the profile
        'action': 'profile_deletion',
      });

      // Delete user's Firestore data
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      // Delete the user's authentication profile
      await FirebaseAuth.instance.currentUser!.delete();

      // Show success message after deletion
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Profile Deleted"),
          content: const Text("Your profile has been successfully deleted."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Redirect to the sign-in page after deletion
                Navigator.pushReplacementNamed(context, '/signin');
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      print("Error deleting profile: $e");
      _showError("An error occurred while deleting your profile. Please try again.");
    }
  }
}

  // Function to display error messages
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("My Profile", style: TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView( 
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickProfilePicture,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : (profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null) as ImageProvider?,
                child: (_selectedImage == null && profilePicUrl.isEmpty)
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            const Text("Tap to change profile picture", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            _buildTextField("Full Name", _fullNameController, Icons.person),
            const SizedBox(height: 16),
            _buildTextField("Email", _emailController, Icons.email, readOnly: true),
            const SizedBox(height: 16),
            _buildTextField("Phone", _phoneController, Icons.phone),
            const SizedBox(height: 16),
            _buildTextField("Username", _usernameController, Icons.person_outline),
            const SizedBox(height: 16),
            _buildTextField("Address", _shippingAddressController, Icons.location_on),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _updateUserProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002A5C),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              child: const Text("Save Changes", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _deleteUserProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              child: const Text("Delete Profile", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool readOnly = false}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
