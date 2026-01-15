import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobil1/services/auth_service.dart';
import 'package:mobil1/services/database_service.dart';
import 'package:mobil1/services/database_service.dart';
import 'package:mobil1/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../theme_notifier.dart'; 

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _userName = "";
  String _userAvatar = "👤";
  bool _isDarkMode = false;
  final DatabaseService _db = DatabaseService();
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _auth.getUserData(user.uid);
      if (userData != null) {
        setState(() {
          _userName = userData.displayName.isNotEmpty ? userData.displayName : "Kullanıcı";
          _userAvatar = userData.avatar ?? "👤";
        });
      }
    }
    
    // Theme is still local preference only
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    });
  }

  Future<void> _updateName() async {
    final controller = TextEditingController(text: _userName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("İsim Düzenle"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Adınız"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text("Kaydet")),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await _auth.updateUserProfile(displayName: newName);
      setState(() => _userName = newName);
    }
  }

  Future<void> _updateAvatar() async {
    const avatars = [
      "assets/images/avatars/human_1.png",
      "assets/images/avatars/human_2.png",
      "assets/images/avatars/human_3.png",
      "assets/images/avatars/human_4.png",
      "assets/images/avatars/human_5.png",
      "assets/images/avatars/human_6.png",
    ];

    final newAvatar = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Avatar Seç"),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: avatars.length,
            itemBuilder: (context, index) {
              final a = avatars[index];
              final isSelected = _userAvatar == a;
              return InkWell(
                onTap: () => Navigator.pop(ctx, a),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.blue, width: 3) : null,
                  ),
                  child: CircleAvatar(
                    backgroundImage: AssetImage(a),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    if (newAvatar != null) {
      await _auth.updateUserProfile(avatar: newAvatar);
      setState(() => _userAvatar = newAvatar);
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    setState(() => _isDarkMode = value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _resetData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Verileri Sıfırla?"),
        content: const Text("Tüm hayvan kayıtları, aşılar ve randevular silinecek. Bu işlem geri alınamaz!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sıfırla", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Siliniyor... Lütfen bekleyin.")));
      }
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        final pets = await _db.getPets().first; 
        for (var p in pets) {
          if (p.id != null) await _db.deletePet(p.id!);
        }

        final vaccines = await _db.getAllVaccines().first;
        for (var v in vaccines) {
          if (v.id != null) await _db.deleteVaccine(v.id!);
        }
        
        final appointments = await _db.getAllAppointments().first;
        for (var a in appointments) {
          if (a.id != null) await _db.deleteAppointment(a.id!);
        }

        final food = await _db.getFoodEntries().first;
        for (var f in food) {
          if (f.id != null) await _db.deleteFoodEntry(f.id!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tüm veriler başarıyla silindi.")));
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata oluştu: $e")));
        }
      }
    }
  }

  Future<void> _sendTestNotification() async {
    await NotificationService().showInstantNotification(
      999,
      "Test Bildirimi 🔔",
      "Bu bir deneme bildirimidir. Sistem çalışıyor! ✅",
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bildirim gönderildi!")));
    }
  }


  Future<void> _sendScheduledTest() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Sayaç başladı! Uygulamayı kapatmayın (Arka plana atabilirsiniz)..."),
        duration: Duration(seconds: 4),
        backgroundColor: Colors.orange,
      ));
    }

    // METHOD CHANGE: Use simple Dart Timer to test if notifications can arrive at all
    // This bypasses the complex Android Alarm permission for now.
    await NotificationService().testDelay_DartTimer(10);
  }

  Future<void> _showUserData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Kullanıcı bulunamadı");

      // Verileri çek
      final pets = await _db.getPets().first;
      final vaccines = await _db.getAllVaccines().first;
      final appointments = await _db.getAllAppointments().first;
      final foodEntries = await _db.getFoodEntries().first;

      // Rapor oluştur
      final buffer = StringBuffer();
      buffer.writeln("=== KULLANICI BİLGİLERİ ===");
      buffer.writeln("ID: ${user.uid}");
      buffer.writeln("Email: ${user.email}");
      buffer.writeln("Kayıt: ${user.metadata.creationTime}");
      buffer.writeln("\n=== EVCİL HAYVANLAR (${pets.length}) ===");
      
      if (pets.isEmpty) buffer.writeln("(Kayıt yok)");
      for (var p in pets) {
        buffer.writeln("- ${p.name} (${p.type}, ${p.breed})");
        buffer.writeln("  ID: ${p.id}");
        buffer.writeln("  Yaş: ${p.age}");
      }

      buffer.writeln("\n=== AŞILAR (${vaccines.length}) ===");
      if (vaccines.isEmpty) buffer.writeln("(Kayıt yok)");
      for (var v in vaccines) {
        buffer.writeln("- ${v.name} (Tarih: ${v.date.toString().split(' ')[0]})");
        buffer.writeln("  Pet ID: ${v.petId}");
        buffer.writeln("  Yapıldı mı: ${v.isDone ? 'Evet' : 'Hayır'}");
      }

      buffer.writeln("\n=== RANDEVULAR (${appointments.length}) ===");
      if (appointments.isEmpty) buffer.writeln("(Kayıt yok)");
      for (var a in appointments) {
        buffer.writeln("- ${a.title} (${a.dateTime.toString().split('.')[0]})");
        buffer.writeln("  Pet ID: ${a.petId}");
      }

      buffer.writeln("\n=== MAMA KAYITLARI (${foodEntries.length}) ===");
      if (foodEntries.isEmpty) buffer.writeln("(Kayıt yok)");
      for (var f in foodEntries) {
        buffer.writeln("- ${f.foodType} (${f.amountGrams}g)");
        buffer.writeln("  Zaman: ${f.time.toString().split('.')[0]}");
      }

      if (mounted) {
        Navigator.pop(context); // Loading kapat
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Verilerim (Ham Görünüm)"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(
                  buffer.toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Kapat"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Loading kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        children: [
          const SizedBox(height: 20),
          // Profile Section
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue.shade50,
                      backgroundImage: _userAvatar.contains("assets/") ? AssetImage(_userAvatar) : null,
                      child: _userAvatar.contains("assets/") 
                          ? null 
                          : Text(_userAvatar, style: const TextStyle(fontSize: 50)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _updateAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: _updateName, icon: const Icon(Icons.edit_outlined, size: 20)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          _buildSectionHeader("Görünüm"),
          SwitchListTile(
            title: const Text("Karanlık Mod"),
            subtitle: const Text("Gözlerinizi yormayan koyu tema"),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: _isDarkMode,
            onChanged: _toggleDarkMode,
          ),
          
          const SizedBox(height: 16),
          _buildSectionHeader("Hesap"),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text("E-posta"),
            subtitle: Text(FirebaseAuth.instance.currentUser?.email ?? "Giriş yapılmamış"),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: const Text("Çıkış Yap"),
            subtitle: const Text("Hesabınızdan çıkış yapın"),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Çıkış Yap?"),
                  content: const Text("Hesabınızdan çıkış yapmak istediğinize emin misiniz?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("İptal"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text("Çıkış Yap"),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await AuthService().signOut();
              }
            },
          ),
          
          const SizedBox(height: 16),
          _buildSectionHeader("Veri Yönetimi"),
          ListTile(
            leading: const Icon(Icons.data_object, color: Colors.blue),
            title: const Text("Verilerimi Görüntüle"),
            subtitle: const Text("Kayıtlı tüm verileri listele"),
            onTap: _showUserData,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text("Tüm Verileri Sıfırla", style: TextStyle(color: Colors.redAccent)),
            subtitle: const Text("Kayıtlı her şeyi siler"),
            onTap: _resetData,
          ),
          
          ListTile(
            leading: const Icon(Icons.notifications_active, color: Colors.purple),
            title: const Text("Bildirim Testi (Anlık)"),
            subtitle: const Text("Hemen bildirim gönder"),
            onTap: _sendTestNotification,
          ),
          
          ListTile(
            leading: const Icon(Icons.av_timer, color: Colors.deepPurple),
            title: const Text("Bildirim Testi (10 Saniye)"),
            subtitle: const Text("10 saniye sonrası için test"),
            onTap: _sendScheduledTest,
          ),
          
          ListTile(
            leading: const Icon(Icons.access_time, color: Colors.blueGrey),
            title: Builder(
              builder: (context) {
                // Since user fixed emulator time, we can stick to native DateTime.now()
                // to match the status bar exactly.
                final now = DateTime.now();
                return Text("Uygulama Saati: ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}");
              }
            ),
            subtitle: const Text("Telefonun şu anki saati"),
          ),

          const SizedBox(height: 16),
          _buildSectionHeader("Hakkında"),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("Uygulama Sürümü"),
            subtitle: Text("1.2.0"),
          ),
          const ListTile(
            leading: Icon(Icons.favorite_border, color: Colors.pink),
            title: Text("Pet Care App"),
            subtitle: Text("Dostlarınız için sevgiyle yapıldı."),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2),
      ),
    );
  }
}
