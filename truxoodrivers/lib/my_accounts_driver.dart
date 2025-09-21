import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';

class MyAccountDriver extends StatefulWidget {
  final String? currentProfileImagePath;
  final bool isLocalImage;
  final String driverName;
  final String driverPhone;
  final String driverEmail;
  final String driverRating;
  final String truckNumber;
  final String truckType;
  final String truckCapacity;
  final String licenseNumber;
  final String licenseExpiry;

  const MyAccountDriver({
    Key? key,
    this.currentProfileImagePath,
    required this.isLocalImage,
    required this.driverName,
    required this.driverPhone,
    required this.driverEmail,
    required this.driverRating,
    required this.truckNumber,
    required this.truckType,
    required this.truckCapacity,
    required this.licenseNumber,
    required this.licenseExpiry,
  }) : super(key: key);

  @override
  State<MyAccountDriver> createState() => _MyAccountDriverState();
}

class _MyAccountDriverState extends State<MyAccountDriver> {
  late String _driverName;
  late String _driverPhone;
  late String _driverEmail;
  late String _driverRating;
  late String _truckNumber;
  late String _truckType;
  late String _truckCapacity;
  late String _licenseNumber;
  late String _licenseExpiry;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _truckNumberController;
  late TextEditingController _truckTypeController;
  late TextEditingController _truckCapacityController;
  late TextEditingController _licenseNumberController;
  late TextEditingController _licenseExpiryController;

  File? _newProfileImage;
  bool _isEditingProfile = false;
  bool _isEditingTruck = false;

  final String _defaultProfilePicture = 'assets/driver_image.webp';

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);

    _driverName = widget.driverName;
    _driverPhone = widget.driverPhone;
    _driverEmail = widget.driverEmail;
    _driverRating = widget.driverRating;
    _truckNumber = widget.truckNumber;
    _truckType = widget.truckType;
    _truckCapacity = widget.truckCapacity;
    _licenseNumber = widget.licenseNumber;
    _licenseExpiry = widget.licenseExpiry;

    _nameController = TextEditingController(text: _driverName);
    _emailController = TextEditingController(text: _driverEmail);
    _phoneController = TextEditingController(text: _driverPhone);
    _truckNumberController = TextEditingController(text: _truckNumber);
    _truckTypeController = TextEditingController(text: _truckType);
    _truckCapacityController = TextEditingController(text: _truckCapacity);
    _licenseNumberController = TextEditingController(text: _licenseNumber);
    _licenseExpiryController = TextEditingController(text: _licenseExpiry);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _truckNumberController.dispose();
    _truckTypeController.dispose();
    _truckCapacityController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (_isEditingProfile || _isEditingTruck) {
      _showUnsavedChangesDialog();
      return true;
    }
    Navigator.of(context).pop();
    return true;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _newProfileImage = File(pickedImage.path);
      });
    }
  }

  void _saveProfileChanges() {
    setState(() {
      _isEditingProfile = false;
      _driverName = _nameController.text;
      _driverEmail = _emailController.text;
      _driverPhone = _phoneController.text;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _saveTruckChanges() {
    setState(() {
      _isEditingTruck = false;
      _truckNumber = _truckNumberController.text;
      _truckType = _truckTypeController.text;
      _truckCapacity = _truckCapacityController.text;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Truck details updated successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _showUnsavedChangesDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('You have unsaved changes. Do you want to discard them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (_isEditingProfile) _saveProfileChanges();
                if (_isEditingTruck) _saveTruckChanges();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileField(
    String label,
    String value,
    TextEditingController? controller,
    bool isEditing, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
                color: Colors.grey[600],
              )),
          const SizedBox(height: 4),
          isEditing && controller != null
              ? TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isLargeScreen ? 16 : 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(fontSize: isLargeScreen ? 16 : 14),
                )
              : Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isLargeScreen ? 16 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(fontSize: isLargeScreen ? 16 : 14),
                  ),
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    final ImageProvider<Object> imageProvider = _newProfileImage != null
        ? FileImage(_newProfileImage!) as ImageProvider<Object>
        : widget.currentProfileImagePath != null
            ? (widget.isLocalImage
                ? FileImage(File(widget.currentProfileImagePath!)) as ImageProvider<Object>
                : NetworkImage(widget.currentProfileImagePath!) as ImageProvider<Object>)
            : AssetImage(_defaultProfilePicture) as ImageProvider<Object>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: isLargeScreen ? 60 : 50,
                    backgroundImage: imageProvider,
                    backgroundColor: Colors.grey[200],
                  ),
                  if (_isEditingProfile)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: isLargeScreen ? 24 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Profile Information',
                    style: TextStyle(
                        fontSize: isLargeScreen ? 20 : 18,
                        fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(_isEditingProfile ? Icons.save : Icons.edit, color: Colors.blue),
                  onPressed: () {
                    if (_isEditingProfile) {
                      _saveProfileChanges();
                    } else {
                      setState(() {
                        _isEditingProfile = true;
                      });
                    }
                  },
                )
              ],
            ),
            _buildProfileField('Name', _driverName, _nameController, _isEditingProfile),
            _buildProfileField('Phone', _driverPhone, _phoneController, _isEditingProfile,
                keyboardType: TextInputType.phone),
            _buildProfileField('Email', _driverEmail, _emailController, _isEditingProfile,
                keyboardType: TextInputType.emailAddress),
            _buildProfileField('Rating', _driverRating, null, false),
            SizedBox(height: isLargeScreen ? 32 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Truck Details',
                    style: TextStyle(
                        fontSize: isLargeScreen ? 20 : 18,
                        fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(_isEditingTruck ? Icons.save : Icons.edit, color: Colors.blue),
                  onPressed: () {
                    if (_isEditingTruck) {
                      _saveTruckChanges();
                    } else {
                      setState(() {
                        _isEditingTruck = true;
                      });
                    }
                  },
                )
              ],
            ),
            _buildProfileField('Truck Number', _truckNumber, _truckNumberController, _isEditingTruck),
            _buildProfileField('Truck Type', _truckType, _truckTypeController, _isEditingTruck),
            _buildProfileField('Capacity', _truckCapacity, _truckCapacityController, _isEditingTruck),
            SizedBox(height: isLargeScreen ? 32 : 16),
            Text('License Details',
                style: TextStyle(
                  fontSize: isLargeScreen ? 20 : 18,
                  fontWeight: FontWeight.bold,
                )),
            _buildProfileField('License Number', _licenseNumber, _licenseNumberController, false),
            _buildProfileField('Expiry Date', _licenseExpiry, _licenseExpiryController, false),
          ],
        ),
      ),
    );
  }
}
