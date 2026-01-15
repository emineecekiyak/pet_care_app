
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  Future<String?> uploadPetImage(File file) async {
    if (_userId == null) return null;

    try {
      final fileName = path.basename(file.path);
      final uniqueName = "${DateTime.now().millisecondsSinceEpoch}_$fileName";
      
      // Path: users/{userId}/pets/{uniqueName}
      final ref = _storage.ref().child('users/$_userId/pets/$uniqueName');
      
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print("Storage Upload Error: $e");
      return null;
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Image already deleted or invalid URL, ignore
      print("Delete Error: $e");
    }
  }
}
