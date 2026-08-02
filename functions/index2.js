const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const jwt = require("jsonwebtoken");

// AI ENTEGRASYONU İÇİN GEREKLİ KÜTÜPHANELER
const { genkit } = require("genkit");
const { googleAI } = require("@genkit-ai/googleai");
const { z } = require("zod");

admin.initializeApp();

// Genkit'i model belirtmeden, sadece plugin ile yalın başlatıyoruz
const aiInstance = genkit({
  plugins: [
    googleAI({ apiKey: process.env.GEMINI_API_KEY })
  ],
});

/**
 * YARDIMCI FONKSİYON: Open-Meteo Geocoding API ile Türkçe il/ilçe adını lat/lng'e çevirir.
 * API key gerektirmez. Hem updateDeviceLocation hem getIrrigationDecision tarafından kullanılır.
 */
async function geocodeLocation(location) {
  const geoUrl = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(location)}&count=1&language=tr&country=TR`;
  const geoResp = await fetch(geoUrl);
  if (!geoResp.ok) throw new Error(`Geocoding servisi hata döndürdü: ${geoResp.status}`);
  const geoData = await geoResp.json();
  if (!geoData.results || geoData.results.length === 0) {
    throw new Error(`'${location}' için konum bulunamadı.`);
  }
  return {
    lat: geoData.results[0].latitude,
    lng: geoData.results[0].longitude,
    name: geoData.results[0].name
  };
}

/**
 * 1. FONKSİYON: registerHardwareDevice
 * Ana kutunun (Hardware) kendini veritabanına kaydetmesini / güncellemesini sağlar.
 * GÜNCELLEME: Sayısal 0 (sıfır) değerlerinin hata fırlatması engellendi.
 */
exports.registerHardwareDevice = onRequest(async (req, res) => {
  try {
    const { lisansKodu, projeNo, binaNo, katNo, daireNo, version, ip } = req.body.data || {};

    // GÜVENLİ KONTROL: Değerlerin varlığı explicit (null/undefined) olarak kontrol ediliyor, 0 artık yasal.
    if (
      lisansKodu === undefined || lisansKodu === null || lisansKodu === "" ||
      projeNo === undefined || projeNo === null ||
      binaNo === undefined || binaNo === null ||
      daireNo === undefined || daireNo === null
    ) {
      return res.status(400).send({
        data: { status: "error", message: "lisansKodu, projeNo, binaNo ve daireNo alanları zorunludur." }
      });
    }

    const db = admin.firestore();

    // Doküman ID'si (anahtar) olarak doğrudan lisansKodu kullanılıyor
    await db.collection("cihaz_kayitlari").doc(lisansKodu).set({
      // String Değerler
      lisansKodu: String(lisansKodu),
      version: version ? String(version) : "0.0.0",
      ip: ip ? String(ip) : "0.0.0.0",

      // Number (Sayısal) Değerler
      projeNo: Number(projeNo),
      binaNo: Number(binaNo),
      katNo: Number(katNo),
      daireNo: Number(daireNo),

      // Zaman Damgası
      sonKayitTarihi: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return res.status(200).send({ data: { status: "success", message: "Ana kutu kaydı/güncellemesi başarılı." } });

  } catch (error) {
    return res.status(500).send({ data: { status: "error", message: error.message } });
  }
});

/**
 * 2. FONKSİYON: getHardwareDevices
 * Yönetim programının filtre göndererek daire/cihaz listesi almasını sağlar.
 */
exports.getHardwareDevices = onRequest(async (req, res) => {
  try {
    const { projeNo, binaNo, katNo, daireNo, lisansKodu } = req.body.data || {};

    const db = admin.firestore();
    let query = db.collection("cihaz_kayitlari");

    if (projeNo !== undefined && projeNo !== null) {
      query = query.where("projeNo", "==", Number(projeNo));
    }
    if (binaNo !== undefined && binaNo !== null) {
      query = query.where("binaNo", "==", Number(binaNo));
    }
    if (katNo !== undefined && katNo !== null) {
      query = query.where("katNo", "==", Number(katNo));
    }
    if (daireNo !== undefined && daireNo !== null) {
      query = query.where("daireNo", "==", Number(daireNo));
    }
    if (lisansKodu) {
      query = query.where("lisansKodu", "==", String(lisansKodu));
    }

    const snapshot = await query.get();
    const cihazListesi = [];

    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.sonKayitTarihi) {
        data.sonKayitTarihi = data.sonKayitTarihi.toDate().toISOString();
      }
      cihazListesi.push(data);
    });

    return res.status(200).send({
      data: {
        status: "success",
        totalCount: cihazListesi.length,
        devices: cihazListesi
      }
    });

  } catch (error) {
    console.error("Listeleme Hatası:", error);
    return res.status(500).send({ data: { status: "error", message: error.message } });
  }
});

/**
 * 3. FONKSİYON: kaydetCihazToken
 */
exports.kaydetCihazToken = onRequest(async (req, res) => {
  try {
    const { cihazId, platform, fcmToken, license } = req.body.data || {};
    if (!cihazId || !fcmToken) return res.status(400).send({ data: { status: "error", message: "Eksik parametre." } });
    const db = admin.firestore();
    await db.collection("cihazlar").doc(cihazId).set({
      cihazId, platform, fcmToken, license: license || "free_trial", sonGuncelleme: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    return res.status(200).send({ data: { status: "success", message: "Cihaz başarıyla kaydedildi." } });
  } catch (error) {
    return res.status(500).send({ data: { status: "error", message: error.message } });
  }
});

/**
 * 4. FONKSİYON: sendAlarmNotification
 */
exports.sendAlarmNotification = onRequest(async (req, res) => {
  try {
    const { type, target, title, body, text } = req.body.data || {};
    const db = admin.firestore();
    let tokens = [];

    if (!type) return res.status(400).send({ data: { status: "error", message: "Eksik 'type' parametresi." } });

    if (type === "single") {
      if (!target) return res.status(400).send({ data: { status: "error", message: "target gerekli." } });
      tokens.push(target);
    } else if (type === "license") {
      if (!target) return res.status(400).send({ data: { status: "error", message: "target gerekli." } });
      const snapshot = await db.collection("cihazlar").where("license", "==", target).get();
      snapshot.forEach(doc => { if (doc.data().fcmToken) tokens.push(doc.data().fcmToken); });
    } else if (type === "all") {
      const snapshot = await db.collection("cihazlar").get();
      snapshot.forEach(doc => { if (doc.data().fcmToken) tokens.push(doc.data().fcmToken); });
    }

    if (tokens.length === 0) return res.status(200).send({ data: { status: "success", message: "Cihaz bulunamadı." } });

    const customData = {};
    if (text) {
      customData.com = "say";
      customData.txt = String(text);
    }

    const message = {
      notification: {
        title: title || "🚨 SİSTEM ALARMI!",
        body: body || "Donanım üzerinden kritik bir alarm tetiklendi.",
      },
      data: Object.keys(customData).length > 0 ? customData : undefined,
      tokens: tokens,
      android: {
        priority: "high",
        notification: { sound: "default", channelId: "alarm_channel", priority: "high" }
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "default" } }
      }
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    return res.status(200).send({ data: { status: "success", sentCount: response.successCount } });

  } catch (error) {
    console.error("Hata:", error);
    return res.status(500).send({ data: { status: "error", message: error.message } });
  }
});

/**
 * 5. FONKSİYON: interpretVoiceCommand
 * Doğal dil komutlarını SmartQ cihazlarının anlayacağı kesin JSON şemasına çevirir.
 */
exports.interpretVoiceCommand = onRequest({ secrets: ["GEMINI_API_KEY"] }, async (req, res) => {
  try {
    const { userPrompt, projeNo, binaNo, daireNo } = req.body.data || {};

    if (!userPrompt) {
      return res.status(400).send({ data: { status: "error", message: "userPrompt alanı zorunludur." } });
    }

    // Gelişmiş Akıllı Ev Cihaz, Mod, Senaryo ve Grup Şeması (Zod)
    const CommandSchema = z.object({
      targetType: z.enum([
        "device", "mode", "scene", "group", "unknown"
      ]).describe("Komutun doğrudan hedef aldığı ana yapı türü. Doğrudan bir cihazsa 'device', ev moduysa 'mode', 16 senaryodan biriyse 'scene', bir cihaz grubu hedefliyse 'group' seçilmelidir."),

      deviceType: z.enum([
        "blind", "door", "elevator", "energy", "garage",
        "gas", "water", "socket", "lamp", "rgb", "climate", "none"
      ]).default("none").describe("Eğer targetType 'device' veya 'group' ise, hedef alınan akıllı ev cihazının türü. Mod veya senaryolarda 'none' olmalıdır."),

      action: z.enum(["ON", "OFF", "SET_VALUE", "STATUS_CHECK"])
        .describe("Cihaza, moda, senaryoya veya gruba yaptırılacak eylem. Mod/Senaryo aktivasyonları için her zaman 'ON' kullanılmalıdır."),

      // 1. GLOBAL EV MODU (Mode)
      mode: z.enum(["normal", "night", "day", "away", "guest"])
        .default("normal")
        .describe("Kullanıcının geçmek istediği genel ev modu. Spesifik bir mod belirtilmemişse 'normal' kalmalıdır. Örn: 'gece modu' -> 'night', 'evden çıkış/dışarı modu' -> 'away'"),

      // 2. 16 ADET ÖZEL SENARYO (Scene)
      sceneNo: z.number().min(0).max(16).default(0)
        .describe("Kullanıcı 16 senaryodan birini tetiklediyse senaryo numarası (1-16 arası). Eğer senaryo tetiklenmediyse 0 olmalıdır. Örn: 'Sinema senaryosunu aç' (Eğer sinema 1. senaryoysa) -> 1, 'Senaryo 5'i aktif et' -> 5"),

      // 3. GRUP YÖNETİMİ (Group)
      groupNo: z.number().default(0)
        .describe("Kullanıcı belirli bir grubu hedeflediyse grup numarası (Örn: 'Grup 2'yi kapat' -> 2, '3. grup ışıkları aç' -> 3). Grup belirtilmediyse 0 olmalıdır."),

      isAll: z.boolean()
        .describe("Eğer kullanıcı 'tüm', 'hepsi', 'her yer' gibi bir kelime kullanarak o gruptaki veya evdeki tüm cihazları hedeflediyse true, tek bir cihazı/grubu hedeflediyse false olmalıdır. Çoğul ekleri (lambalar, perdeler) tek başına grubu veya senaryoyu ifade etmiyorsa true yapabilir."),

      value: z.number().optional()
        .describe("Dimmer yüzdesi, rgb parlaklığı veya termostat sıcaklık derecesi (Varsa)"),

      name: z.string().optional()
        .describe("Eğer kullanıcı 'mavi led', 'mutfak lambası', 'sinema senaryosu', 'bahçe grubu' gibi özel bir isim belirtmişse buraya aynen yazılmalıdır."),

      targetZone: z.string().optional()
        .describe("Komutun hedeflediği genel oda veya bölge (salon, mutfak, koridor vb.)"),

      responseMessage: z.string()
        .describe("Kullanıcıya mobil uygulamada dönecek sesli/yazılı Türkçe yanıt")
    });

    // Gemini ile şemalı analiz çağrısı
    const aiResponse = await aiInstance.generate({
      model: 'googleai/gemini-2.5-flash',
      prompt: `Kullanıcı Komutu: "${userPrompt}"\nBağlam -> Proje: ${projeNo || 1}, Bina: ${binaNo || 0}, Daire: ${daireNo || 0}`,
      output: {
        schema: CommandSchema,
      },
      system: `Sen SmartQ akıllı ev otomasyon sisteminin yapay zeka motorusun.
               Kullanıcılardan gelen Türkçe doğal dil komutlarını cihazların, modların, senaryoların ve grupların işleyebileceği saf verilere dönüştürürsün.

               KRİTİK HEDEF AYRIMI KURALLARI:
               1. TARGET_TYPE SEÇİMİ:
                  - Eğer komut tekil bir cihazı veya genel cihaz sınıfını hedefliyorsa (Örn: "ışığı yak", "klmayı kapat"): targetType = "device"
                  - Eğer komut global bir ev modunu hedefliyorsa (Örn: "gece moduna geç", "evden çıkış modu"): targetType = "mode"
                  - Eğer komut 16 senaryodan birini hedefliyorsa (Örn: "1. senaryoyu çalıştır", "kitap okuma senaryosunu aç"): targetType = "scene"
                  - Eğer komut tanımlı bir grubu hedefliyorsa (Örn: "2. grubu kapat", "bahçe grubunu aç"): targetType = "group"

               2. MOD (MODE) KURALLARI:
                  - Bir moda geçiş istendiğinde targetType="mode", action="ON" olmalı ve 'mode' alanı uygun değere (night, day, away, guest) setlenmelidir.

               3. SENARYO (SCENE) KURALLARI:
                  - Kullanıcı ismen veya numarayla bir senaryo tetiklediğinde targetType="scene", action="ON" olmalı ve 'sceneNo' alanına 1-16 arası ilgili sayı yazılmalıdır. Cümlede numara geçmiyorsa ama bilinen bir akıllı ev senaryosuysa (Örn: Sinema, Romantik, Kitap Okuma, Parti) mantıklı bir senaryo numarası ata veya name alanına yazıp sceneNo'yu belirle.

               4. GRUP (GROUP) KURALLARI:
                  - Kullanıcı grup belirttiğinde targetType="group", 'groupNo' alanına ilgili grup numarası yazılmalıdır. Eyleme göre action "ON" veya "OFF" olur.

               5. GENEL CİHAZ VE EYLEM KURALLARI:
                  - deviceType alanı sadece targetType 'device' veya 'group' olduğunda doldurulur (blind, lamp, climate vb.). Mod ve senaryolarda "none" kalır.
                  - action alanı KESİNLİKLE çıktıya eklenmelidir. Açma/Aktif etme="ON", Kapatma="OFF", Derece/Yüzde="SET_VALUE", Durum sorma="STATUS_CHECK" olmalıdır.
                  - isAll alanı; "tüm lambalar", "her yeri kapat" gibi toplu cihaz komutlarında true olmalıdır.
                  - responseMessage alanına her zaman doğal, onaylayıcı ve asistan üslubuna uygun Türkçe bir cümle yaz.`
    });

    return res.status(200).send({
      data: {
        status: "success",
        command: aiResponse.output
      }
    });

  } catch (error) {
    console.error("AI Yorumlama Hatası:", error);
    return res.status(500).send({ data: { status: "error", message: error.message } });
  }
});

/**
 * 6. FONKSİYON: updateDeviceLocation
 * Cihazın sulama konumunu AÇIKÇA ve KOŞULSUZ olarak günceller/kaydeder.
 * İki senaryoda çağrılmalıdır:
 *   1) İlk kurulum sırasında (embedded veya web arayüzünden)
 *   2) Cihaz fiziksel olarak taşındığında
 * getIrrigationDecision bu fonksiyonun yazdığı cache'i SADECE OKUR, kendisi konum
 * değişikliğini tespit etmeye çalışmaz — sorumluluk ayrımı burada net tutulmuştur.
 *
 * Girdi JSON örnekleri:
 *   {"lisansKodu":"ABC123","location":"istanbul maltepe"}
 *   {"lisansKodu":"ABC123","lat":40.93,"lng":29.15}
 */
exports.updateDeviceLocation = onRequest(async (req, res) => {
  try {
    const { lisansKodu, location, lat, lng } = req.body.data || {};

    if (!lisansKodu) {
      return res.status(400).send({ data: { status: "error", message: "'lisansKodu' alanı zorunludur." } });
    }
    if ((lat === undefined || lng === undefined) && !location) {
      return res.status(400).send({ data: { status: "error", message: "'location' ya da 'lat'/'lng' ikilisi zorunludur." } });
    }

    let resolved;
    if (lat !== undefined && lng !== undefined) {
      resolved = { lat: Number(lat), lng: Number(lng), name: location || `${lat},${lng}` };
    } else {
      resolved = await geocodeLocation(location);
    }

    const db = admin.firestore();
    await db.collection("cihaz_kayitlari").doc(String(lisansKodu)).set({
      sulamaLat: resolved.lat,
      sulamaLng: resolved.lng,
      sulamaLocationName: resolved.name,
      sulamaLocationGuncelleme: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return res.status(200).send({
      data: { status: "success", message: "Konum güncellendi.", lat: resolved.lat, lng: resolved.lng, location: resolved.name }
    });

  } catch (error) {
    console.error("Konum Güncelleme Hatası:", error);
    return res.status(500).send({ data: { status: "error", message: error.message } });
  }
});

/**
 * 7. FONKSİYON: getIrrigationDecision
 * Cihazdan gelen konum + planlanan sulama saati/süresine göre, GERÇEK hava durumu
 * verisini (Open-Meteo, API key gerektirmez) çekip AI'a yorumlatarak nihai sulama
 * süresini belirler. AI'a "hava nasıl?" diye SORULMAZ; ham hava verisi ona verilir,
 * o sadece bu veriyi yorumlar. Böylece halüsinasyon riski ortadan kalkar.
 *
 * 'duration' bir BAZ/ORTALAMA süredir, sabit tavan değildir — AI mevsimsel/hava koşullarına
 * göre bu süreyi artırabilir veya azaltabilir. GÜVENLİK KELEPÇESİ: AI'ın döndürdüğü süre
 * (a) girdideki 'duration'ın en fazla 2 katı olabilir, (b) sistem genelinde tanımlı mutlak
 * bir tavanı (AI_MAX_ABSOLUTE_MINUTES) hiçbir koşulda aşamaz. Bu kod-seviyesi kelepçe,
 * modelin hatalı/aşırı bir değer üretmesi durumunda fiziksel taşkın/su israfı riskini
 * prompt'a değil, koda bağlı sabit bir kurala dayandırır.
 *
 * KONUM KAYNAĞI: Bu fonksiyon konum kıyaslaması YAPMAZ, sadece okur.
 *   - lat/lng doğrudan gönderilirse onu kullanır (tek seferlik override, cache'e yazmaz).
 *   - lisansKodu gönderilirse Firestore cache'inden (cihaz_kayitlari/{lisansKodu}) okur.
 *   - Cache boşsa ve 'location' de gönderilmemişse hata döner — önce updateDeviceLocation
 *     çağrılmalıdır (ilk kurulum) ya da cihaz taşındıysa yine updateDeviceLocation.
 *
 * Girdi JSON örnekleri:
 *   {"lisansKodu":"ABC123","time":"05:20","duration":15}   // konum cache'ten okunur
 *   {"lat":40.93,"lng":29.15,"time":"05:20","duration":15} // tek seferlik override
 */
exports.getIrrigationDecision = onRequest({ secrets: ["GEMINI_API_KEY"] }, async (req, res) => {
  try {
    const { lisansKodu, lat, lng, time, duration } = req.body.data || {};

    // GİRDİ DOĞRULAMA
    const requestedDuration = Number(duration);
    if (!time || typeof time !== "string" || !/^\d{2}:\d{2}$/.test(time)) {
      return res.status(400).send({ data: { status: "error", message: "'time' alanı HH:MM formatında zorunludur." } });
    }
    if (!Number.isFinite(requestedDuration) || requestedDuration < 0) {
      return res.status(400).send({ data: { status: "error", message: "'duration' alanı zorunlu ve sıfır veya pozitif bir sayı olmalıdır." } });
    }
    if ((lat === undefined || lng === undefined) && !lisansKodu) {
      return res.status(400).send({ data: { status: "error", message: "'lisansKodu' ya da 'lat'/'lng' ikilisi zorunludur." } });
    }

    // 1. ADIM: KONUM ÇÖZÜMLEME — sadece override ya da cache okuma, geocode YOK
    let resolvedLat = lat !== undefined ? Number(lat) : null;
    let resolvedLng = lng !== undefined ? Number(lng) : null;
    let resolvedName = (lat !== undefined && lng !== undefined) ? `${lat},${lng}` : null;

    if (resolvedLat === null || resolvedLng === null) {
      const deviceSnap = await admin.firestore().collection("cihaz_kayitlari").doc(String(lisansKodu)).get();
      const d = deviceSnap.exists ? deviceSnap.data() : null;
      if (!d || d.sulamaLat === undefined || d.sulamaLng === undefined) {
        return res.status(400).send({
          data: { status: "error", message: "Bu lisans için kayıtlı konum yok. Önce 'updateDeviceLocation' çağrılmalıdır." }
        });
      }
      resolvedLat = d.sulamaLat;
      resolvedLng = d.sulamaLng;
      resolvedName = d.sulamaLocationName;
    }

    // 2. ADIM: GERÇEK SAATLİK HAVA VERİSİ ÇEKME (Open-Meteo, key gerektirmez)
    const weatherUrl = `https://api.open-meteo.com/v1/forecast?latitude=${resolvedLat}&longitude=${resolvedLng}` +
      `&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,precipitation,wind_speed_10m` +
      `&timezone=Europe%2FIstanbul&forecast_days=2`;
    const weatherResp = await fetch(weatherUrl);
    if (!weatherResp.ok) throw new Error(`Hava durumu servisi hata döndürdü: ${weatherResp.status}`);
    const weatherData = await weatherResp.json();

    // İstenen 'time' saatine en yakın saatlik veri noktasını bul (bugünün tarihiyle)
    const todayStr = new Date().toISOString().slice(0, 10);
    const targetTimestamp = new Date(`${todayStr}T${time}:00`).getTime();
    const hourlyTimes = weatherData.hourly.time;
    let closestIdx = 0;
    let closestDiff = Infinity;
    hourlyTimes.forEach((t, idx) => {
      const diff = Math.abs(new Date(t).getTime() - targetTimestamp);
      if (diff < closestDiff) { closestDiff = diff; closestIdx = idx; }
    });

    const weatherFacts = {
      sicaklikC: weatherData.hourly.temperature_2m[closestIdx],
      nemYuzde: weatherData.hourly.relative_humidity_2m[closestIdx],
      yagisIhtimaliYuzde: weatherData.hourly.precipitation_probability[closestIdx],
      yagisMm: weatherData.hourly.precipitation[closestIdx],
      ruzgarKmh: weatherData.hourly.wind_speed_10m[closestIdx]
    };

    // 3. ADIM: AI'A HAM VERİYİ VERİP SADECE YORUMLATMA (veri üretmesi değil, yorumlaması isteniyor)
    const IrrigationSchema = z.object({
      duration: z.number().min(0).describe("Önerilen sulama süresi (dakika). Asla girdideki istenen süreyi aşmamalı, sadece azaltılabilir veya 0 yapılabilir."),
      reason: z.string().describe("Kararın kısa Türkçe gerekçesi (örn. 'Yüksek yağış ihtimali nedeniyle sulama iptal edildi.')")
    });

    const aiResponse = await aiInstance.generate({
      model: 'googleai/gemini-2.5-flash',
      prompt: `Konum: ${resolvedName}\nPlanlanan sulama saati: ${time}\nİstenen (maksimum) sulama süresi: ${requestedDuration} dakika\n` +
        `Güncel hava verisi -> Sıcaklık: ${weatherFacts.sicaklikC}°C, Nem: %${weatherFacts.nemYuzde}, ` +
        `Yağış ihtimali: %${weatherFacts.yagisIhtimaliYuzde}, Yağış miktarı: ${weatherFacts.yagisMm}mm, Rüzgar: ${weatherFacts.ruzgarKmh}km/s`,
      output: { schema: IrrigationSchema },
      system: `Sen bir akıllı bahçe/çim sulama sisteminin karar destek motorusun.
               Sana verilen GERÇEK hava verisine dayanarak, planlanan (baz) sulama süresini artırıp azaltmaya karar verirsin.
               Girdideki süre bir ORTALAMA/BAZ değerdir, sabit bir tavan değildir; mevsimsel kuraklık veya yüksek sıcaklıkta artırabilirsin.
               KURALLAR:
               1. Yağış ihtimali yüksekse (%60 üzeri) veya son/yakın saatlerde belirgin yağış (1mm üzeri) varsa süreyi düşür veya 0 yap.
               2. Nem oranı çok yüksekse (%85 üzeri) süreyi azalt.
               3. Rüzgar çok yüksekse (30km/s üzeri) sulama verimsiz ve savurma riskli olur, süreyi azalt.
               4. Hava çok sıcak (30°C üzeri) ve kuruysa (nem %40 altı, yağış ihtimali düşük), baz süreyi makul ölçüde artırabilirsin.
               5. Normal/ortalama koşullarda baz süreyi olduğu gibi koru.
               6. reason alanına kısa, anlaşılır bir Türkçe gerekçe yaz.`
    });

    // 4. ADIM: GÜVENLİK KELEPÇESİ — kod seviyesinde sabit kurallar, prompt'a güvenilmiyor.
    // AI baz süreyi en fazla 2 katına çıkarabilir, AMA sistem genelinde mutlak bir tavanı
    // (AI_MAX_ABSOLUTE_MINUTES) hiçbir koşulda aşamaz. Bu ikinci sınır, cihazdan anormal
    // düşük/yüksek bir 'duration' gelse bile fiziksel taşkın riskine karşı sabit bir korumadır.
    const AI_MAX_ABSOLUTE_MINUTES = 60;
    const aiDuration = Number(aiResponse.output?.duration);
    const safeDuration = Number.isFinite(aiDuration)
      ? Math.min(Math.max(0, aiDuration), requestedDuration * 2, AI_MAX_ABSOLUTE_MINUTES)
      : requestedDuration; // AI/parse hatasında güvenli varsayılan: orijinal planlanan süreyi koru

    return res.status(200).send({
      data: {
        status: "success",
        duration: safeDuration,
        reason: aiResponse.output?.reason || "Değerlendirme tamamlandı.",
        location: resolvedName,
        weather: weatherFacts
      }
    });

  } catch (error) {
    console.error("Sulama Kararı Hatası:", error);
    // HATA DURUMUNDA GÜVENLİ VARSAYILAN: hava verisi alınamazsa orijinal planı uygula,
    // sistemi tamamen durdurmak (çimin susuz kalması) yerine normal sulamaya izin ver.
    const fallbackDuration = Number(req.body?.data?.duration);
    return res.status(200).send({
      data: {
        status: "fallback",
        duration: Number.isFinite(fallbackDuration) ? fallbackDuration : 0,
        message: "Hava verisi alınamadı, planlanan süre uygulanıyor: " + error.message
      }
    });
  }
});