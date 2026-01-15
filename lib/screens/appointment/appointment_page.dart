import 'package:flutter/material.dart';
import 'package:mobil1/models/pet.dart';
import 'package:mobil1/models/appointment.dart';
import 'package:mobil1/services/database_service.dart';
import 'package:mobil1/services/notification_service.dart';

class AppointmentPage extends StatefulWidget {
  final List<Pet> pets;

  const AppointmentPage({super.key, required this.pets});

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  Pet? _selectedPet;
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.pets.isNotEmpty) {
      // _selectedPet = widget.pets.first;
      _selectedPet = null;
    }
  }

  @override
  void didUpdateWidget(covariant AppointmentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pets.length != oldWidget.pets.length) {
      if (_selectedPet == null && widget.pets.isNotEmpty) {
        setState(() {
      // _selectedPet = widget.pets.first; // Remove force select
      _selectedPet = null; // Default to All
        });
      }
    }
  }

  Future<void> _addAppointment() async {
    if (widget.pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Önce bir hayvan eklemelisiniz.")),
      );
      return;
    }

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locController = TextEditingController();
    final costController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    String selectedCategory = "Veteriner";

    final categories = [
      {"name": "Veteriner", "icon": Icons.medical_services_outlined},
      {"name": "Bakım", "icon": Icons.content_cut_outlined},
      {"name": "Eğitim", "icon": Icons.school_outlined},
      {"name": "Oyun", "icon": Icons.sports_esports_outlined},
      {"name": "Diğer", "icon": Icons.more_horiz_outlined},
    ];

    // Use ID for selection to avoid object equality issues
    String? dialogSelectedPetId = _selectedPet?.id ?? (widget.pets.isNotEmpty ? widget.pets.first.id : null);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Yeni Randevu Ekle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // PET SEÇİMİ (ID Bazlı)
                DropdownButtonFormField<String>(
                  value: dialogSelectedPetId,
                  decoration: const InputDecoration(labelText: "Hangi Dostumuz?"),
                  items: widget.pets.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (val) => setDialogState(() => dialogSelectedPetId = val),
                ),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "Randevu Başlığı"),
                ),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: "Kategori"),
                  items: categories.map((c) => DropdownMenuItem(value: c['name'] as String, child: Text(c['name'] as String))).toList(),
                  onChanged: (c) => setDialogState(() => selectedCategory = c!),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Tarih ve Saat"),
                  subtitle: Text("${selectedDate.day}.${selectedDate.month}.${selectedDate.year} - ${selectedTime.format(context)}"),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (t != null) {
                        setDialogState(() {
                          selectedDate = d;
                          selectedTime = t;
                        });
                      }
                    }
                  },
                ),
                TextField(
                  controller: locController,
                  decoration: const InputDecoration(labelText: "Konum / Klinik Adı"),
                ),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Tahmini Maliyet (₺)"),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: "Notlar"),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                
                if (dialogSelectedPetId == null) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir hayvan seçin")));
                   return;
                }
                
                // Find name for notification
                final selectedPetName = widget.pets.firstWhere((p) => p.id == dialogSelectedPetId, orElse: () => widget.pets.first).name;

                final dt = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final app = Appointment(
                  petId: dialogSelectedPetId!, // Safe usage
                  title: titleController.text,
                  description: descController.text,
                  dateTime: dt,
                  category: selectedCategory,
                  location: locController.text,
                  cost: double.tryParse(costController.text),
                  isDone: false,
                );

                // 1. Show processing feedback gracefully
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text("Kaydediliyor... 🔄"),
                  duration: Duration(milliseconds: 800),
                ));

                try {
                  // 2. Await DB Operation
                  await _db.addAppointment(app);
                  
                  // 3. Await Notification Setup
                  debugPrint("DEBUG: Appt saved. Setup notification...");
                  await NotificationService().requestExactAlarms();

                  // Notification Logic (Relative):
                  final timeUntilAppt = dt.difference(DateTime.now());
                  String snackMsg = "Randevu kaydedildi.";
                  Color snackColor = Colors.green;
                  
                  Duration delay;
                  if (timeUntilAppt.inMinutes > 30) {
                     // 30 dakika kala bildirim gönder
                     delay = timeUntilAppt - const Duration(minutes: 30);
                  } else {
                     // 30 dakikadan az kaldıysa hemen (veya tam zamanında)
                     delay = timeUntilAppt;
                  }

                  if (!delay.isNegative) {
                     await NotificationService().scheduleRelativeNotification(
                       app.hashCode + 10000, 
                       "Randevu ⏰",
                       "Zamanı geldi: $selectedPetName - ${app.title}.",
                       delay,
                     );
                     snackMsg += "\n🔔 Alarm: ${delay.inMinutes} dk sonra çalacak (Randevudan 30 dk önce).";
                  } else {
                     snackMsg += "\n(Süre geçtiği için alarm kurulmadı)";
                     snackColor = Colors.orange;
                  }

                  // 4. Show Result
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(snackMsg),
                      backgroundColor: snackColor,
                      duration: const Duration(seconds: 4),
                    ));
                  }
                } catch (e) {
                  print("SAVE ERROR: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Hata: $e"),
                      backgroundColor: Colors.red,
                    ));
                  }
                } finally {
                  // 5. Close Dialog
                  if (ctx.mounted) {
                    Navigator.pop(ctx); 
                  }
                }
              },
              child: const Text("Kaydet"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStatus(Appointment app) async {
    final updated = app.copyWith(isDone: !app.isDone);
    await _db.updateAppointment(updated);
  }

  Future<void> _deleteAppointment(Appointment app) async {
    if (app.id == null) return;
    await _db.deleteAppointment(app.id!);
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Veteriner": return Icons.medical_services_outlined;
      case "Bakım": return Icons.content_cut_outlined;
      case "Eğitim": return Icons.school_outlined;
      case "Oyun": return Icons.sports_esports_outlined;
      default: return Icons.more_horiz_outlined;
    }
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
                 child: StreamBuilder<List<Appointment>>(
                      stream: _db.getAllAppointments(), // 🔥 Always fetch all, filter locally to avoid Index issues
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          if (_isLoading) return const Center(child: CircularProgressIndicator());
                        }

                        var appointments = snapshot.data ?? [];
                        
                        // Client-side filtering
                        if (_selectedPet != null) {
                           appointments = appointments.where((a) => a.petId == _selectedPet!.id).toList();
                        }

                        final now = DateTime.now();
                        
                        // Bekleyen: Tamamlanmamış VE gelecekteki randevular
                        final upcoming = appointments.where((a) => !a.isDone && a.dateTime.isAfter(now)).toList();
                        // Tamamlanan: Tamamlanmış VEYA geçmiş tarihli randevular
                        final completed = appointments.where((a) => a.isDone || a.dateTime.isBefore(now)).toList();

                        if (appointments.isEmpty) return _buildEmptyState();

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (upcoming.isNotEmpty) ...[
                              Text(
                                _selectedPet == null ? "Bekleyen Randevular (Tümü)" : "Bekleyen Randevular (${_selectedPet!.name})", 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                              ),
                              const SizedBox(height: 12),
                              ...upcoming.map((a) => _buildAppointmentCard(a)),
                            ],
                            if (completed.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              const Text("Tamamlananlar / Geçmiş", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 12),
                              ...completed.map((a) => _buildAppointmentCard(a)),
                            ],
                          ],
                        );
                      }
                    ),
               ),
            ],
          ),
      floatingActionButton: widget.pets.isNotEmpty 
        ? FloatingActionButton(
            onPressed: _addAppointment,
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.add),
          )
        : null,
    );
  }

  Widget _buildPetSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: DropdownButtonFormField<Pet?>( // Change type to Pet?
        value: _selectedPet,
        decoration: InputDecoration(
          labelText: "Filtrele",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.filter_list),
        ),
        // Add "All" option
        items: [
          const DropdownMenuItem<Pet?>(
            value: null, 
            child: Text("Tüm Dostlarım")
          ),
          ...widget.pets.map((p) => DropdownMenuItem<Pet?>(
            value: p, 
            child: Text(p.name)
          )),
        ],
        onChanged: (val) {
          setState(() {
            _selectedPet = val;
          });
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment app) {
    final now = DateTime.now();
    final isOverdue = !app.isDone && app.dateTime.isBefore(now);
    
    // Modern Kart Tasarımı
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: app.isDone ? Colors.green.shade50.withOpacity(0.5) : Colors.white, // Hafif yeşil arka plan
          border: Border(
            left: BorderSide(
              color: app.isDone ? Colors.teal : (isOverdue ? Colors.red : Colors.blue),
              width: 6,
            ),
          ),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: Container(
             padding: const EdgeInsets.all(10),
             decoration: BoxDecoration(
               color: app.isDone ? Colors.teal.shade100 : Colors.blue.shade50,
               shape: BoxShape.circle,
             ),
             child: Icon(
               _getCategoryIcon(app.category),
               color: app.isDone ? Colors.teal.shade800 : Colors.blueAccent,
               size: 22,
             ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  app.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: app.isDone ? Colors.teal.shade900 : Colors.black87,
                  ),
                ),
              ),
              // Show Pet Name badge if in "All" mode or general utility
              if (widget.pets.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    widget.pets.firstWhere((p) => p.id == app.petId, orElse: () => Pet(name: "?", type: "", age: 0, weight: "", breed: "")).name,
                    style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.event, size: 14, color: app.isDone ? Colors.teal.shade700 : Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    "${app.dateTime.day}.${app.dateTime.month}.${app.dateTime.year} • ${app.dateTime.hour}:${app.dateTime.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(
                      fontSize: 13, 
                      color: app.isDone ? Colors.teal.shade700 : Colors.grey.shade700,
                      fontWeight: app.isDone ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (isOverdue && !app.isDone) // Tamamlanmışsa zamanı geçti yazmasın
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    "⚠️ Zamanı Geçti",
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                  ),
                ),
              if (app.isDone)
                 Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    "✅ Tamamlandı",
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          trailing: InkWell(
            onTap: () => _toggleStatus(app), 
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: app.isDone ? Colors.teal : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: app.isDone ? Colors.teal : Colors.grey.shade400, width: 2),
              ),
              child: Icon(
                Icons.check,
                size: 20,
                color: app.isDone ? Colors.white : Colors.grey.shade400,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  if (app.location != null && app.location!.isNotEmpty)
                    _buildDetailRow(Icons.location_on_outlined, "Konum: ${app.location}"),
                  if (app.cost != null)
                    _buildDetailRow(Icons.payments_outlined, "Maliyet: ${app.cost} ₺"),
                  if (app.description != null && app.description!.isNotEmpty)
                    _buildDetailRow(Icons.notes, app.description!),
                  
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _deleteAppointment(app),
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        label: const Text("Sil", style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).hintColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Henüz randevu yok.", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Yeni bir randevu eklemek için + butonuna basın.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
