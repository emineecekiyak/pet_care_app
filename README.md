# 🐾 Pet Care Assistant - Akıllı Evcil Hayvan Takip Uygulaması

Bu proje, Mobil Programlama Dersi Final Projesi kapsamında Flutter & Dart kullanılarak geliştirilmiştir. Evcil hayvan sahiplerinin günlük bakım, sağlık ve beslenme süreçlerini dijital ortamda profesyonelce yönetmelerini sağlar.

---

## 📺 YouTube Tanıtım Videosu
> **Video Linki:** https://youtu.be/RdVl43f8hlk

---

## 🎯 Projenin Amacı ve Senaryosu

### 1. Bu uygulama kimin işine yarar?
Uygulama, bir veya birden fazla evcil hayvana (kedi, köpek vb.) sahip olan; onların aşı takvimini, veteriner randevularını ve hassas beslenme düzenlerini takip etmek isteyen tüm bireysel kullanıcıların işine yarar.

### 2. Hangi problemi çözer?
*   **Aşı Unutkanlığı:** Karmaşık aşı takvimlerini otomatik hatırlatıcılar ile yöneterek sağlık risklerini azaltır.
*   **Beslenme Düzensizliği:** Hayvanın yaşına ve kilosuna göre günlük ne kadar yemesi gerektiğini hesaplayarak obezite riskini önler.
*   **Stok Yönetimi:** "Evde mama bitti mi?" stresini, gram bazlı stok takibi ve düşük stok bildirimleri ile çözer.
*   **Kayıt Dağınıklığı:** Veteriner kağıtları arasında kaybolmak yerine tüm sağlık geçmişini tek bir dijital merkezde toplar.

### 3. Nerede ve nasıl kullanılır?
Evde, sokakta veya veterinerde; ihtiyaç duyulan her an mobil cihaz üzerinden kullanılır. Kullanıcı uygulamayı açar, evcil hayvanını kaydeder, mevcut mama stoğunu girer ve uygulama üzerinden günlük beslemelerini yaparak tüm süreci izler.

---

## ✨ Temel Özellikler

*   **📈 Akıllı Beslenme Sistemi:** Yaş, kilo ve tür bazlı otomatik gramaj hesaplama.
*   **📦 Envanter Takibi:** Mama azaldığında (160g altı) otomatik bildirim.
*   **🏥 Sağlık Yönetimi:** Firestore tabanlı, her yerden erişilebilir aşı ve randevu defteri.
*   **💉 Aşı Şablonları:** Yavru ve yetişkin kedi/köpekler için hazır sağlık takvimleri.
*   **🌗 Dinamik Tema:** Tam uyumlu Aydınlık ve Karanlık mod desteği.
*   **🔔 Yerel Bildirimler:** Aşı ve randevu günü sabahında gelen akıllı hatırlatıcılar.

---

## 🛠️ Teknik Altyapı

*   **Framework:** Flutter / Dart
*   **Veritabanı:** Firebase Firestore (Bulut Tabanlı Gerçek Zamanlı Veritabanı) - Tam CRUD işlemleri.
*   **Authentication:** Firebase Auth (Kullanıcı Oturumu Yönetimi).
*   **Yerel Depolama:** `SharedPreferences` (Kullanıcı profili ve tema tercihleri).
*   **Bildirimler:** `flutter_local_notifications` & `timezone`.
*   **Mimari:** Modüler widget yapısı, Singleton Database Helper, Stream-based Data Flow.

---

## 🚀 Kurulum

1.  Projeyi klonlayın: `git clone [repo-url]`
2.  Bağımlılıkları yükleyin: `flutter pub get`
3.  Uygulamayı çalıştırın: `flutter run`

---

## 👨‍💻 Geliştirici
*   **Ad Soyad:** EMİNE ECE KIYAK
*   **Öğrenci No:** 132230013

---
*Bu proje bireysel olarak geliştirilmiştir.*
