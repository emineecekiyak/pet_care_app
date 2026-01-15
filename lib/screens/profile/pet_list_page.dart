import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobil1/services/database_service.dart';
import 'package:mobil1/models/pet.dart';
import 'profile_view_page.dart';
import 'profile_edit_page.dart';

class PetListPage extends StatefulWidget {
  const PetListPage({super.key});

  @override
  State<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends State<PetListPage> {
  final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dostlarım"),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProfileEditPage(),
            ),
          );
        },
      ),
      body: StreamBuilder<List<Pet>>(
        stream: _db.getPets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final pets = snapshot.data ?? [];

          if (pets.isEmpty) {
            return const Center(
              child: Text(
                "Henüz hayvan eklenmedi 🐾",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: pets.length,
            itemBuilder: (context, index) {
              final pet = pets[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: _buildPetAvatar(pet),
                  title: Text(
                    pet.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${pet.type} • ${pet.breed}"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileViewPage(pet: pet),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 🖼 FOTO / AVATAR KARARI
  Widget _buildPetAvatar(Pet pet) {
     if (pet.imagePath != null && pet.imagePath!.isNotEmpty) {
       // 1. Preset Avatar (Emoji)
       if (pet.imagePath!.startsWith("avatar:")) {
         final emoji = pet.imagePath!.replaceAll("avatar:", "");
         return CircleAvatar(
           radius: 28,
           backgroundColor: Colors.orange.shade100,
           child: Text(emoji, style: const TextStyle(fontSize: 24)),
         );
       } 
       
       // 2. Dosya Yolu
       try {
         final file = File(pet.imagePath!);
         if (file.existsSync()) {
           return CircleAvatar(
             radius: 28,
             backgroundColor: Colors.grey.shade300,
             backgroundImage: FileImage(file),
           );
         }
       } catch (e) { }
     }

     // 3. Varsayılan Asset
     String asset = 'assets/images/avatars/cat.png';
     if (pet.type == "Köpek") asset = 'assets/images/avatars/dog.png';

     return CircleAvatar(
       radius: 28,
       backgroundColor: Colors.grey.shade300,
       backgroundImage: AssetImage(asset),
     );
  }
}
