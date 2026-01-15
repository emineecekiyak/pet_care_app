import 'package:flutter/material.dart';
import 'package:mobil1/models/pet.dart';
import 'package:mobil1/models/vaccine.dart';
import 'package:mobil1/services/database_service.dart';
import 'package:mobil1/services/notification_service.dart';

class VaccinePage extends StatefulWidget {
  final List<Pet> pets;

  const VaccinePage({super.key, required this.pets});

  @override
  State<VaccinePage> createState() => _VaccinePageState();
}

class _VaccinePageState extends State<VaccinePage> {
  Pet? _selectedPet;
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.pets.isNotEmpty) {
      _selectedPet = widget.pets.first;
    }
  }

  @override
  void didUpdateWidget(covariant VaccinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pets.length != oldWidget.pets.length) {
      if (_selectedPet == null && widget.pets.isNotEmpty) {
        setState(() {
          _selectedPet = widget.pets.first;
        });
      }
    }
  }

  Future<void> _applyTemplate() async {
    if (_selectedPet == null || _selectedPet!.id == null) return;

    final isCat = _selectedPet!.type.toLowerCase().contains("kedi");
    // [İsim, Frekans(Ay)]
    final List<List<dynamic>> templates = isCat
        ? [
            ["İç/Dış Parazit", 2],
            ["Karma Aşı", 12],
            ["Kuduz Aşısı (Zorunlu)", 12],
            ["Lösemi Aşısı", 12],
          ]
        : [
            ["İç/Dış Parazit", 2],
            ["Karma Aşı", 12],
            ["Kuduz Aşısı (Zorunlu)", 12],
            ["Corona Aşısı", 12],
            ["Bronchine", 12],
          ];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${_selectedPet!.name} İçin Şablon Uygula"),
        content: Text("${templates.length} adet önerilen aşı/uygulama listeye eklenecek. Devam edilsin mi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Evet, Ekle")),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // 🔥 Parallel Execution (Hepsini aynı anda başlat)
        final futures = <Future<bool>>[];
        
        for (int i = 0; i < templates.length; i++) {
           futures.add(_addSingleVaccineFromTemplate(templates[i], i));
        }

        // Tüm işlemlerin bitmesini bekle
        final results = await Future.wait(futures);
        final successCount = results.where((r) => r).length;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$successCount / ${templates.length} aşı takvime eklendi!")),
          );
        }
      } catch (e) {
        _showError("Şablon uygulanırken hata: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Helper for parallel execution
  Future<bool> _addSingleVaccineFromTemplate(List<dynamic> template, int index) async {
    try {
      final v = Vaccine(
        petId: _selectedPet!.id!,
        name: template[0] as String,
        frequencyMonths: template[1] as int,
        date: DateTime.now().add(Duration(days: (index + 1) * 7)),
        isDone: false,
      );

      // 1. DB Add
      await _db.addVaccine(v);

      // 2. Notification (Fire & Forget)
      final reminderTime = DateTime(v.date.year, v.date.month, v.date.day, 9, 0);
      NotificationService().scheduleNotification(
        DateTime.now().microsecondsSinceEpoch + index, // Unique ID
        "Aşı Hatırlatıcısı 💉",
        "${_selectedPet!.name} dostumuzun bugün ${v.name} aşısı yapılması gerekiyor.",
        reminderTime,
      ).catchError((_) {});

      return true; // Success
    } catch (e) {
      print("Template item failed ($template): $e");
      return false; // Failed
    }
  }

  Future<void> _addVaccine() async {
    if (_selectedPet == null) return;

    final nameController = TextEditingController();
    final noteController = TextEditingController();
    final freqController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final isCat = _selectedPet!.type.toLowerCase().contains("kedi");
    
    final List<Map<String, dynamic>> suggestions = isCat
        ? [
            {"name": "İç/Dış Parazit", "freq": 2, "icon": Icons.bug_report_outlined},
            {"name": "Karma Aşı", "freq": 12, "icon": Icons.shield_outlined},
            {"name": "Kuduz Aşısı", "freq": 12, "icon": Icons.warning_amber_rounded},
            {"name": "Lösemi Aşısı", "freq": 12, "icon": Icons.health_and_safety_outlined},
          ]
        : [
            {"name": "İç/Dış Parazit", "freq": 2, "icon": Icons.bug_report_outlined},
            {"name": "Karma Aşı", "freq": 12, "icon": Icons.shield_outlined},
            {"name": "Kuduz Aşısı", "freq": 12, "icon": Icons.warning_amber_rounded},
            {"name": "Corona Aşısı", "freq": 12, "icon": Icons.coronavirus_outlined},
            {"name": "Bronchine", "freq": 12, "icon": Icons.air_outlined},
          ];

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blueAccent),
              const SizedBox(width: 8),
              const Text("Akıllı Aşı Ekle"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Hızlı Seçim", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 12),
                Column(
                  children: suggestions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () {
                        setDialogState(() {
                          nameController.text = s['name'];
                          freqController.text = s['freq'].toString();
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: nameController.text == s['name'] ? Colors.blueAccent : Colors.grey.shade200,
                            width: nameController.text == s['name'] ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: nameController.text == s['name'] ? Colors.blue.shade50 : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(s['icon'] as IconData, size: 20, color: Colors.blueAccent),
                            const SizedBox(width: 12),
                            Expanded(child: Text(s['name'] as String, style: const TextStyle(fontSize: 14))),
                            Text("${s['freq']} Ay", style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 24),
                const Text("Manuel Detaylar", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Aşı Adı",
                    prefixIcon: Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: freqController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Tekrar Sıklığı (Ay)",
                    hintText: "Örn: 12",
                    border: OutlineInputBorder(),
                    helperText: "Bu aşı kaç ayda bir tekrarlanmalı?",
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  tileColor: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.calendar_today, color: Colors.blue),
                  ),
                  title: const Text("Aşı Tarihi", style: TextStyle(fontSize: 14)),
                  subtitle: Text("${selectedDate.day}.${selectedDate.month}.${selectedDate.year}", 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 1000)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: "Notlar (Opsiyonel)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                
                final v = Vaccine(
                  petId: _selectedPet!.id!,
                  name: nameController.text.trim(),
                  date: selectedDate,
                  frequencyMonths: int.tryParse(freqController.text),
                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                );
                
                if (ctx.mounted) {
                  Navigator.pop(ctx, true); // ⚡ Anında kapat
                }

                // 🔥 Arka planda kaydet (Optimistic)
                _db.addVaccine(v).then((_) async {
                   final reminderTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 9, 0);
                   await NotificationService().scheduleNotification(
                     v.hashCode,
                     "Aşı Hatırlatıcısı 💉",
                     "${_selectedPet!.name} dostumuzun bugün ${v.name} aşısı yapılması gerekiyor.",
                     reminderTime,
                   );
                }).catchError((e){
                   if (mounted) _showError("Aşı kaydedilirken hata oluştu: $e");
                });
              },
              child: const Text("Kaydet"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renewVaccine(Vaccine vaccine) async {
    if (vaccine.frequencyMonths == null) {
      _showError("Bu aşının bir periyot bilgisi yok, otomatik tekrarlanamaz.");
      return;
    }

    final nextDetail = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Gelecek Dozu Planla"),
        content: Text("${vaccine.name} aşısının bir sonraki dozu ${vaccine.frequencyMonths} ay sonrasına planlanacak.\n\nEmin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Planla"),
          ),
        ],
      ),
    );

    if (nextDetail == true) {
      final DateTime originalDate = vaccine.date;
      final DateTime nextDate = DateTime(
        originalDate.year,
        originalDate.month + vaccine.frequencyMonths!,
        originalDate.day,
      );

      final nextV = Vaccine(
        petId: vaccine.petId,
        name: vaccine.name,
        date: nextDate,
        isDone: false,
        note: vaccine.note,
        frequencyMonths: vaccine.frequencyMonths,
      );

      await _db.addVaccine(nextV);

      final reminderTime = DateTime(nextV.date.year, nextV.date.month, nextV.date.day, 9, 0);
      await NotificationService().scheduleNotification(
        nextV.hashCode,
        "Aşı Hatırlatıcısı 💉",
        "${_selectedPet!.name} dostumuzun bugün ${nextV.name} aşısı yapılması gerekiyor.",
        reminderTime,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gelecek doz ${nextDate.day}.${nextDate.month}.${nextDate.year} tarihine eklendi! 📅")),
        );
      }
    }
  }

  Future<void> _toggleDone(Vaccine vaccine) async {
    final updated = vaccine.copyWith(isDone: !vaccine.isDone);
    await _db.updateVaccine(updated);
  }

  Future<void> _deleteVaccine(Vaccine vaccine) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Aşıyı Sil?"),
        content: const Text("Bu kayıt silinecek, emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && vaccine.id != null) {
      await _db.deleteVaccine(vaccine.id!);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: widget.pets.isEmpty
          ? const Center(child: Text("Önce bir hayvan eklemelisiniz."))
          : Column(
              children: [
                _buildPetSelector(),
                Expanded(
                  child: StreamBuilder<List<Vaccine>>(
                      stream: _db.getAllVaccines(), // 🔥 Tüm hayvanların aşılarını çek
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          if (_isLoading) return const Center(child: CircularProgressIndicator());
                        }
                        
                        final allVaccines = snapshot.data ?? [];
                        print("DEBUG: All Vaccines Count: ${allVaccines.length}");
                        
                        // 🔥 Sadece aktif hayvanların aşılarını göster (Silinenleri gizle)
                        final activePetIds = widget.pets.map((p) => p.id).toSet();
                        
                        // 1. GLOBAL Gelecek Aşılar (Tüm AKTİF hayvanlar)
                        final upcomingGlobal = allVaccines
                            .where((v) => !v.isDone && activePetIds.contains(v.petId))
                            .toList()
                            ..sort((a, b) => a.date.compareTo(b.date));

                        // 2. SEÇİLİ HAYVAN Geçmişi (Aşağıdaki liste)
                        final selectedPetVaccines = (_selectedPet == null || _selectedPet!.id == null)
                            ? <Vaccine>[]
                            : allVaccines
                                .where((v) => v.petId == _selectedPet!.id)
                                .toList()
                                ..sort((a, b) => a.date.compareTo(b.date)); // 🔥 Client-side sort

                         print("DEBUG: Selected Pet: ${_selectedPet?.name} (${_selectedPet?.id})");
                         print("DEBUG: Selected Pet Vaccines Count: ${selectedPetVaccines.length}");

                        // Liste boşsa ve şablon eklenmemişse boş ekran (ama global yaklaşan varsa gösterelim mi? 
                        // Kullanıcı "Planlanan aşılar tüm hayvanları kapsasın" dedi.
                        // Aşağıdaki liste seçili hayvana ait. Seçili hayvanın aşısı yoksa boş state dönebiliriz,
                        // AMA yukarıda "Upcoming" varsa onu göstermemiz lazım.
                        // O yüzden boş state kontrolünü sadece liste için yapacağız veya yapıyı değiştireceğiz.
                        
                        return ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            // 🔥 GLOBAL UPCOMING SECTION
                            if (upcomingGlobal.isNotEmpty) 
                              _buildUpcomingSection(upcomingGlobal),

                            // AŞI GEÇMİŞİ BAŞLIĞI
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                              child: Text(
                                _selectedPet != null ? "${_selectedPet!.name} Aşı Takvimi" : "Aşı Kayıtları",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),

                            // SEÇİLİ HAYVAN LİSTESİ
                            if (selectedPetVaccines.isEmpty)
                               _buildEmptyStateForSelectedPet()
                            else
                               _buildVaccineList(selectedPetVaccines),
                               
                            const SizedBox(height: 80), // FAB için boşluk
                          ],
                        );
                      }
                    ),
                ),
              ],
            ),
      floatingActionButton: widget.pets.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _addVaccine,
              icon: const Icon(Icons.add),
              label: const Text("Aşı Ekle"),
              backgroundColor: Colors.blueAccent,
            )
          : null,
    );
  }

  // Helper to find pet name
  String _getPetName(String petId) {
    try {
      return widget.pets.firstWhere((p) => p.id == petId).name;
    } catch (_) {
      return "Bilinmeyen";
    }
  }

  Widget _buildUpcomingSection(List<Vaccine> upcoming) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            "Yaklaşan Aşılar (Tümü) 📅",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 155,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: upcoming.length,
            itemBuilder: (context, index) {
              final v = upcoming[index];
              final petName = _getPetName(v.petId); // 🔥 İsim buradan geliyor

              final now = DateTime.now();
              final bool isOverdue = v.date.isBefore(now);
              final bool isSoon = !isOverdue && v.date.difference(now).inDays < 90;
              
              return Container(
                width: 210,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isOverdue 
                      ? [Colors.red.shade400, Colors.red.shade600]
                      : [Colors.orange.shade300, Colors.orange.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isOverdue ? Colors.red : Colors.orange).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            petName,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          isOverdue ? "Gecikti!" : (isSoon ? "Yakında" : ""),
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      v.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.event, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "${v.date.day}.${v.date.month}.${v.date.year}",
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPetSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: DropdownButtonFormField<Pet>(
        value: _selectedPet,
        decoration: InputDecoration(
          labelText: "Hayvan Seçin",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.pets),
        ),
        items: widget.pets
            .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
            .toList(),
        onChanged: (val) {
          setState(() {
            _selectedPet = val;
            // StreamBuilder otomatik güncellenecek çünkü _selectedPet değişiyor
          });
        },
      ),
    );
  }

  Widget _buildEmptyStateForSelectedPet() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vaccines_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              "Bu hayvan için aşı kaydı yok.",
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _applyTemplate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Şablon Uygula"),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blueAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccineList(List<Vaccine> list) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final v = list[index];
        final bool isOverdue = !v.isDone && v.date.isBefore(DateTime.now());
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: v.isDone 
                ? Colors.green.shade100 
                : (isOverdue ? Colors.red.shade100 : Colors.blue.shade100),
              child: Icon(
                v.isDone ? Icons.check : Icons.vaccines,
                color: v.isDone 
                  ? Colors.green 
                  : (isOverdue ? Colors.red : Colors.blue),
              ),
            ),
            title: Text(
              v.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: v.isDone ? TextDecoration.lineThrough : null,
                color: Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text("${v.date.day}.${v.date.month}.${v.date.year}", style: const TextStyle(color: Colors.black54)),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Zamanı Geçti",
                          style: TextStyle(fontSize: 10, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (v.frequencyMonths != null) 
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(
                           color: Colors.orange.shade50,
                           borderRadius: BorderRadius.circular(4),
                         ),
                         child: Text(
                           "Her ${v.frequencyMonths} Ay",
                           style: TextStyle(fontSize: 10, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                         ),
                       )
                    else
                       Text("(Sıklık Belirtilmedi)", style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
                if (v.note != null) 
                  Text(v.note!, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  tooltip: "Tamamlandı / Geri Al",
                  icon: Icon(
                    v.isDone ? Icons.undo : Icons.check_circle_outline,
                    color: v.isDone ? Colors.grey : Colors.green,
                  ),
                  onPressed: () => _toggleDone(v),
                ),
                if (v.frequencyMonths != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    tooltip: "Gelecek Dozu Planla",
                    icon: const Icon(Icons.event_repeat, color: Colors.orange),
                    onPressed: () => _renewVaccine(v),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  tooltip: "Sil",
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteVaccine(v),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
