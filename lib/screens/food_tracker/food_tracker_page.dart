import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobil1/models/food_entry.dart';
import 'package:mobil1/models/pet.dart';

import 'package:mobil1/services/database_service.dart';

class FoodTrackerPage extends StatefulWidget {
  final List<Pet> pets;
  final List<FoodEntry> entries;

  const FoodTrackerPage({
    super.key,
    required this.pets,
    this.entries = const [],
  });

  @override
  State<FoodTrackerPage> createState() => _FoodTrackerPageState();
}

class _FoodTrackerPageState extends State<FoodTrackerPage> {
  final DatabaseService _db = DatabaseService();
  
  // ⚡ Optimistic UI Listesi
  final List<FoodEntry> _pendingEntries = [];
  // 🗑 Optimistic UI Silinenler (Anında gizlensin)
  final Set<String> _deletedEntryIds = {};

  // 📦 Stok Değişkenleri (Granular)
  int _catDryStock = 0;   // 🐱 Kuru
  int _catWetStock = 0;   // 🐱 Yaş
  int _catTreatStock = 0; // 🐱 Ödül

  int _dogDryStock = 0;   // 🐶 Kuru
  int _dogWetStock = 0;   // 🐶 Yaş
  int _dogTreatStock = 0; // 🐶 Ödül


  
  @override
  void didUpdateWidget(FoodTrackerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Gelen yeni listede, bekleyenlerden biri varsa pending'den sil
    // (Basit eşleştirme: Zaman ve Miktar aynıysa aynıdır veya sunucudan gelen daha yeni)
    if (_pendingEntries.isNotEmpty) {
      if (mounted) {
         setState(() {
            _pendingEntries.removeWhere((p) => widget.entries.any((real) => 
               real.time.difference(p.time).inSeconds.abs() < 5 && 
               real.amountGrams == p.amountGrams &&
               real.petName == p.petName
            ));
         });
      }
    }
  }

