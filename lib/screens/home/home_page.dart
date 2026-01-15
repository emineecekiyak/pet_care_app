import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For user name/avatar (still local for now)
import 'package:mobil1/services/database_service.dart';
import 'package:mobil1/services/auth_service.dart';
import 'package:mobil1/models/pet.dart';
import 'package:mobil1/models/food_entry.dart';
import 'package:mobil1/models/vaccine.dart';
import 'package:mobil1/models/appointment.dart';

import 'package:mobil1/screens/profile/profile_edit_page.dart';
import 'package:mobil1/screens/food_tracker/food_tracker_page.dart';
import 'package:mobil1/screens/vaccine/vaccine_page.dart';
import 'package:mobil1/screens/appointment/appointment_page.dart';
import 'package:mobil1/screens/settings/settings_page.dart';

import 'dart:io'; 

class HomePage extends StatefulWidget {
  final String? uid;
  const HomePage({super.key, this.uid});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  late final DatabaseService _db;

  // User Data
  String userAvatar = "👤";

  // Persistent Streams
  late Stream<List<Pet>> _petStream;
  late Stream<List<FoodEntry>> _foodStream;
  late Stream<List<Vaccine>> _vaccineStream;
  late Stream<List<Appointment>> _appointmentStream;

  @override
  void initState() {
    super.initState();
    _db = DatabaseService(uid: widget.uid);
    _loadUserProfile();
    
    // Initialize streams once
    _petStream = _db.getPets();
    _foodStream = _db.getFoodEntries();
    _vaccineStream = _db.getAllVaccines();
    _appointmentStream = _db.getAllAppointments();
  }

