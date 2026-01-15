import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'dart:async';
import 'package:mobil1/services/database_service.dart';
import 'package:mobil1/models/pet.dart';

class ProfileEditPage extends StatefulWidget {
  final Pet? pet;

  const ProfileEditPage({super.key, this.pet});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  static const List<String> _petTypes = ["Kedi", "Köpek"];
  static const Map<String, List<String>> _popularBreeds = {
    "Kedi": [
      "British Shorthair",
      "Scottish Fold",
      "Van Kedisi",
      "Tekir",
      "Sarman",
      "Siyam",
      "Maine Coon",
    ],
    "Köpek": [
      "Golden Retriever",
      "Labrador Retriever",
      "Pomeranian",
      "Poodle",
      "Alman Çoban",
      "Bulldog",
      "Cavalier King Charles",
    ],
  };

  String _normalizePetType(String? rawType) {
    final lower = rawType?.toLowerCase() ?? "";
    if (lower == "köpek" || lower == "kopek") return "Köpek";
    return "Kedi";
  }

  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final breedCtrl = TextEditingController();
  final birthDateCtrl = TextEditingController();

  // Tür listesi
  String? selectedPetType;
  // Cins için popüler + Diğer seçimi
  String? _selectedBreedOption;
  bool _useCustomBreed = false;
  File? _image;
  String? _selectedAvatarString; // "avatar:🐱" formatı için değil, sadece "🐱" tutariz
  DateTime? _birthDate;
  String? _gender; // Erkek / Dişi
  bool? _neutered; // Kısırlaştırılmış mı
  final ImagePicker _picker = ImagePicker();

  String _formatDate(DateTime? date) {
    if (date == null) return "";
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return "$d.$m.$y";
  }

  int _calculateAge(DateTime date) {
    final now = DateTime.now();
    int age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  @override
  void initState() {
    super.initState();

    if (widget.pet != null) {
      nameCtrl.text = widget.pet!.name;
      selectedPetType = _normalizePetType(widget.pet!.type);
      ageCtrl.text = widget.pet!.age.toString();
      weightCtrl.text = widget.pet!.weight;
      breedCtrl.text = widget.pet!.breed;
      _birthDate = widget.pet!.birthDate;
      birthDateCtrl.text = _formatDate(_birthDate);
      _gender = widget.pet!.gender ?? "Erkek";
      _neutered = widget.pet!.neutered ?? false;

      // Cins dropdown başlangıç değeri
      _setupBreedForType();

      // 🔥 VARSA ESKİ FOTOYU YÜKLE
      if (widget.pet!.imagePath != null && widget.pet!.imagePath!.isNotEmpty) {
        final path = widget.pet!.imagePath!;
        if (path.startsWith("avatar:")) {
           // Preset Avatar
           _selectedAvatarString = path.replaceAll("avatar:", "");
           _image = null;
        } else {
           // Dosya Yolu
           try {
            final file = File(path);
            if (file.existsSync()) {
              _image = file;
              _selectedAvatarString = null;
            }
          } catch (e) { }
        }
      }
    } else {
      selectedPetType = "Kedi"; // Varsayılan olarak Kedi
      _gender = "Erkek";
      _neutered = false;
      _setupBreedForType();
    }
  }

  // Tür ve mevcut cins değerine göre dropdown + custom ayarı
  void _setupBreedForType() {
    final type = selectedPetType ?? "Kedi";
    final popular = _popularBreeds[type] ?? [];
    final current = breedCtrl.text.trim();

    if (current.isNotEmpty && popular.contains(current)) {
      _selectedBreedOption = current;
      _useCustomBreed = false;
    } else if (current.isNotEmpty) {
      _selectedBreedOption = "Diğer";
      _useCustomBreed = true;
    } else {
      _selectedBreedOption = popular.isNotEmpty ? popular.first : "Diğer";
      _useCustomBreed = false;
      if (popular.isNotEmpty) {
        breedCtrl.text = popular.first;
      }
    }
  }

  // 🖼 AVATAR / FOTO SEÇİM MENÜSÜ
  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text("Galeriden Seç"),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions, color: Colors.orange),
                title: const Text("Hazır Avatar Seç"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPresetAvatarSelector();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 1. GALERİDEN FOTO
  Future<void> _pickImageFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final fileName = path.basename(picked.path);
    final savedImage =
    await File(picked.path).copy('${directory.path}/$fileName');

    setState(() {
      _image = savedImage; // 🔥 KALICI DOSYA
      _selectedAvatarString = null; // Avatarı temizle
    });
  }

