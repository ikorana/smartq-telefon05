# 🌳 Akıllı Bahçe ve Çevre Ekosistemi Mimari Dökümanı (V2.0)

Bu döküman, **Olay Odaklı (Event-Driven)** ve **Öncelik Esaslı Rol Modeli (Priority-Based Role Model)** ile bahçe otomasyonunun (Aydınlatma, Sulama, Güvenlik) yönetim prensiplerini belirler.

---

## 1. KATMAN: Ortak Olay Havuzu (Unified Event Pool)
Sistemdeki tüm donanım ve yazılım tetikleyicileri bu havuza sinyal yayınlar. Roller bu havuzdaki olaylara abone olur.

### A. Çevresel ve Astro Olaylar
*   **SUNSET / SUNRISE**: Astronomik saat verisi (Hava karardı/aydınlandı).
*   **RAIN_DETECTED**: Yağmur sensörü verisi (Boolean).
*   **TEMP_UPDATE**: Konum bazlı sıcaklık verisi (Location + Value). Hem iç mekan hem dış mekan için ortak kullanılır.
*   **WIND_STRENGTH**: Rüzgar hızı verisi (Sulama güvenliği için).

### B. Varlık ve Giriş Olayları
*   **MOTION_ZONE_[X]**: Belirli bir bölgede hareket algılandı.
*   **STAY_CONTINUOUS**: Bir bölgede uzun süreli (5 dk+) varlık tespiti (Sosyal aktivite algılama).
*   **GATE_EVENT**: Kapıların (Bahçe, Garaj) açılma veya kapanma sinyali.

### C. Güvenlik Olayları
*   **ALARM_STATE**: Ev alarm sisteminin durumu (Kurulu/Devre Dışı/Alarmda).
*   **PERIMETER_BREACH**: Sınır ihlali (Lazer/Beam sensörleri).

---

## 2. KATMAN: Sistem Rolleri ve Öncelik (Roles & Priority)
Sistem, mantığını roller üzerinden yürütür. Her rolün bir öncelik (Priority) değeri vardır.

### 💡 Aydınlatma Rolleri
| Rol Adı | Öncelik (1-100) | Görevi |
| :--- | :---: | :--- |
| **DETERRENT** | 100 | Caydırıcılık (Alarm anında flaşör yapma) |
| **WELCOME_PATH**| 60 | Karşılama (Kapı açıldığında yolu aydınlatma) |
| **SOCIAL_ZONE** | 50 | Sosyal (Manuel veya misafir modunda tam aydınlatma) |
| **SECURITY** | 30 | Güvenlik (Gün batımından sonra sabit aydınlatma) |
| **NAVIGATION** | 20 | Yönlendirme (Gece yarısı sadece harekete duyarlı aydınlatma) |

### 💧 Sulama Rolleri
| Rol Adı | Öncelik (1-100) | Görevi |
| :--- | :---: | :--- |
| **EMERGENCY_OFF**| 100 | Acil Durdurma (Don riski veya bahçede insan varken kapatma) |
| **RAIN_DELAY** | 90 | Yağmur Geciktirme (Yağmurda sulamayı iptal etme) |
| **HEAT_BOOST** | 40 | Sıcaklık Desteği (Aşırı sıcakta ek sulama yapma) |
| **DAILY_PLAN** | 10 | Günlük Plan (Zamanlanmış standart sulama) |

---

## 3. KATMAN: Segmentasyon (Logical Grouping)
Fiziksel röleler, mantıksal segmentlere bölünür. Bir segment birden fazla role atanabilir.
*   *Örnek:* "Giriş Yolu" segmenti hem **SECURITY** (30) hem de **WELCOME_PATH** (60) rollerine abonedir.

---

## 4. KATMAN: Çakışma Çözümleme (Conflict Resolution)
Aynı segment üzerinde çelişen komutlar (Aç/Kapat) gelirse izlenecek algoritma:
1.  **Aktif Rolleri Belirle:** Tetiklenen tüm rolleri listele.
2.  **Öncelik Kıyaslaması:** Aktif roller içinden **en yüksek Priority** değerine sahip olanı seç.
3.  **Kararı Uygula:** Fiziksel röleyi bu kazanan rolün istediği konuma getir.

---

## 5. KATMAN: Güvenlik ve Donanım Protokolleri
*   **Pompa Gecikmesi (Start Delay):** Vana açıldıktan 2 saniye sonra pompa çalışır.
*   **Vana Çakıştırma (Overlap):** Bir vana kapanmadan 3 saniye önce diğeri açılır (Su çekici koruması).
*   **Akış Kontrolü (Flow Check):** 30 saniye içinde akış gelmezse sistemi durdurur.

---

## 6. ÖRNEK VERİ YAPISI (JSON)
```json
{
  "system": "Integrated_Garden_V1",
  "segments": [
    {
      "id": "SEG_01",
      "name": "Mutfak Önü Çimler",
      "type": "irrigation",
      "relay_id": 5,
      "roles": ["DAILY_PLAN", "EMERGENCY_OFF"]
    }
  ]
}
```
