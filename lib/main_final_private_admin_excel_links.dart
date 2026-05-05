import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:excel/excel.dart' as xls;
import 'dart:typed_data';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAt3tmuiAHLb1cPEra0KjmF5ytiUSftdz8",
        appId: "1:103359671597:ios:f8eb16640261073ee037a4",
        messagingSenderId: "103359671597",
        projectId: "sapan-takip",
        storageBucket: "sapan-takip.firebasestorage.app",
        iosBundleId: "com.mertalkan.sapantakip",
      ),
    );
    runApp(MyApp());
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            "Firebase başlatma hatası:\n$e",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ));
  }
}

const Color anaRenk = Color(0xFF1E3A8A);
const String logoPath = "assets/images/anonim_logo.png";

Future<String> aktifKullaniciAdi() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return "Bilinmiyor";

  final doc = await FirebaseFirestore.instance
      .collection('kullanicilar')
      .doc(user.uid)
      .get();

  return doc.data()?['adSoyad'] ?? user.email ?? "Bilinmiyor";
}

Future<bool> aktifKullaniciAdminMi() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final doc = await FirebaseFirestore.instance
      .collection('kullanicilar')
      .doc(user.uid)
      .get();

  return doc.data()?['admin'] == true;
}

String kontrolDurumuHesapla(Map<String, dynamic> data) {
  final mevcutDurum = data['durum'] ?? 'Aktif';

  if (mevcutDurum == "Kullanım Dışı") return "Kullanım Dışı";

  final sonKontrolTarihi = data['sonKontrolTarihi'];
  final periyot = data['kontrolPeriyodu'] ?? 'Günlük';

  if (sonKontrolTarihi == null) return "Kontrol Gerekli";

  final DateTime tarih = (sonKontrolTarihi as Timestamp).toDate();
  final farkGun = DateTime.now().difference(tarih).inDays;

  if (periyot == "Günlük" && farkGun >= 1) return "Kontrol Gerekli";
  if (periyot == "Haftalık" && farkGun >= 7) return "Kontrol Gerekli";
  if (periyot == "Aylık" && farkGun >= 30) return "Kontrol Gerekli";

  return "Aktif";
}

String tarihYaz(dynamic tarih) {
  if (tarih == null) return "-";
  final dt = (tarih as Timestamp).toDate();
  return "${dt.day}.${dt.month}.${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sapan Takip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: anaRenk,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: anaRenk,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: anaRenk,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: AuthCheck(),
    );
  }
}