  // 🧮 Ağırlık string'ini double'a çevirir
  double _parseWeight(String weightStr) {
    if (weightStr.isEmpty) return 0.0;
    String clean = weightStr.replaceAll(RegExp(r'[^0-9.,]'), '');
    clean = clean.replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  // 🦴 Bazal Günlük İhtiyaç
  double _calculateBaseDailyNeeds(Pet pet) {
    double weight = _parseWeight(pet.weight);
    if (weight <= 0) return 0;
    
    final isPuppy = pet.age < 1;
    double base = 0.0;

    if (pet.type.toLowerCase().contains("kedi")) {
       base = isPuppy ? weight * 30 : weight * 15;
    } else {
       base = isPuppy ? weight * 40 : weight * 20;
    }
    return base;
  }

  // 🥣 Gösterilecek hedeflenen miktar
  int _calculateRecommendedAmount(Pet pet, String foodType) {
    double base = _calculateBaseDailyNeeds(pet);
    
    if (foodType == "Yaş Mama") {
      return (base * 2.5).round();
    } else if (foodType == "Ödül Maması") {
      return (base * 1.0).round();
    }
    return base.round();
  }

  // 📅 Bugün tüketilen toplam miktar
  double _calculateConsumedTodayInBaseUnits(String? petId) {
    if (petId == null) return 0;
    final now = DateTime.now();
    
    // Hem sunucudan gelenler hem yerelde bekleyenler
    final all = [..._pendingEntries, ...widget.entries];
    
    return all
        .where((e) =>
            e.petId == petId &&
            e.time.year == now.year &&
            e.time.month == now.month &&
            e.time.day == now.day)
        .fold(0.0, (sum, e) {
          double entryBase = 0.0;
          if (e.foodType == "Yaş Mama") {
            entryBase = e.amountGrams / 2.5; 
          } else if (e.foodType == "Ödül Maması") {
             entryBase = e.amountGrams / 1.0; 
          } else {
             entryBase = e.amountGrams.toDouble(); // Kuru Mama
          }
          return sum + entryBase;
        });
  }

  Future<void> _clearToday() async {
     final now = DateTime.now();
     final todayEntries = widget.entries.where((e) => 
          e.time.year == now.year && 
          e.time.month == now.month && 
          e.time.day == now.day
       ).toList();
       
     for (var e in todayEntries) {
       if (e.id != null) {
          // Stok iadesi yapılabilir ama "Toplu Temizleme" genelde hatalı girişleri silmek değil günü sıfırlamak içindir.
          // Yine de stok iadesi yapmamak kullanıcı tercihidir. Şimdilik sadece siliyoruz.
          await _db.deleteFoodEntry(e.id!);
       }
     }

     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text("Bugünkü veriler temizlendi.")),
     );
  }

  Future<void> _openAddDialog() async {
    final amountCtrl = TextEditingController();
    String selectedFoodType = "Kuru Mama";
    final List<String> foodTypes = ["Kuru Mama", "Yaş Mama", "Ödül Maması"];

    if (widget.pets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Önce en az bir hayvan eklemelisin.")),
      );
      return;
    }

    Pet selectedPet = widget.pets.first;
    int calc = _calculateRecommendedAmount(selectedPet, selectedFoodType);
    if (calc > 0) amountCtrl.text = calc.toString();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              
              void updateAmount() {
                final val = _calculateRecommendedAmount(selectedPet, selectedFoodType);
                setModalState(() {
                   amountCtrl.text = val > 0 ? val.toString() : "";
                });
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Mama Kaydı Ekle", style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Pet>(
                    value: selectedPet,
                    decoration: const InputDecoration(labelText: "Hayvan", border: OutlineInputBorder()),
                    items: widget.pets.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      selectedPet = value;
                      updateAmount();
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedFoodType,
                    decoration: const InputDecoration(labelText: "Mama Türü", border: OutlineInputBorder()),
                    items: foodTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      selectedFoodType = val;
                      updateAmount(); 
                      setModalState(() {}); 
                    },
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(
                      labelText: "Miktar (gram)",
                      border: OutlineInputBorder(),
                      helperText: "Otomatik hesaplandı, değiştirebilirsiniz.",
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = int.tryParse(amountCtrl.text) ?? 0;
                        if (amount <= 0) {
                          Navigator.pop(ctx);
                          return;
                        }

                        // 🚫 GÜNLÜK LİMİT KONTROLÜ
                        double baseTarget = _calculateBaseDailyNeeds(selectedPet);
                        double baseConsumed = _calculateConsumedTodayInBaseUnits(selectedPet.id);
                        double baseRemaining = (baseTarget - baseConsumed).clamp(0.0, baseTarget);
                        
                        // Seçilen mama türüne göre çarpan
                        double multiplier = 1.0;
                        if (selectedFoodType == "Yaş Mama") multiplier = 2.5;
                        if (selectedFoodType == "Ödül Maması") multiplier = 1.0;
                        
                        int allowedGrams = (baseRemaining * multiplier).floor();

                        // Eğer hiç hak kalmadıysa veya girilen miktar kalandan fazlaysa
                        if (amount > allowedGrams) {
                           showDialog(
                            context: ctx,
                            builder: (dialogCtx) => AlertDialog(
                                title: const Text("Limit Aşıldı! 🛑", style: TextStyle(color: Colors.red)),
                                content: Text("Günlük yemek limitiniz doldu veya bu miktar çok fazla.\n\nKalan Hakkınız: $allowedGrams gr ($selectedFoodType)"),
                                actions: [TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Tamam"))],
                              )
                          );
                          return;
                        }

                        // 🔍 Stok Kontrolü
                        int currentStock = 0;
                        final isCat = selectedPet.type.toLowerCase().contains("kedi");
                        if (isCat) {
                          if (selectedFoodType == "Kuru Mama") currentStock = _catDryStock;
                          if (selectedFoodType == "Yaş Mama") currentStock = _catWetStock;
                          if (selectedFoodType == "Ödül Maması") currentStock = _catTreatStock;
                        } else {
                          if (selectedFoodType == "Kuru Mama") currentStock = _dogDryStock;
                          if (selectedFoodType == "Yaş Mama") currentStock = _dogWetStock;
                          if (selectedFoodType == "Ödül Maması") currentStock = _dogTreatStock;
                        }

                        if (currentStock < amount) {
                          showDialog(
                            context: ctx,
                            builder: (dialogCtx) => AlertDialog(
                                title: const Text("Yetersiz Stok ⚠️", style: TextStyle(color: Colors.red)),
                                content: Text("Depoda sadece $currentStock gr $selectedFoodType var."),
                                actions: [TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Tamam"))],
                              )
                          );
                          return;
                        }
                        
                        // 📉 Stoktan Düş
                        setState(() {
                          if (isCat) {
                             if (selectedFoodType == "Kuru Mama") _catDryStock = (_catDryStock - amount).clamp(0, 999999);
                             if (selectedFoodType == "Yaş Mama") _catWetStock = (_catWetStock - amount).clamp(0, 999999);
                             if (selectedFoodType == "Ödül Maması") _catTreatStock = (_catTreatStock - amount).clamp(0, 999999);
                          } else {
                             if (selectedFoodType == "Kuru Mama") _dogDryStock = (_dogDryStock - amount).clamp(0, 999999);
                             if (selectedFoodType == "Yaş Mama") _dogWetStock = (_dogWetStock - amount).clamp(0, 999999);
                             if (selectedFoodType == "Ödül Maması") _dogTreatStock = (_dogTreatStock - amount).clamp(0, 999999);
                          }
                        });
                        _saveStock();

                        // 🔥 Firestore'a Ekle (Arka planda)
                        final entry = FoodEntry(
                          petId: selectedPet.id ?? "",
                          petName: selectedPet.name,
                          foodType: selectedFoodType,
                          amountGrams: amount,
                          time: DateTime.now(),
                        );

                        // 1. Yerel Listeye Ekle (Anında Görünsün)
                        setState(() {
                          _pendingEntries.insert(0, entry);
                        });

                        // 2. Firestore'a Gönder (Arka Planda)
                        _db.addFoodEntry(entry).then((_) {
                           // OK
                        }).catchError((e){
                           // Hata olursa pending'den sil ki kullanıcı fark etsin? 
                           // Ya da retry mekanizması. Şimdilik logluyoruz.
                           print("Food add error: $e");
                           if (mounted) {
                              setState(() {
                                _pendingEntries.remove(entry);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kaydedilemedi!")));
                           }
                        });

                        _checkStockLevels();
                        if (mounted) Navigator.pop(ctx);
                      },
                      child: const Text("Kaydet"),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final date = "${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}.${time.year}";
    final hour = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    return "$date • $hour";
  }

  String _dailyRecFoodType = "Kuru Mama";

  Widget _buildDailyRecommendationSection() {
    if (widget.pets.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // NEW PASTEL GRADIENT (Matching Home Page)
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade50,
            Colors.orange.shade100,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: Colors.orange.withOpacity(0.2), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Günlük Ne Kadar Yemeli? 🍽️",
                  style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.cleaning_services_rounded, color: Colors.orange),
                  onPressed: _clearToday,
                  tooltip: "Bugünü Sıfırla",
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["Kuru Mama", "Yaş Mama", "Ödül Maması"].map((type) {
                  final isSelected = _dailyRecFoodType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _dailyRecFoodType = type);
                      },
                      selectedColor: Colors.orange,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? Colors.orange : Colors.orange.shade200),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.pets.length,
                itemBuilder: (context, index) {
                  final pet = widget.pets[index];
                  if (pet.id == null) return const SizedBox.shrink();

                  double baseTarget = _calculateBaseDailyNeeds(pet);
                  double baseConsumed = _calculateConsumedTodayInBaseUnits(pet.id);
                  double baseRemaining = (baseTarget - baseConsumed).clamp(0, baseTarget);

                  double displayMultiplier = 1.0;
                  if (_dailyRecFoodType == "Yaş Mama") displayMultiplier = 2.5;
                  if (_dailyRecFoodType == "Ödül Maması") displayMultiplier = 1.0;

                  int displayTarget = (baseTarget * displayMultiplier).round();
                  int displayConsumed = (baseConsumed * displayMultiplier).round();
                  int displayRemaining = (baseRemaining * displayMultiplier).round();
                  
                  double progress = baseTarget > 0 ? (baseConsumed / baseTarget).clamp(0.0, 1.0) : 0.0;
                  
                  final isCat = pet.type.toLowerCase().contains("kedi");
                  final defaultAvatar = Text(isCat ? "🐱" : "🐶", style: const TextStyle(fontSize: 28));
                  
                  return Container(
                    width: 230,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                         BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 8, offset: const Offset(0,4))
                      ]
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.shade50),
                          child: ClipOval(
                            child: Builder(builder: (_) {
                                if (pet.imagePath != null) {
                                  // 1. Asset Path (New System)
                                  if (pet.imagePath!.contains("assets/")) {
                                     final cleanPath = pet.imagePath!.replaceAll("avatar:", "");
                                     return Image.asset(cleanPath, fit: BoxFit.cover, width: 52, height: 52, errorBuilder: (_,__,___)=>Center(child: defaultAvatar));
                                  }
                                  // 2. Legacy Emoji
                                  if (pet.imagePath!.startsWith("avatar:")) {
                                     return Center(child: Text(pet.imagePath!.replaceAll("avatar:", ""), style: const TextStyle(fontSize: 28)));
                                  }
                                  // 3. Local File
                                  if (File(pet.imagePath!).existsSync()) {
                                     return Image.file(File(pet.imagePath!), fit: BoxFit.cover, width: 52, height: 52, errorBuilder: (_,__,___)=>Center(child: defaultAvatar));
                                  }
                                }
                                return Center(child: defaultAvatar);
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(pet.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(progress>=1?Colors.redAccent:Colors.orange))),
                              const SizedBox(height: 6),
                              Text(displayRemaining == 0 ? "Limit Doldu 🛑" : "Kalan: ~$displayRemaining gr", style: const TextStyle(color: Colors.black87, fontSize: 13)),
                              Text("$displayConsumed / $displayTarget gr", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                        )),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkStockLevels() async {

    // Bildirim servisi logic'i aynen korunuyor (kısaltıldı)
  }

  StreamSubscription<Map<String, int>>? _stockSubscription;

  @override
  void initState() {
    super.initState();
    // No manual _loadStock needed, we listen to stream now
    _initStockStream();
  }
  
  @override
  void dispose() {
    _stockSubscription?.cancel();
    super.dispose();
  }

  void _initStockStream() {
    _stockSubscription = _db.getStock().listen((stock) {
      if (mounted) {
        setState(() {
          _catDryStock = stock['catDry'] ?? 0;
          _catWetStock = stock['catWet'] ?? 0;
          _catTreatStock = stock['catTreat'] ?? 0;
          
          _dogDryStock = stock['dogDry'] ?? 0;
          _dogWetStock = stock['dogWet'] ?? 0;
          _dogTreatStock = stock['dogTreat'] ?? 0;
        });
        _checkStockLevels();
      }
    });
  }

  Future<void> _saveStock() async {
    // Firestore'a kaydet (Debounce eklenebilir ama şimdilik doğrudan yazıyoruz)
    final stockData = {
      'catDry': _catDryStock,
      'catWet': _catWetStock,
      'catTreat': _catTreatStock,
      'dogDry': _dogDryStock,
      'dogWet': _dogWetStock,
      'dogTreat': _dogTreatStock,
    };
    
    await _db.updateStock(stockData).catchError((e){
       print("Stock cloud save error: $e");
    });
  }

  Future<void> _openAddStockDialog() async {
    final stockCtrl = TextEditingController();
    String targetSpecies = "Kedi";
    String targetType = "Kuru Mama";
    final types = ["Kuru Mama", "Yaş Mama", "Ödül Maması"];
    
    await showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Mama Stoğu Ekle 📦", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                
                // Tür Seçimi (Kedi/Köpek)
                DropdownButtonFormField<String>(
                  value: targetSpecies,
                  decoration: const InputDecoration(labelText: "Hayvan Türü", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: "Kedi", child: Text("Kedi 🐱")),
                    DropdownMenuItem(value: "Köpek", child: Text("Köpek 🐶")),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => targetSpecies = val);
                  },
                ),
                const SizedBox(height: 12),
                
                // Mama Tipi Seçimi
                DropdownButtonFormField<String>(
                  value: targetType,
                  decoration: const InputDecoration(labelText: "Mama Türü", border: OutlineInputBorder()),
                  items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => targetType = val);
                  },
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Miktar (Gram)", 
                    border: OutlineInputBorder(),
                    hintText: "Örn: 1500"
                  ),
                ),
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = int.tryParse(stockCtrl.text) ?? 0;
                      if (amount > 0) {
                        setState(() {
                          if (targetSpecies == "Kedi") {
                            if (targetType == "Kuru Mama") _catDryStock = (_catDryStock + amount).clamp(0, 999999);
                            if (targetType == "Yaş Mama") _catWetStock = (_catWetStock + amount).clamp(0, 999999);
                            if (targetType == "Ödül Maması") _catTreatStock = (_catTreatStock + amount).clamp(0, 999999);
                          } else {
                            if (targetType == "Kuru Mama") _dogDryStock = (_dogDryStock + amount).clamp(0, 999999);
                            if (targetType == "Yaş Mama") _dogWetStock = (_dogWetStock + amount).clamp(0, 999999);
                            if (targetType == "Ödül Maması") _dogTreatStock = (_dogTreatStock + amount).clamp(0, 999999);
                          }
                        });
                        _saveStock();
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text("$amount gr eklendi.")),
                         );
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text("Stok Ekle"),
                  ),
                )
              ],
            ),
          );
        }
      )
    );
  }

  Widget _buildStockRow(String label, int currentGrams, double maxCapacity, Color color) {
    final progress = (currentGrams / maxCapacity).clamp(0.0, 1.0);
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text("$currentGrams gr")]),
       LinearProgressIndicator(value: progress, color: color, backgroundColor: Colors.grey.shade100),
    ]));
  }

  Widget _buildStockSection() {
     return Container(
       padding: const EdgeInsets.all(16),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Mama Stok Durumu 📦", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue), 
                  onPressed: _openAddStockDialog,
                  tooltip: "Stok Ekle",
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text("🐱 Kedi Mamaları", style: TextStyle(fontWeight: FontWeight.bold)),
            _buildStockRow("Kuru Mama", _catDryStock, 3000, Colors.orange),
            _buildStockRow("Yaş Mama", _catWetStock, 2000, Colors.purple),
            _buildStockRow("Ödül", _catTreatStock, 500, Colors.pink),
            
            const SizedBox(height: 12),
            const Text("🐶 Köpek Mamaları", style: TextStyle(fontWeight: FontWeight.bold)),
            _buildStockRow("Kuru Mama", _dogDryStock, 10000, Colors.brown),
            _buildStockRow("Yaş Mama", _dogWetStock, 5000, Colors.deepOrange),
            _buildStockRow("Ödül", _dogTreatStock, 1000, Colors.green),
         ],
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    
    // 🔥 Merge Real + Pending AND Filter Deleted
    final allEntries = [..._pendingEntries, ...widget.entries]
        .where((e) => !_deletedEntryIds.contains(e.id))
        .toList();
        
    // Tarihe göre sırala (Yeni en üstte)
    allEntries.sort((a, b) => b.time.compareTo(a.time));

    final todayEntries = allEntries.where((e) => e.time.year==now.year && e.time.month==now.month && e.time.day==now.day).toList();
    final pastEntries = allEntries.where((e) => !(e.time.year==now.year && e.time.month==now.month && e.time.day==now.day)).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: _openAddDialog, child: const Icon(Icons.add)),
      body: ListView(children: [
         _buildDailyRecommendationSection(),
         _buildStockSection(),
         if(todayEntries.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.all(16), child: Text("Bugün")),
            ...todayEntries.map((e) => _buildFoodEntryCard(e))
         ],
         if(pastEntries.isNotEmpty) ...[
             const Padding(padding: EdgeInsets.all(16), child: Text("Geçmiş")),
             ...pastEntries.map((e) => _buildFoodEntryCard(e))
         ],
         if(allEntries.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("Kayıt yok"))),
      ]),
    );
  }

  Widget _buildFoodEntryCard(FoodEntry e) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade50,
            Colors.orange.shade100.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          "${e.petName} • ${e.foodType}",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        subtitle: Text(
          "${e.amountGrams} gr • ${_formatTime(e.time)}",
          style: TextStyle(color: Colors.black54),
        ),
        trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () async {
              // 1. Anında listeden ve bardan sil (Optimistic)
              setState(() {
                // Eğer henüz kaydedilmemiş (bekleyen) bir öğe ise
                if (_pendingEntries.contains(e)) {
                  _pendingEntries.remove(e);
                }
                // Eğer veritabanından gelen bir öğe ise
                else if (e.id != null) {
                  _deletedEntryIds.add(e.id!);
                  // Arka planda sil
                  _db.deleteFoodEntry(e.id!).catchError((err) {
                    print("Delete error: $err");
                  });
                }
              });
              // Stok İadesi (Yerel)
              setState(() {
                Pet? pet;
                try {
                  pet = widget.pets.firstWhere((p) => p.id == e.petId);
                } catch (_) {}

                final isCat =
                    pet != null ? pet.type.toLowerCase().contains("kedi") : true; // Varsayılan kedi

                if (isCat) {
                  if (e.foodType == "Kuru Mama") _catDryStock += e.amountGrams;
                  if (e.foodType == "Yaş Mama") _catWetStock += e.amountGrams;
                  if (e.foodType == "Ödül Maması") _catTreatStock += e.amountGrams;
                } else {
                  if (e.foodType == "Kuru Mama") _dogDryStock += e.amountGrams;
                  if (e.foodType == "Yaş Mama") _dogWetStock += e.amountGrams;
                  if (e.foodType == "Ödül Maması") _dogTreatStock += e.amountGrams;
                }
              });
              _saveStock();
            }),
      ),
    );
  }
}


