import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobil1/services/database_service.dart';
import 'package:mobil1/models/pet.dart';
import 'profile_edit_page.dart';

class ProfileViewPage extends StatelessWidget {
  final Pet pet;

  const ProfileViewPage({
    super.key,
    required this.pet,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pet.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🖼 PROFİL FOTO
            Center(
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _getPetImage(pet),
                child: _buildAvatarChild(pet),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              pet.name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              pet.type,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 28),

            _info(Icons.cake, "Yaş", pet.age.toString()),
            _info(Icons.monitor_weight, "Kilo", pet.weight),
            _info(Icons.pets, "Cins", pet.breed),

            const SizedBox(height: 28),

            // ✏️ DÜZENLE
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text("Profili Düzenle"),
                onPressed: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileEditPage(pet: pet),
                    ),
                  ).then((_) {
                    // Sayfa geri döndüğünde verileri güncellemek gerekebilir
                    // Şimdilik basitçe bu sayfayı da kapatıyoruz ki listeden taze veriyle tekrar açılsın
                    Navigator.pop(context); 
                  });
                },
              ),
            ),

            const SizedBox(height: 12),

            // 🗑 SİL
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text("Hayvanı Sil"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => _confirmDelete(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String title, String value) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(value),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Emin misiniz?"),
        content: const Text("Bu hayvan silinecek."),
        actions: [
          TextButton(
            child: const Text("İptal"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              "Sil",
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () async {
              Navigator.pop(context); // Dialog kapat
              if (pet.id != null) {
                await DatabaseService().deletePet(pet.id!);
              }
              if (context.mounted) {
                Navigator.pop(context); // Sayfayı kapat
              }
            },
          ),
        ],
      ),
    );
  }

  /// 🖼 FOTO / AVATAR KARARI
  ImageProvider? _getPetImage(Pet pet) {
    if (pet.imagePath == null || pet.imagePath!.isEmpty) {
       // Return default based on type
       // Note: path might need to be 'assets/...' or just 'assets/...'
       // Assuming standard flutter asset loading
       return AssetImage(pet.type == "Köpek" ? 'assets/images/avatars/dog_1.png' : 'assets/images/avatars/cat_1.png');
    }

    final path = pet.imagePath!;
    
    // Check for "avatar:" prefix (Presets)
    if (path.startsWith("avatar:")) {
       final val = path.substring(7);
       if (val.contains("assets/")) {
         return AssetImage(val);
       }
       // Emoji -> No ImageProvider
       return null;
    }

    // Try File
    try {
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (e) {
      // debugPrint("File load error: $e");
    }
    
    return null; 
  }

  Widget? _buildAvatarChild(Pet pet) {
    // 1. Check for Emoji (legacy avatar)
    if (pet.imagePath != null && pet.imagePath!.startsWith("avatar:")) {
       final val = pet.imagePath!.substring(7);
       if (!val.contains("assets/")) {
          return Text(val, style: const TextStyle(fontSize: 60));
       }
    }

    // 2. If _getPetImage would return null (meaning Broken File or Emoji handled above but we want to check broken file here)
    // Actually simpler: If we have no image provider, show something?
    // But _getPetImage returns a DEFAULT if empty.
    // So if it returns null, it's either an Emoji (handled above) or a Broken File.
    
    // If it's a broken file
    if (pet.imagePath != null && !pet.imagePath!.startsWith("avatar:")) {
        final file = File(pet.imagePath!);
        if (!file.existsSync()) {
           return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
        }
    }
    
    // If _getPetImage returns null (e.g. Emoji), we returned Text above.
    // If it returns an image, child is null.
    return null;
  }
}