  Future<void> _loadUserProfile() async {
    // Try to load from Firestore first
    if (widget.uid != null) {
      final userData = await AuthService().getUserData(widget.uid!);
      if (userData != null && userData.avatar != null) {
        if (mounted) {
          setState(() {
            userAvatar = userData.avatar!;
          });
        }
        return; 
      }
    }

    // Fallback to local (optional, or just default)
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        userAvatar = prefs.getString('user_avatar') ?? "👤";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pet>>(
      stream: _petStream,
      builder: (context, snapshot) {
        // Main loading state could be here
        final pets = snapshot.data ?? [];
        
        return StreamBuilder<List<FoodEntry>>(
          stream: _foodStream,
          initialData: const [],
          builder: (context, foodSnapshot) {
             final foodEntries = foodSnapshot.data ?? [];
             
             // Navigation Pages
             final pages = [
                _buildDashboard(pets, foodEntries),       // 0. Dashboard (Updated)
                FoodTrackerPage(pets: pets, entries: foodEntries), // 1. Food (Data Connected!)
                VaccinePage(pets: pets),     // 2. Vaccine
                AppointmentPage(pets: pets), // 3. Appointment
                const SettingsPage(),        // 4. Settings
             ];

             return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: _buildAppBar(),
                body: pages[selectedIndex],
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: selectedIndex,
                  onTap: (index) {
                    setState(() => selectedIndex = index);
                    if (index == 0) _loadUserProfile(); 
                  },
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: Colors.blueAccent,
                  unselectedItemColor: Colors.grey,
                  showUnselectedLabels: true,
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Ana Sayfa"),
                    BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: "Mama"),
                    BottomNavigationBarItem(icon: Icon(Icons.vaccines), label: "Aşı"),
                    BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Randevu"),
                    BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ayarlar"),
                  ],
                ),
             );
          }
        );
      }
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).cardColor,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 70, 
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo_appbar.png',
            height: 50, 
            width: 50,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              "Pet Care",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            backgroundImage: userAvatar.contains("assets/") ? AssetImage(userAvatar) : null,
            child: userAvatar.contains("assets/") 
                ? null 
                : Text(userAvatar, style: const TextStyle(fontSize: 24)),
          ),
        )
      ],
    );
  }

  // 🏠 DASHBOARD
  Widget _buildDashboard(List<Pet> pets, List<FoodEntry> foodEntries) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // 1. Pets Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Dostlarım 🐾",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  "${pets.length} Kayıtlı",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // 2. Pet Slider
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.85),
              itemCount: pets.length + 1,
              itemBuilder: (context, index) {
                if (index == pets.length) {
                  return _buildAddPetCard();
                }
                return _buildPetCard(pets[index]);
              },
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 3. Summary Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Bugünün Özeti 📊",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          
          _buildFoodSummary(pets, foodEntries),
          _buildVaccineSummary(),
          _buildAppointmentSummary(),
          _buildDailyTipCard(),
        ],
      ),
    );
  }

  // 💡 GÜNLÜK İPUCU
  Widget _buildDailyTipCard() {
    final tips = [
      "Kediler günde ortalama 12-16 saat uyurlar. 😴",
      "Köpeklerin burun izleri, insanların parmak izleri gibi eşsizdir. 👃",
      "Kedilerin bıyıkları, dar alanlardan geçip geçemeyeceklerini anlamalarına yarar. 📏",
      "Çikolata köpekler için zehirlidir, asla vermeyin! 🍫🚫",
      "Yetişkin kedilere süt verilmemelidir, laktozu sindiremezler. 🥛🚫",
      "Köpekler rüya görürler, uykularında koşmaları bundandır. 🐕💤",
      "Kediler tatlı tadı alamazlar. 🍭",
      "Köpeğinizin dişlerini düzenli fırçalamak ömrünü uzatır. 🪥",
      "Kediler, kendi boylarının 6 katı yüksekliğe zıplayabilirler. 🆙",
      "Köpekler, insanların duygularını ses tonundan anlayabilirler. 🗣️",
      "Kedilerin köprücük kemikleri yoktur, bu yüzden kafalarının sığdığı her yerden geçerler. 🚪",
      "Köpeğiniz kuyruğunu sağa sallıyorsa mutlu, sola sallıyorsa gergindir. 🐕‍🦺",
      "Kediler insanlara miyavlar, birbirleriyle daha çok vücut diliyle anlaşırlar. 💬",
      "Yazın sıcak asfaltta köpeğinizi yürütmeyin, patileri yanabilir. ☀️🐾",
      "Kediler su içmeyi pek sevmezler, yaş mama ile su ihtiyaçlarını destekleyin. 💧",
    ];

    final now = DateTime.now();
    // Yılın günü (1-365)
    final dayOfYear = int.parse("${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}"); 
    // Basit bir hash/mod işlemi ile her gün farklı ama o gün içinde sabit bir ipucu
    final index = dayOfYear % tips.length;

    return _buildSummaryCard(
      "💡 Günün İpucu",
      tips[index],
      Icons.lightbulb,
      Colors.purple,
    );
  }

  Widget _buildFoodSummary(List<Pet> pets, List<FoodEntry> entries) {
        final now = DateTime.now();
        final fedTodayIds = entries.where((e) => 
          e.time.year == now.year && 
          e.time.month == now.month && 
          e.time.day == now.day
        ).map((e) => e.petId).toSet();
        
        final totalPets = pets.where((p) => p.id != null).length;
        
        final fedCount = fedTodayIds.length;
        
        String statusText;
        Color color = Colors.orange;
        
        if (totalPets == 0) {
          statusText = "Henüz hayvan eklemediniz.";
        } else if (fedCount == 0) {
          statusText = "Henüz kimse beslenmedi. 🥣";
        } else if (fedCount < totalPets) {
          statusText = "$fedCount / $totalPets dostumuz beslendi.";
        } else {
          statusText = "Tüm dostlarımız doydu! ✨";
          color = Colors.green;
        }

        return _buildSummaryCard(
          "🦴 Mama Durumu",
          statusText,
          Icons.restaurant_menu,
          color,
          onTap: () => setState(() => selectedIndex = 1),
        );
  }

  Widget _buildVaccineSummary() {
    return StreamBuilder<List<Vaccine>>(
      stream: _vaccineStream,
      builder: (context, snapshot) {
         final vaccines = snapshot.data ?? [];
         final upcoming = vaccines.where((v) => !v.isDone).toList()
           ..sort((a, b) => a.date.compareTo(b.date));
         
         String text;
         bool isUrgent = false;
         
         if (upcoming.isEmpty) {
           text = "Yakın zamanda aşı yok.";
         } else {
           final nextV = upcoming.first;
           final now = DateTime.now();
           final diff = nextV.date.difference(DateTime(now.year, now.month, now.day)).inDays;
           
           if (diff < 0) {
             text = "Gecikmiş Aşı: ${nextV.name} 🚨";
             isUrgent = true;
           } else if (diff == 0) {
             text = "Bugün: ${nextV.name} yapılacak! ⚠️";
             isUrgent = true;
           } else {
             text = "Sıradaki: ${nextV.name} ($diff gün kaldı)";
           }
         }

         return _buildSummaryCard(
           "💉 Aşı Takvimi",
           text,
           Icons.vaccines,
           isUrgent ? Colors.redAccent : Colors.blue,
           onTap: () => setState(() => selectedIndex = 2),
         );
      }
    );
  }

  Widget _buildAppointmentSummary() {
    return StreamBuilder<List<Appointment>>(
      stream: _appointmentStream,
      builder: (context, snapshot) {
         final appointments = snapshot.data ?? [];
         final now = DateTime.now();
         // Filter: Not done and in future (or past but not marked done)
         final pending = appointments.where((a) => !a.isDone).toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

         String text;
         bool isUrgent = false;

         if (pending.isEmpty) {
           text = "Gelecek randevunuz yok.";
         } else {
           final nextA = pending.first;
           final diff = nextA.dateTime.difference(now).inDays;
           
           if (nextA.dateTime.isBefore(now)) {
              text = "Gecikmiş: ${nextA.title} 🚨";
              isUrgent = true;
           } else if (diff == 0) {
              final hours = nextA.dateTime.difference(now).inHours;
              text = hours > 0 
                ? "Bugün $hours saat sonra: ${nextA.title}" 
                : "Randevu Zamanı: ${nextA.title} ⚠️";
              isUrgent = true;
           } else {
              text = "Sıradaki: ${nextA.title} ($diff gün kaldı)";
           }
         }

         return _buildSummaryCard(
           "📅 Randevular",
           text,
           Icons.calendar_today,
           isUrgent ? Colors.redAccent : Colors.green,
           onTap: () => setState(() => selectedIndex = 3),
         );
      }
    );
  }

  Widget _buildPetCard(Pet pet) {
    Widget avatarWidget;
    if (pet.imagePath != null && pet.imagePath!.startsWith("avatar:")) {
       final val = pet.imagePath!.substring(7);
       if (val.contains("assets/")) {
          avatarWidget = ClipOval(
            child: Image.asset(
              val,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          );
       } else {
          avatarWidget = Text(
             val, 
             style: const TextStyle(fontSize: 60),
          );
       }
    } else if (pet.imagePath != null) {
       // Local file path
       avatarWidget = CircleAvatar(
         radius: 40,
         backgroundImage: FileImage(File(pet.imagePath!)),
       );
    } else {
       avatarWidget = Image.asset(
          pet.type == "Köpek" ? 'assets/images/avatars/dog_1.png' : 'assets/images/avatars/cat_1.png',
          width: 80,
       );
    }

    return GestureDetector(
      onTap: () {
        // Go to edit page
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileEditPage(pet: pet)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          // Gradient for a premium, non-white look
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              avatarWidget is Text 
                  ? FittedBox(child: avatarWidget) 
                  : avatarWidget,
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  pet.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                "${pet.breed} • ${pet.age} Yaş",
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPetCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileEditPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50, // Distinct light blue for action card
          borderRadius: BorderRadius.circular(24),
          // Note: BorderStyle.dashed does not exist in standard Flutter BorderStyle enum (only solid/none).
          // We use solid here.
          border: Border.all(color: Colors.blue.withOpacity(0.3), style: BorderStyle.solid, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 32, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            Text(
              "Yeni Ekle",
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String subtitle, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
          boxShadow: [
            if (onTap != null)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
