import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobil1/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanıcı durumu stream'i
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Şu anki kullanıcı
  User? get currentUser => _auth.currentUser;

  // Kullanıcı bilgilerini al
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirebase(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Kullanıcı bilgilerini güncelle (İsim ve Avatar)
  Future<void> updateUserProfile({String? displayName, String? avatar}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final updates = <String, dynamic>{};
      if (displayName != null) {
        updates['displayName'] = displayName;
        await user.updateDisplayName(displayName);
      }
      if (avatar != null) {
        updates['avatar'] = avatar;
        // Firebase Auth profil fotosu url veya null olabilir, avatar özel bir string ise buraya yazamayabiliriz,
        // ama firestore'a yazarız.
        // await user.updatePhotoURL(avatar); 
        // Not: PhotoURL url formatında olmalı, bizim avatar "🐶" gibi emoji olabilir. O yüzden Auth'a yazmıyoruz.
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updates);
      }
    } catch (e) {
      print('Update profile error: $e');
      rethrow;
    }
  }

  // Kayıt ol
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // Firebase Authentication ile kayıt
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Kullanıcı bilgilerini Firestore'a kaydet
      if (credential.user != null) {
        final userData = UserModel(
          uid: credential.user!.uid,
          email: email,
          displayName: displayName,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(userData.toMap());

        // Display name'i Firebase Auth'a da kaydet
        await credential.user!.updateDisplayName(displayName);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      print('Sign up error: ${e.code}');
      rethrow;
    } catch (e) {
      print('Sign up error: $e');
      rethrow;
    }
  }

  // Giriş yap
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.code}');
      rethrow;
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  // Şifre sıfırlama e-postası gönder
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.code}');
      rethrow;
    } catch (e) {
      print('Password reset error: $e');
      rethrow;
    }
  }

  // Hata mesajlarını Türkçe'ye çevir
  String getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Lütfen daha sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok.';
      default:
        return 'Bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }
}
