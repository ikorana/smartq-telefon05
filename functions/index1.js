

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