  // 2. HAZIR AVATAR LİSTESİ
  void _showPresetAvatarSelector() {
    final type = selectedPetType ?? "Kedi";
    final isCat = type == "Kedi";
    
    // Asset Listeleri
    final catAssets = [
      "assets/images/avatars/cat_1.png",
      "assets/images/avatars/cat_2.png",
    ];
    final dogAssets = [
      "assets/images/avatars/dog_1.png",
      "assets/images/avatars/dog_2.png",
    ];
    
    final list = isCat ? catAssets : dogAssets;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text("$type Avatarları", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final assetPath = list[index];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAvatarString = assetPath;
                          _image = null; // Dosyayı temizle
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: AssetImage(assetPath),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🎂 DOĞUM TARİHİ SEÇ
  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 1, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: now,
      helpText: "Doğum tarihi seç",
      cancelText: "İptal",
      confirmText: "Tamam",
    );

    if (picked == null) return;

    setState(() {
      _birthDate = picked;
      birthDateCtrl.text = _formatDate(picked);
      ageCtrl.text = _calculateAge(picked).toString();
    });
  }

  bool _isLoading = false;
  final DatabaseService _db = DatabaseService();

  // 💾 KAYDET
  // 💾 KAYDET
  Future<void> _save() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final petType = selectedPetType ?? "Kedi";
      
      String? finalPath;
      if (_image != null) {
        finalPath = _image!.path;
      } else if (_selectedAvatarString != null) {
        finalPath = "avatar:$_selectedAvatarString";
      } else {
        finalPath = widget.pet?.imagePath; 
      }

      final newPet = Pet(
        id: widget.pet?.id, 
        name: nameCtrl.text.trim(),
        type: petType,
        age: int.tryParse(ageCtrl.text) ?? 0,
        weight: weightCtrl.text,
        breed: breedCtrl.text,
        imagePath: finalPath, 
        birthDate: _birthDate,
        gender: _gender,
        neutered: _neutered,
      );
      
      final op = widget.pet == null ? _db.addPet(newPet) : _db.updatePet(newPet);
      
      // 🔥 AGRESİF ÇÖZÜM: Kullanıcı "sonsuz yükleniyor" diyor.
      // 2 Saniye içinde cevap gelmezse, "Tamam, arka planda hallederiz" deyip sayfayı kapatıyoruz.
      // Firestore zaten offline persistence desteklediği için veri kaybolmaz.
      
      try {
        await op.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        print("Save taking too long (>2s), skipping wait to unblock UI.");
        // Hata fırlatmıyoruz, sadece beklemeyi bırakıyoruz.
      }

