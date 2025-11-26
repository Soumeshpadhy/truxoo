import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseDriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload image to Firebase Storage
  Future<String?> uploadImage(File imageFile, String mobileNumber, String imageName) async {
    try {
      final path = 'drivers/$mobileNumber/$imageName';
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image $imageName: $e');
      return null;
    }
  }

  // Register driver in Firestore
  Future<bool> registerDriver(Map<String, dynamic> driverData, String mobileNumber) async {
    try {
      await _firestore.collection('drivers').doc(mobileNumber).set(driverData);
      return true;
    } catch (e) {
      print('Error registering driver: $e');
      return false;
    }
  }

  // Check if driver already exists
  Future<bool> driverExists(String mobileNumber) async {
    try {
      final doc = await _firestore.collection('drivers').doc(mobileNumber).get();
      return doc.exists;
    } catch (e) {
      print('Error checking driver existence: $e');
      return false;
    }
  }

  // Get driver data
  Future<Map<String, dynamic>?> getDriverData(String mobileNumber) async {
    try {
      final doc = await _firestore.collection('drivers').doc(mobileNumber).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting driver data: $e');
      return null;
    }
  }

  // Update driver status
  Future<bool> updateDriverStatus(String mobileNumber, String status) async {
    try {
      await _firestore.collection('drivers').doc(mobileNumber).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating driver status: $e');
      return false;
    }
  }

  // Delete driver images from storage
  Future<void> deleteDriverImages(String mobileNumber) async {
    try {
      final ref = _storage.ref().child('drivers/$mobileNumber');
      final listResult = await ref.listAll();
      
      for (var item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      print('Error deleting driver images: $e');
    }
  }

  // Delete driver from Firestore
  Future<bool> deleteDriver(String mobileNumber) async {
    try {
      // Delete images first
      await deleteDriverImages(mobileNumber);
      
      // Delete Firestore document
      await _firestore.collection('drivers').doc(mobileNumber).delete();
      return true;
    } catch (e) {
      print('Error deleting driver: $e');
      return false;
    }
  }
}