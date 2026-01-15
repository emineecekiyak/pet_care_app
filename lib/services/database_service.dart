import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobil1/models/pet.dart';
import 'package:mobil1/models/vaccine.dart';
import 'package:mobil1/models/appointment.dart';
import 'package:mobil1/models/food_entry.dart';

class DatabaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _uidOverride;

  DatabaseService({String? uid}) : _uidOverride = uid;

  // Helpers
  String? get _userId => _uidOverride ?? _auth.currentUser?.uid;

  CollectionReference _userCollection() {
    if (_userId == null) {
      throw Exception("Kullanıcı giriş yapmamış!");
    }
    return _firestore.collection('users').doc(_userId).collection('pets');
  }
  
  // ------------- PETS -------------

  Stream<List<Pet>> getPets() {
    if (_userId == null) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('pets')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Pet.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<String> addPet(Pet pet) async {
    if (_userId == null) throw Exception("User not logged in");
    
    final docRef = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('pets')
        .add(pet.toMap());
        
    return docRef.id;
  }

  Future<void> updatePet(Pet pet) async {
     if (_userId == null) {
       print("updatePet Error: _userId is null");
       throw Exception("User not logged in");
     }
     if (pet.id == null) {
       print("updatePet Error: pet.id is null. Name: ${pet.name}");
       throw Exception("Cannot update pet without ID");
     }
     
     print("Updating Pet: ${pet.id} - ${pet.name}");
     await _firestore
        .collection('users')
        .doc(_userId)
        .collection('pets')
        .doc(pet.id)
        .update(pet.toMap());
  }

  Future<void> deletePet(String petId) async {
    if (_userId == null) return;
    
    // Alt koleksiyonları da silmek gerekebilir ama şimdilik sadece Pet dokümanını siliyoruz.
    // Not: Firestore'da ana dokümanı silmek alt koleksiyonları silmez.
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('pets')
        .doc(petId)
        .delete();
        
    // İsteğe bağlı: Aşıları ve randevuları da temizle
    // (Bunu daha sonra Cloud Functions ile veya manuel döngüyle yapabiliriz)
  }

  // ------------- VACCINES -------------

  Stream<List<Vaccine>> getVaccines(String petId) {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('vaccines')
        .where('petId', isEqualTo: petId)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Vaccine.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
  
  // Tüm aşıları getir (Özet ekranı için)
  Stream<List<Vaccine>> getAllVaccines() {
    if (_userId == null) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('vaccines')
        // .orderBy('date') // 🔥 İndeks hatası ihtimaline karşı kaldırdık, client-side sıralama yapacağız
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Vaccine.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  Future<void> addVaccine(Vaccine vaccine) async {
    if (_userId == null) return;
    
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('vaccines')
        .add(vaccine.toMap());
  }

  Future<void> updateVaccine(Vaccine vaccine) async {
    if (_userId == null || vaccine.id == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('vaccines')
        .doc(vaccine.id)
        .update(vaccine.toMap());
  }

  Future<void> deleteVaccine(String vaccineId) async {
     if (_userId == null) return;
     
     await _firestore
        .collection('users')
        .doc(_userId)
        .collection('vaccines')
        .doc(vaccineId)
        .delete();
  }

  // ------------- APPOINTMENTS -------------

  Stream<List<Appointment>> getAppointments(String? petId) {
    if (_userId == null) return Stream.value([]);

    Query query = _firestore
        .collection('users')
        .doc(_userId)
        .collection('appointments')
        .orderBy('dateTime');

    if (petId != null) {
      query = query.where('petId', isEqualTo: petId);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Appointment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }
  
  Stream<List<Appointment>> getAllAppointments() {
     return getAppointments(null);
  }

  Future<void> addAppointment(Appointment appointment) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('appointments')
        .add(appointment.toMap());
  }

  Future<void> updateAppointment(Appointment appointment) async {
    if (_userId == null || appointment.id == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('appointments')
        .doc(appointment.id)
        .update(appointment.toMap());
  }

  Future<void> deleteAppointment(String appointmentId) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('appointments')
        .doc(appointmentId)
        .delete();
  }

  // ------------- FOOD TRACKER -------------

  Stream<List<FoodEntry>> getFoodEntries() {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('food_entries')
        .orderBy('time', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FoodEntry.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> addFoodEntry(FoodEntry entry) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('food_entries')
        .add(entry.toMap());
  }
  
  Future<void> deleteFoodEntry(String entryId) async {
    if (_userId == null) return;
    
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('food_entries')
        .doc(entryId)
        .delete();
  }
  // ------------- STOCK / INVENTORY -------------

  Stream<Map<String, int>> getStock() {
    if (_userId == null) return Stream.value({});

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('inventory')
        .doc('main')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return {
          'catDry': 0, 'catWet': 0, 'catTreat': 0,
          'dogDry': 0, 'dogWet': 0, 'dogTreat': 0,
        };
      }
      final data = doc.data() as Map<String, dynamic>;
      return {
        'catDry': (data['catDry'] as int?) ?? 0,
        'catWet': (data['catWet'] as int?) ?? 0,
        'catTreat': (data['catTreat'] as int?) ?? 0,
        'dogDry': (data['dogDry'] as int?) ?? 0,
        'dogWet': (data['dogWet'] as int?) ?? 0,
        'dogTreat': (data['dogTreat'] as int?) ?? 0,
      };
    });
  }

  Future<void> updateStock(Map<String, int> stockData) async {
    if (_userId == null) return;
    
    // Use set with merge to create if not exists
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('inventory')
        .doc('main')
        .set(stockData, SetOptions(merge: true)); 
  }
}
