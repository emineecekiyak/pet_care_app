import 'package:flutter/material.dart';
import '../home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PetProfilePage extends StatefulWidget {
  const PetProfilePage({super.key});

  @override
  State<PetProfilePage> createState() => _PetProfilePageState();
}

class _PetProfilePageState extends State<PetProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController weightController = TextEditingController();

  String petType = 'Kedi';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evcil Hayvan Profili'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profil foto alanı (şimdilik icon)
              const CircleAvatar(
                radius: 55,
                child: Icon(Icons.pets, size: 50),
              ),

              const SizedBox(height: 24),

              // Hayvan adı
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Hayvan Adı',
                  border: OutlineInputBorder(),
                ),
                enableSuggestions: true,
                autocorrect: true,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bu alan boş bırakılamaz';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Tür seçimi
              DropdownButtonFormField<String>(
                value: petType,
                items: const [
                  DropdownMenuItem(value: 'Kedi', child: Text('Kedi')),
                  DropdownMenuItem(value: 'Köpek', child: Text('Köpek')),
                ],
                onChanged: (value) {
                  setState(() {
                    petType = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Tür',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // Yaş
              TextFormField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Yaş',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // Kilo
              TextFormField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kilo (kg)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              // Kaydet butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final prefs = await SharedPreferences.getInstance();

                      await prefs.setString('pet_name', nameController.text);
                      await prefs.setString('pet_type', petType);
                      await prefs.setString('pet_age', ageController.text);
                      await prefs.setString('pet_weight', weightController.text);

                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomePage(), // AuthWrapper will handle uid usually, but here we might need to pop instead of pushReplacement if possible or better, just pop. However, to keep existing logic: const HomePage() works if we don't pass uid (it falls back to currentUser).
                          ),
                        );
                      }
                    }
                  },

                  child: const Text('Kaydet'),
                ),

              ),
            ],
          ),
        ),
      ),
    );
  }
}
