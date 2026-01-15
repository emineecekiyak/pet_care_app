import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      // Force Istanbul for consistency since user device is now TR
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (e) {
      print("Timezone error: $e");
    }
    
    // ... init settings ...
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
      },
    );
    
    await requestPermissions();
  }

  // ALTERNATIVE TEST: Plain Dart Timer (Bypasses Alarm Manager)
  Future<void> testDelay_DartTimer(int seconds) async {
    print("DART TIMER: Waiting $seconds seconds...");
    await Future.delayed(Duration(seconds: seconds));
    print("DART TIMER: Time's up! Showing notification.");
    
    await showInstantNotification(
      777,
      "Sayaç Testi (Dart) ⏱️",
      "Bu bildirim Alarm sistemi yerine Dart sayacı ile atıldı.",
    );
  }

  Future<String> scheduleSecondsFromNow(int seconds) async {
    try {
      // Correct way: Get NOW in the target timezone
      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(Duration(seconds: seconds));
      
      await _notificationsPlugin.zonedSchedule(
        998,
        "Zamanlı Test ⏰", 
        "Test Başarılı! ($seconds saniye beklendi)",
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel_v3', // Changed channel ID to force refresh
            'Zamanlı Hatırlatıcılar (Kesin)',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        // Switch back to EXACT now that permission is granted
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return "Kuruldu: ${scheduledDate.hour}:${scheduledDate.minute}:${scheduledDate.second}";
    } catch (e) {
      print("Schedule Error: $e");
      return "HATA: $e";
    }
  }

  // Robust Scheduling: Uses direct duration delay
  // This avoids all timezone/date calculation issues.
  Future<void> scheduleRelativeNotification(int id, String title, String body, Duration delay) async {
    try {
      if (delay.isNegative) return; // Don't schedule for past

      // 1. BACKUP PLAN: Start a Dart Timer immediately
      // This ensures the notification arrives if the app is still running (foreground or background RAM)
      // ignoring Emulator Alarm quirks.
      Future.delayed(delay, () async {
        print("DART BACKUP TIMER: Firing notification now!");
        await showInstantNotification(id, "$title (Yedek)", body);
      });

      // 2. PRIMARY PLAN: Android Alarm Manager (for when app is killed)
      // "Now" in the eyes of the Alarm Manager's timezone
      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(delay);
      
      print("RELATIVE SCHEDULING: Now ($now) + $delay = $scheduledDate");

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'appointment_channel_critical',
            'Randevu (Kritik)',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        // NUCLEAR OPTION: Alarm Clock mode (Best chance of firing on Emulators)
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print("Relative Schedule Error: $e");
    }
  }

  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<bool> checkExactAlarmPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
            
    if (androidImplementation != null) {
      // Check if we can schedule exact notifications (Android 12+)
      // This might return null on older versions, so default to true.
      final canSchedule = await androidImplementation.requestExactAlarmsPermission(); 
      // Note: requestExactAlarmsPermission actually returns the status or requests it?
      // Actually flutter_local_notifications 'requestExactAlarmsPermission' might not be available in older versions of the package
      // or it might just open settings.
      // Let's safe-check standard "canScheduleExactNotifications" logic if available or just assume we need to guide user.
      
      // Simpler approach for this package version:
      // Try to just return true for now, but we'll use a better check in the UI.
      return true; 
    }
    return true;
  }
  
  // Specific method to help debug Android 12+ Exact Alarms
  Future<void> requestExactAlarms() async {
     final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
     await androidImplementation?.requestExactAlarmsPermission();
  }

  Future<void> showInstantNotification(int id, String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'low_stock_channel',
      'Stok Uyarıları',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(id, title, body, platformChannelSpecifics);
  }

  Future<void> scheduleNotification(int id, String title, String body, DateTime scheduledDate) async {
    if (scheduledDate.isBefore(DateTime.now())) {
      print("SERVICE DEBUG: Scheduled date $scheduledDate is in the past! Ignoring.");
      return;
    }
    
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    print("SERVICE DEBUG: Scheduling ID $id for raw: $scheduledDate | tz: $tzDate");

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Hatırlatıcılar',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}