class AuthCheck extends StatelessWidget {
  Future<DocumentSnapshot<Map<String, dynamic>>> kullaniciDoc(User user) {
    return FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(user.uid)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LoginPage();

        final user = snapshot.data!;

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: kullaniciDoc(user),
          builder: (context, userDocSnap) {
            if (userDocSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userDocSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Yetki kontrol hatası:\n${userDocSnap.error}",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final doc = userDocSnap.data;

            if (doc == null || !doc.exists) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Bu kullanıcı Firestore'da kayıtlı değil.\n\nUID:\n${user.uid}\n\nEmail:\n${user.email}",
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                          child: const Text("Giriş ekranına dön"),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final data = doc.data();
            final aktif = data != null && data['aktif'] == true;

            if (aktif) {
              return SapanListesi();
            }

            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Bu kullanıcı aktif değil.\n\nUID:\n${user.uid}\n\nEmail:\n${user.email}",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                        child: const Text("Giriş ekranına dön"),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class LoginPage extends StatelessWidget {
  final email = TextEditingController();
  final pass = TextEditingController();
  Future<void> giris(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: pass.text.trim(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Giriş hatası: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 420,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 12),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(logoPath, height: 90),
                const SizedBox(height: 18),
                const Text(
                  "SAPAN TAKİP",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: anaRenk,
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Şifre",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => giris(context),
                    child: const Text("Giriş Yap"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SapanListesi extends StatefulWidget {
  @override
  _SapanListesiState createState() => _SapanListesiState();
}

class _SapanListesiState extends State<SapanListesi> {
  String arama = "";

  Color durumRengi(String durum) {
    if (durum == "Aktif") return Colors.green;
    if (durum == "Kontrol Gerekli") return Colors.orange;
    if (durum == "Kullanım Dışı") return Colors.red;
    return Colors.grey;
  }

  Future<void> excelIndir() async {
    try {
      final veri = await FirebaseFirestore.instance.collection('sapanlar').get();

      final excel = xls.Excel.createExcel();
      final sheet = excel['Sapanlar'];

      sheet.appendRow([
        xls.TextCellValue("Seri No"),
        xls.TextCellValue("Plaka"),
        xls.TextCellValue("Periyot"),
        xls.TextCellValue("Durum"),
        xls.TextCellValue("Tonaj"),
        xls.TextCellValue("Metre"),
        xls.TextCellValue("Son Kontrol"),
        xls.TextCellValue("Kontrol Eden"),
        xls.TextCellValue("Son Foto Linki"),
        xls.TextCellValue("Tüm Foto Linkleri"),
      ]);

      for (var d in veri.docs) {
        final data = d.data();
        final durum = kontrolDurumuHesapla(data);

        String sonFotoLinki = '';
        String tumFotoLinkleri = '';

        try {
          final kontroller = await FirebaseFirestore.instance
              .collection('sapanlar')
              .doc(d.id)
              .collection('kontroller')
              .orderBy('tarih', descending: true)
              .get();

          final fotoLinkleri = kontroller.docs
              .map((k) {
                final kData = k.data();
                return (kData['fotoUrl'] ?? '').toString();
              })
              .where((url) => url.trim().isNotEmpty)
              .toList();

          if (fotoLinkleri.isNotEmpty) {
            sonFotoLinki = fotoLinkleri.first;
            tumFotoLinkleri = fotoLinkleri.join('\n');
          }
        } catch (_) {
          // Foto linkleri alınamazsa Excel oluşturma işlemi devam etsin.
        }

        sheet.appendRow([
          xls.TextCellValue((data['seriNo'] ?? '').toString()),
          xls.TextCellValue((data['plaka'] ?? '').toString()),
          xls.TextCellValue((data['kontrolPeriyodu'] ?? '').toString()),
          xls.TextCellValue(durum),
          xls.TextCellValue((data['kapasite'] ?? '').toString()),
          xls.TextCellValue((data['uzunluk'] ?? '').toString()),
          xls.TextCellValue(
            data['sonKontrolTarihi'] != null
                ? (data['sonKontrolTarihi'] as Timestamp).toDate().toString()
                : '',
          ),
          xls.TextCellValue((data['sonKontrolEden'] ?? '').toString()),
          xls.TextCellValue(sonFotoLinki),
          xls.TextCellValue(tumFotoLinkleri),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sapanlar_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sapan Takip Excel Raporu',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Excel hazırlanamadı: $e")),
      );
    }
  }

  void yeniSapanDialogAc(BuildContext context) {
    final seriNo = TextEditingController();
    final plaka = TextEditingController();
    final kapasite = TextEditingController();
    final uzunluk = TextEditingController();
    String kontrolPeriyodu = "Günlük";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Yeni Sapan Ekle"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: seriNo,
                    decoration: const InputDecoration(labelText: "Seri No"),
                  ),
                  TextField(
                    controller: plaka,
                    decoration: const InputDecoration(labelText: "Plaka / Araç"),
                  ),
                  TextField(
                    controller: kapasite,
                    decoration: const InputDecoration(labelText: "Kapasite / Tonaj"),
                  ),
                  TextField(
                    controller: uzunluk,
                    decoration: const InputDecoration(labelText: "Uzunluk / Metre"),
                  ),
                  DropdownButtonFormField<String>(
                    value: kontrolPeriyodu,
                    decoration: const InputDecoration(labelText: "Kontrol Periyodu"),
                    items: ["Günlük", "Haftalık", "Aylık"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        kontrolPeriyodu = v!;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (seriNo.text.trim().isNotEmpty) {
                    await FirebaseFirestore.instance.collection('sapanlar').add({
                      'seriNo': seriNo.text.trim(),
                      'plaka': plaka.text.trim(),
                      'kapasite': kapasite.text.trim(),
                      'uzunluk': uzunluk.text.trim(),
                      'kontrolPeriyodu': kontrolPeriyodu,
                      'durum': 'Kontrol Gerekli',
                      'createdAt': FieldValue.serverTimestamp(),
                      'ekleyenKullanici': await aktifKullaniciAdi(),
                    });
                  }

                  Navigator.pop(context);
                },
                child: const Text("Ekle"),
              ),
            ],
          );
        },
      ),
    );
  }

  void cikisYap() {
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: aktifKullaniciAdi(),
      builder: (context, userSnap) {
        final userName = userSnap.data ?? "";

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    logoPath,
                    width: 42,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                const Text("Sapan Takip"),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: "QR Tara",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => QRScannerPage()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.block),
                tooltip: "Kullanım Dışı",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => KullanilmayanSapanlarPage()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: "Excel İndir",
                onPressed: excelIndir,
              ),
              IconButton(
                icon: const Icon(Icons.directions_car),
                tooltip: "Araç Bazlı",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AracBazliPage()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.bar_chart),
                tooltip: "Rapor",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RaporPage()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                tooltip: "Kullanıcı Yönetimi",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminKullanicilarPage()),
                  );
                },
              ),
              Center(child: Text(userName, style: const TextStyle(fontSize: 12))),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: cikisYap,
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: const Text(
                  "Ekipman Kontrol Paneli",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: anaRenk,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Seri no veya plaka ara",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) {
                    setState(() {
                      arama = v.toLowerCase();
                    });
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('sapanlar')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final hesaplananDurum = kontrolDurumuHesapla(data);

                      if (hesaplananDurum == "Kullanım Dışı") return false;

                      final seri = (data['seriNo'] ?? '').toString().toLowerCase();
                      final plaka = (data['plaka'] ?? '').toString().toLowerCase();

                      return seri.contains(arama) || plaka.contains(arama);
                    }).toList();

                    if (docs.isEmpty) {
                      return const Center(child: Text("Kayıt bulunamadı."));
                    }

                    return ListView(
                      children: docs.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final hesaplananDurum = kontrolDurumuHesapla(data);

                        if (hesaplananDurum != data['durum']) {
                          FirebaseFirestore.instance
                              .collection('sapanlar')
                              .doc(d.id)
                              .update({'durum': hesaplananDurum});
                        }

                        final plaka = (data['plaka'] ?? '').toString();
                        final plakaYazi = plaka.trim().isEmpty ? "Zimmet yok" : plaka;

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(
                              data['seriNo'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "$hesaplananDurum • Periyot: ${data['kontrolPeriyodu'] ?? 'Günlük'}\n"
                              "Plaka: $plakaYazi\n"
                              "Tonaj: ${data['kapasite'] ?? '-'} • Metre: ${data['uzunluk'] ?? '-'}",
                            ),
                            trailing: Icon(Icons.circle, color: durumRengi(hesaplananDurum), size: 18),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SapanDetay(id: d.id, data: data),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: anaRenk,
            onPressed: () => yeniSapanDialogAc(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class RaporPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rapor")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sapanlar').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          int aktif = 0;
          int gerekli = 0;
          int disi = 0;
          int toplam = snap.data!.docs.length;

          for (var d in snap.data!.docs) {
            final data = d.data() as Map<String, dynamic>;
            final durum = kontrolDurumuHesapla(data);

            if (durum == "Aktif") aktif++;
            if (durum == "Kontrol Gerekli") gerekli++;
            if (durum == "Kullanım Dışı") disi++;
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Toplam Sapan: $toplam", style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 12),
                Text("Aktif: $aktif", style: const TextStyle(fontSize: 18)),
                Text("Kontrol Gerekli: $gerekli", style: const TextStyle(fontSize: 18)),
                Text("Kullanım Dışı: $disi", style: const TextStyle(fontSize: 18)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class KullanilmayanSapanlarPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kullanım Dışı Sapanlar")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sapanlar')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return kontrolDurumuHesapla(data) == "Kullanım Dışı";
          }).toList();

          if (docs.isEmpty) return const Center(child: Text("Kullanım dışı sapan yok."));

          return ListView(
            children: docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final plaka = (data['plaka'] ?? '').toString().trim();
              final plakaYazi = plaka.isEmpty ? "Zimmet yok" : plaka;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(data['seriNo'] ?? ''),
                  subtitle: Text(
                    "Plaka: $plakaYazi\n"
                    "Tonaj: ${data['kapasite'] ?? '-'} • Metre: ${data['uzunluk'] ?? '-'}",
                  ),
                  trailing: const Icon(Icons.block, color: Colors.red),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SapanDetay(id: d.id, data: data)),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class AracBazliPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Araç Bazlı Sapanlar")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sapanlar').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final Map<String, List<QueryDocumentSnapshot>> araclar = {};

          for (var d in snap.data!.docs) {
            final data = d.data() as Map<String, dynamic>;
            final plakaRaw = (data['plaka'] ?? '').toString().trim();
            final plaka = plakaRaw.isEmpty ? "Zimmet Yok" : plakaRaw;
            araclar.putIfAbsent(plaka, () => []);
            araclar[plaka]!.add(d);
          }

          return ListView(
            children: araclar.entries.map((entry) {
              return ExpansionTile(
                title: Text("${entry.key} (${entry.value.length})"),
                children: entry.value.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final durum = kontrolDurumuHesapla(data);

                  return ListTile(
                    title: Text(data['seriNo'] ?? ''),
                    subtitle: Text(durum),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SapanDetay(id: doc.id, data: data)),
                      );
                    },
                  );
                }).toList(),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class SapanDetay extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;

  SapanDetay({required this.id, required this.data});

  @override
  _SapanDetayState createState() => _SapanDetayState();
}

class _SapanDetayState extends State<SapanDetay> {
  String sonuc = "Uygun";
  bool kesikVar = false;
  bool yipranmaVar = false;
  bool etiketOkunuyor = true;
  bool kaydediliyor = false;

  final aciklama = TextEditingController();
  Uint8List? secilenFotoBytes;
  String? secilenFotoAdi;
  final ImagePicker _picker = ImagePicker();

 Future<void> fotoSec() async {
  final secim = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Fotoğraf Çek"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("Galeriden Seç"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );

  if (secim == null) return;

  try {
    final XFile? foto = await _picker.pickImage(
      source: secim,
      imageQuality: 70,
      maxWidth: 1600,
    );

    if (foto == null) return;

    final bytes = await foto.readAsBytes();
    if (!mounted) return;

    setState(() {
      secilenFotoBytes = bytes;
      secilenFotoAdi = foto.name;
    });
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Fotoğraf seçilemedi: $e")),
    );
  }
}

  Future<void> bilgileriGuncelle(Map<String, dynamic> mevcutData) async {
    final plaka = TextEditingController(text: mevcutData['plaka'] ?? "");
    final kapasite = TextEditingController(text: mevcutData['kapasite'] ?? "");
    final uzunluk = TextEditingController(text: mevcutData['uzunluk'] ?? "");

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Sapan Bilgilerini Güncelle"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: plaka, decoration: const InputDecoration(labelText: "Plaka / Araç")),
                TextField(controller: kapasite, decoration: const InputDecoration(labelText: "Kapasite / Tonaj")),
                TextField(controller: uzunluk, decoration: const InputDecoration(labelText: "Uzunluk / Metre")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('sapanlar').doc(widget.id).update({
                  'plaka': plaka.text.trim(),
                  'kapasite': kapasite.text.trim(),
                  'uzunluk': uzunluk.text.trim(),
                  'bilgiGuncelleyen': await aktifKullaniciAdi(),
                  'bilgiGuncellemeTarihi': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
              },
              child: const Text("Kaydet"),
            ),
          ],
        );
      },
    );
  }

  Future<void> periyotGuncelle(String mevcutPeriyot) async {
    String secilenPeriyot = mevcutPeriyot;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Kontrol Periyodu Güncelle"),
              content: DropdownButtonFormField<String>(
                value: secilenPeriyot,
                decoration: const InputDecoration(
                  labelText: "Kontrol Periyodu",
                  border: OutlineInputBorder(),
                ),
                items: ["Günlük", "Haftalık", "Aylık"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  setDialogState(() {
                    secilenPeriyot = v!;
                  });
                },
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('sapanlar').doc(widget.id).update({
                      'kontrolPeriyodu': secilenPeriyot,
                      'periyotGuncelleyen': await aktifKullaniciAdi(),
                      'periyotGuncellemeTarihi': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Kaydet"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> sapanSil() async {
    final eminMi = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sapanı Sil"),
        content: const Text("Bu sapan ve kontrol kayıtları silinecek. Emin misin?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sil")),
        ],
      ),
    );

    if (eminMi != true) return;

    final ref = FirebaseFirestore.instance.collection('sapanlar').doc(widget.id);
    final kontroller = await ref.collection('kontroller').get();

    for (final doc in kontroller.docs) {
      await doc.reference.delete();
    }

    await ref.delete();

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sapan silindi")),
    );
  }

  Future<void> _fotoyuArkaPlandaYukle({
    required String sapanId,
    required String kontrolId,
    required Uint8List fotoBytes,
  }) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("kontrol_fotolari")
          .child("${sapanId}_${kontrolId}.jpg");

      final snapshot = await storageRef
          .putData(fotoBytes, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(const Duration(seconds: 90));

      final fotoUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('sapanlar')
          .doc(sapanId)
          .collection('kontroller')
          .doc(kontrolId)
          .update({
        'fotoUrl': fotoUrl,
        'fotoYukleniyor': false,
        'fotoHatasi': null,
        'fotoYuklemeTarihi': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await FirebaseFirestore.instance
          .collection('sapanlar')
          .doc(sapanId)
          .collection('kontroller')
          .doc(kontrolId)
          .update({
        'fotoYukleniyor': false,
        'fotoHatasi': e.toString(),
      });
    }
  }

  Future<void> kontrolKaydet(Map<String, dynamic> mevcutData) async {
    if (kaydediliyor) return;

    setState(() {
      kaydediliyor = true;
    });

    try {
      final durum = mevcutData['durum'];

      if (durum == "Kullanım Dışı") {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bu sapan kullanım dışı, tekrar kontrol yapılamaz")),
        );
        setState(() {
          kaydediliyor = false;
        });
        return;
      }

      final user = await aktifKullaniciAdi();
      final ref = FirebaseFirestore.instance.collection('sapanlar').doc(widget.id);
      final kontrolPeriyodu = mevcutData['kontrolPeriyodu'] ?? 'Günlük';
      final otomatikSonuc = (kesikVar || yipranmaVar || !etiketOkunuyor) ? "Uygun değil" : sonuc;
      final kontrolDoc = ref.collection('kontroller').doc();

      final Uint8List? fotoBytes = secilenFotoBytes;
      final bool fotoVar = fotoBytes != null;

      // En hızlı ve en güvenli akış:
      // 1) Kontrol kaydı hemen oluşturulur.
      // 2) Ana sayfaya hemen dönülür.
      // 3) Foto varsa aynı kayda arka planda yüklenir.
      await kontrolDoc.set({
        'kontrolTipi': kontrolPeriyodu,
        'sonuc': otomatikSonuc,
        'kesikVar': kesikVar,
        'yipranmaVar': yipranmaVar,
        'etiketOkunuyor': etiketOkunuyor,
        'aciklama': aciklama.text.trim(),
        'fotoUrl': null,
        'fotoYukleniyor': fotoVar,
        'fotoHatasi': null,
        'kontrolEden': user,
        'tarih': FieldValue.serverTimestamp(),
      });

      await ref.update({
        'durum': otomatikSonuc == "Uygun değil" ? "Kullanım Dışı" : "Aktif",
        'sonKontrolTarihi': FieldValue.serverTimestamp(),
        'sonKontrolTipi': kontrolPeriyodu,
        'sonKontrolEden': user,
      });

      if (fotoVar) {
  Future.microtask(() {
    _fotoyuArkaPlandaYukle(
      sapanId: widget.id,
      kontrolId: kontrolDoc.id,
      fotoBytes: fotoBytes,
    );
  });
}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fotoVar
                ? "Kontrol kaydedildi. Fotoğraf arka planda yükleniyor."
                : "Kontrol kaydedildi",
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        kaydediliyor = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kayıt hatası: $e")),
      );
    }
  }

  void fotoAc(String fotoUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.network(
            fotoUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text("Fotoğraf yüklenemedi."),
              );
            },
          ),
        ),
      ),
    );
  }

  Color sonucRengi(String sonuc) {
    return sonuc == "Uygun" ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('sapanlar').doc(widget.id);

    return Scaffold(
      appBar: AppBar(title: const Text("Sapan Detay")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final data = snap.data!.data() as Map<String, dynamic>;
          final hesaplananDurum = kontrolDurumuHesapla(data);

          if (hesaplananDurum != data['durum']) {
            FirebaseFirestore.instance.collection('sapanlar').doc(widget.id).update({'durum': hesaplananDurum});
          }

          final kullanimDisi = hesaplananDurum == "Kullanım Dışı";
          final plaka = (data['plaka'] ?? '').toString().trim();
          final plakaYazi = plaka.isEmpty ? "Zimmet yok" : plaka;
          final kontrolPeriyodu = data['kontrolPeriyodu'] ?? 'Günlük';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<bool>(
              future: aktifKullaniciAdminMi(),
              builder: (context, adminSnap) {
                final adminMi = adminSnap.data == true;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Seri No: ${data['seriNo'] ?? '-'}",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text("Plaka / Araç: $plakaYazi"),
                    Text("Kapasite / Tonaj: ${data['kapasite'] ?? '-'}"),
                    Text("Uzunluk / Metre: ${data['uzunluk'] ?? '-'}"),
                    Text("Kontrol Periyodu: $kontrolPeriyodu"),
                    Text("Durum: $hesaplananDurum"),
                    Text("Son Kontrol: ${data['sonKontrolTipi'] ?? '-'}"),
                    Text("Son Kontrol Eden: ${data['sonKontrolEden'] ?? '-'}"),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => bilgileriGuncelle(data),
                      child: const Text("Plaka / Tonaj / Metre Güncelle"),
                    ),
                    if (adminMi) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => periyotGuncelle(kontrolPeriyodu),
                        child: const Text("Admin: Kontrol Periyodu Güncelle"),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: sapanSil,
                        child: const Text("Admin: Sapanı Sil"),
                      ),
                    ],
                    const Divider(height: 32),
                    if (kullanimDisi)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.red.shade100,
                        child: const Text(
                          "Bu sapan kullanım dışı. Tekrar kontrol yapılamaz.",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    else ...[
                      const Text("Yeni Kontrol", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text("Kontrol Periyodu: $kontrolPeriyodu", style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: sonuc,
                        decoration: const InputDecoration(labelText: "Sonuç", border: OutlineInputBorder()),
                        items: ["Uygun", "Uygun değil"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => sonuc = v!),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text("Kesik var mı?"),
                        value: kesikVar,
                        onChanged: (v) => setState(() => kesikVar = v!),
                      ),
                      CheckboxListTile(
                        title: const Text("Yıpranma var mı?"),
                        value: yipranmaVar,
                        onChanged: (v) => setState(() => yipranmaVar = v!),
                      ),
                      CheckboxListTile(
                        title: const Text("Etiket okunuyor mu?"),
                        value: etiketOkunuyor,
                        onChanged: (v) => setState(() => etiketOkunuyor = v!),
                      ),
                      TextField(
                        controller: aciklama,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: "Açıklama", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: kaydediliyor ? null : fotoSec,
                        child: Text(secilenFotoAdi == null ? "Fotoğraf Çek / Ekle" : "Fotoğraf Seçildi: $secilenFotoAdi"),
                      ),
                      if (secilenFotoBytes != null) ...[
                        const SizedBox(height: 8),
                        Image.memory(secilenFotoBytes!, height: 160, fit: BoxFit.cover),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: kaydediliyor ? null : () => kontrolKaydet(data),
                          child: kaydediliyor
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Kontrol Kaydet"),
                        ),
                      ),
                    ],
                    const Divider(height: 32),
                    const Text("Kontrol Geçmişi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: ref.collection('kontroller').orderBy('tarih', descending: true).snapshots(),
                      builder: (context, ksnap) {
                        if (!ksnap.hasData) return const Center(child: CircularProgressIndicator());
                        final docs = ksnap.data!.docs;
                        if (docs.isEmpty) return const Text("Henüz kontrol yok.");

                        return Column(
                          children: docs.map((d) {
                            final k = d.data() as Map<String, dynamic>;
                            final fotoUrl = k['fotoUrl'];

                            return Card(
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(
                                      "${k['kontrolTipi'] ?? '-'} - ${k['sonuc'] ?? '-'}",
                                      style: TextStyle(
                                        color: sonucRengi(k['sonuc'] ?? ''),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "Tarih: ${tarihYaz(k['tarih'])}\n"
                                      "Kontrol Eden: ${k['kontrolEden'] ?? '-'}\n"
                                      "Kesik: ${k['kesikVar'] == true ? 'Var' : 'Yok'}\n"
                                      "Yıpranma: ${k['yipranmaVar'] == true ? 'Var' : 'Yok'}\n"
                                      "Etiket: ${k['etiketOkunuyor'] == true ? 'Okunuyor' : 'Okunmuyor'}\n"
                                      "Açıklama: ${k['aciklama'] ?? ''}",
                                    ),
                                  ),
                                  if (k['fotoYukleniyor'] == true)
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          "Fotoğraf arka planda yükleniyor...",
                                          style: TextStyle(fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                    ),
                                  if ((k['fotoHatasi'] ?? '').toString().isNotEmpty)
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          "Fotoğraf yüklenemedi.",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  if (fotoUrl != null && fotoUrl.toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: ElevatedButton.icon(
                                          onPressed: () => fotoAc(fotoUrl.toString()),
                                          icon: const Icon(Icons.photo),
                                          label: const Text("Fotoğrafı Aç"),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class QRScannerPage extends StatefulWidget {
  @override
  _QRScannerPageState createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool okundu = false;

  String seriNoCek(String qrData) {
    final uri = Uri.tryParse(qrData);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return qrData.trim();
  }

  Future<void> qrIsle(String qrData) async {
    if (okundu) return;
    okundu = true;

    final seriNo = seriNoCek(qrData);

    final sonuc = await FirebaseFirestore.instance
        .collection('sapanlar')
        .where('seriNo', isEqualTo: seriNo)
        .limit(1)
        .get();

    if (!mounted) return;
    Navigator.pop(context);

    if (sonuc.docs.isNotEmpty) {
      final doc = sonuc.docs.first;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SapanDetay(id: doc.id, data: doc.data())),
      );
    } else {
      final plaka = TextEditingController();
      final kapasite = TextEditingController();
      final uzunluk = TextEditingController();
      String kontrolPeriyodu = "Günlük";

      final ekle = await showDialog<bool>(
        context: context,
        builder: (_) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text("Sapan kayıtlı değil"),
                content: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text("Seri No: $seriNo"),
                      TextField(controller: plaka, decoration: const InputDecoration(labelText: "Plaka / Araç")),
                      TextField(controller: kapasite, decoration: const InputDecoration(labelText: "Kapasite / Tonaj")),
                      TextField(controller: uzunluk, decoration: const InputDecoration(labelText: "Uzunluk / Metre")),
                      DropdownButtonFormField<String>(
                        value: kontrolPeriyodu,
                        decoration: const InputDecoration(labelText: "Kontrol Periyodu"),
                        items: ["Günlük", "Haftalık", "Aylık"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            kontrolPeriyodu = v!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Ekle")),
                ],
              );
            },
          );
        },
      );

      if (ekle == true) {
        final yeni = await FirebaseFirestore.instance.collection('sapanlar').add({
          'seriNo': seriNo,
          'plaka': plaka.text.trim(),
          'kapasite': kapasite.text.trim(),
          'uzunluk': uzunluk.text.trim(),
          'kontrolPeriyodu': kontrolPeriyodu,
          'durum': 'Kontrol Gerekli',
          'createdAt': FieldValue.serverTimestamp(),
          'ekleyenKullanici': await aktifKullaniciAdi(),
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SapanDetay(
              id: yeni.id,
              data: {
                'seriNo': seriNo,
                'plaka': plaka.text.trim(),
                'kapasite': kapasite.text.trim(),
                'uzunluk': uzunluk.text.trim(),
                'kontrolPeriyodu': kontrolPeriyodu,
                'durum': 'Kontrol Gerekli',
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QR Tara")),
      body: MobileScanner(
        onDetect: (capture) {
          if (capture.barcodes.isEmpty) return;
          final barcode = capture.barcodes.first;
          if (barcode.rawValue != null) {
            qrIsle(barcode.rawValue!);
          }
        },
      ),
    );
  }
}

class AdminKullanicilarPage extends StatelessWidget {
  Future<bool> adminMi() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(user.uid)
        .get();

    return doc.data()?['admin'] == true;
  }

  Future<void> alanGuncelle(String uid, String alan, bool deger) async {
    await FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(uid)
        .update({alan: deger});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: adminMi(),
      builder: (context, adminSnap) {
        if (!adminSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (adminSnap.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text("Kullanıcı Yönetimi")),
            body: const Center(
              child: Text("Bu sayfaya erişim yetkiniz yok."),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Kullanıcı Yönetimi")),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('kullanicilar')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text("Kullanıcı yok."));
              }

              return ListView(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final email = (data['email'] ?? '-').toString();
                  final adSoyad = (data['adSoyad'] ?? '').toString();
                  final aktif = data['aktif'] == true;
                  final admin = data['admin'] == true;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(adSoyad.isEmpty ? email : adSoyad),
                      subtitle: Text(email),
                      trailing: SizedBox(
                        width: 170,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Aktif"),
                                Switch(
                                  value: aktif,
                                  onChanged: (v) => alanGuncelle(d.id, 'aktif', v),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Admin"),
                                Switch(
                                  value: admin,
                                  onChanged: (v) => alanGuncelle(d.id, 'admin', v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      },
    );
  }
}