      if (mounted) {
        Navigator.pop(context); // Kesin kapat
      }
      
    } catch (e) {
      if (mounted) {
         // Gerçek bir hata (yetki yok vs) varsa göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🗑 SİL
  Future<void> _deletePet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Emin misiniz?"),
        content: Text("${widget.pet!.name} adlı hayvanı silmek üzeresiniz. Bu işlem geri alınamaz."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (widget.pet!.id != null) {
        setState(() => _isLoading = true);
        
        try {
          // 2 saniye bekle, cevap gelmezse devam et (Optimistic Delete)
          await _db.deletePet(widget.pet!.id!).timeout(const Duration(seconds: 2));
        } on TimeoutException {
          print("Delete operation timed out (Optimistic Flow)");
        } catch (e) {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
             setState(() => _isLoading = false);
             return; // Gerçek hata varsa çıkma
          }
        }
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  // 🖼 AVATAR GÖSTERİMİ
  Widget _buildAvatar() {
    Widget content;
    
    if (_image != null) {
      content = CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: FileImage(_image!),
      );
    } else if (_selectedAvatarString != null) {
       // Check if it is an asset path (new system) or emoji (legacy)
       if (_selectedAvatarString!.contains("assets/")) {
         content = CircleAvatar(
          radius: 60,
          backgroundColor: Colors.transparent,
          backgroundImage: AssetImage(_selectedAvatarString!),
        );
       } else {
         content = CircleAvatar(
          radius: 60,
          backgroundColor: Colors.orange.shade100,
          child: Text(_selectedAvatarString!, style: const TextStyle(fontSize: 50)),
        );
       }
    } else {
     // Varsayılan (fallback)
     final isDog = (selectedPetType ?? "Kedi") == "Köpek";
     content = CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: AssetImage(isDog ? 'assets/images/avatars/dog_1.png' : 'assets/images/avatars/cat_1.png'), // Updated default
        child: _image == null && _selectedAvatarString == null ? null : Icon(isDog ? Icons.pets : Icons.add_a_photo, size: 30, color: Colors.white54),
     );
  }

    return Stack(
      children: [
        content,
        Positioned(
          bottom: 0,
          right: 0,
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.edit, size: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pet == null ? "Yeni Hayvan Ekle" : "Profili Düzenle"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 🖼 FOTO ALANI
              GestureDetector(
                onTap: _showAvatarPicker,
                child: _buildAvatar(),
              ),
  
              const SizedBox(height: 20),
  
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "İsim *", border: OutlineInputBorder()), // Added star to indicate required
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Lütfen bir isim girin";
                  }
                  return null;
                },
                enableSuggestions: true,
                autocorrect: true,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\s\S]')),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _petTypes.contains(selectedPetType) ? selectedPetType : "Kedi",
                decoration: const InputDecoration(
                  labelText: "Tür",
                  border: OutlineInputBorder(),
                ),
                items: _petTypes
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPetType = value ?? "Kedi";
                  _setupBreedForType();
                  });
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickBirthDate,
                child: AbsorbPointer(
                  child: TextField(
                    controller: birthDateCtrl,
                    decoration: const InputDecoration(
                      labelText: "Doğum Tarihi",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 👤 CİNSİYET
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Cinsiyet",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text("Erkek"),
                    selected: _gender == "Erkek",
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _gender = "Erkek";
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Dişi"),
                    selected: _gender == "Dişi",
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _gender = "Dişi";
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ✂️ KISIRLAŞTIRMA DURUMU
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Kısırlaştırma",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text("Evet"),
                    selected: _neutered == true,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _neutered = true;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Hayır"),
                    selected: _neutered == false,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _neutered = false;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Yaş"),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: weightCtrl,
                decoration: const InputDecoration(labelText: "Kilo"),
                enableSuggestions: true,
                autocorrect: true,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\s\S]')),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedBreedOption,
                decoration: const InputDecoration(
                  labelText: "Cins (ırk)",
                  border: OutlineInputBorder(),
                ),
                items: [
                  ...((_popularBreeds[selectedPetType ?? "Kedi"] ?? [])
                      .map(
                        (b) => DropdownMenuItem(
                          value: b,
                          child: Text("En çok tercih edilen: $b"),
                        ),
                      )),
                  const DropdownMenuItem(
                    value: "Diğer",
                    child: Text("Diğer (elle gir)"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBreedOption = value;
                    if (value == "Diğer") {
                      _useCustomBreed = true;
                    } else if (value != null) {
                      _useCustomBreed = false;
                      breedCtrl.text = value;
                    }
                  });
                },
              ),
              if (_useCustomBreed) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: breedCtrl,
                  decoration: const InputDecoration(
                    labelText: "Cins (elle gir)",
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\s\S]')),
                  ],
                ),
              ],
  
              const SizedBox(height: 24),
  
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading 
                      ? const SizedBox(
                          height: 20, 
                          width: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                        )
                      : const Text("Kaydet"),
                ),
              ),

              if (widget.pet != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deletePet,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text("Hayvanı Sil", style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
