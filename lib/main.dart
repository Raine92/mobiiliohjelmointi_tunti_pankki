import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart'; 
import 'package:timezone/data/latest_all.dart' as tz;
import 'firebase_options.dart';
import 'firestore_service.dart';

// Globaali muuttuja notifikaatioille
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Alustetaan Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Alustetaan aikavyöhykkeet (notifikaatiokirjaston vaatimus)
  tz.initializeTimeZones();

  // 3. Android-kohtaiset notifikaatioasetukset
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid
  );

  // Alustetaan plugin käyttäen nimettyä parametria 'settings'
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  runApp(const TuntiPankkiApp());
}

// Apufunktio ilmoituksen lähettämiseen (Vain Android)
void naytaIlmoitus(String otsikko, String viesti) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'tunti_kanava', 
    'Tuntikirjaukset',
    importance: Importance.max, 
    priority: Priority.high,
  );
  
  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    id: 0, 
    title: otsikko, 
    body: viesti, 
    notificationDetails: details,
  );
}

class TuntiPankkiApp extends StatelessWidget {
  const TuntiPankkiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TuntipankkiHome(),
    );
  }
}

class TuntipankkiHome extends StatefulWidget {
  const TuntipankkiHome({super.key});
  @override
  State<TuntipankkiHome> createState() => _TuntipankkiHomeState();
}

class _TuntipankkiHomeState extends State<TuntipankkiHome> {
  int _currentIndex = 0;
  final FirestoreService _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TuntiPankki Pro'),
        backgroundColor: Colors.blue.shade50,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _service.getSaldoStream(),
            builder: (context, snapshot) {
              double s = (snapshot.hasData && snapshot.data!.exists) ? (snapshot.data!['euroa'] as num).toDouble() : 0.0;
              return Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Center(
                  child: Text(
                    "${s.toStringAsFixed(2)} €", 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          LisaaTuntejaSivu(service: _service),
          NostaRahaaSivu(service: _service),
          YhteenvetoSivu(service: _service),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Tunnit'),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Nostot'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Yhteenveto'),
        ],
      ),
    );
  }
}

// --- SIVU 1: LISÄÄ TUNTEJA ---
class LisaaTuntejaSivu extends StatefulWidget {
  final FirestoreService service;
  const LisaaTuntejaSivu({super.key, required this.service});

  @override
  State<LisaaTuntejaSivu> createState() => _LisaaTuntejaSivuState();
}

class _LisaaTuntejaSivuState extends State<LisaaTuntejaSivu> {
  String _kayttaja = 'Aki';
  double _tunnit = 1.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text("KIRJAA TUNTEJA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Aki', label: Text('Aki')), 
              ButtonSegment(value: 'Janne', label: Text('Janne'))
            ],
            selected: {_kayttaja},
            onSelectionChanged: (val) => setState(() => _kayttaja = val.first),
          ),
          const Spacer(),
          const Text("Kuinka monta tuntia?"),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pyoreaNappi(Icons.remove, () => setState(() => _tunnit > 0.5 ? _tunnit -= 0.5 : null)),
              SizedBox(width: 120, child: Center(child: Text("$_tunnit h", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)))),
              _pyoreaNappi(Icons.add, () => setState(() => _tunnit += 0.5)),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () async {
              await widget.service.lisaaTunnit(_kayttaja, _tunnit);
              
              // KORJAUS 1: Tarkistetaan contextin tila asynkronisen gapin jälkeen
              if (!context.mounted) return;
              
              naytaIlmoitus("Tunnit kirjattu!", "$_kayttaja lisäsi $_tunnit tuntia.");
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tunnit tallennettu!")));
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60), 
              backgroundColor: Colors.blue, 
              foregroundColor: Colors.white
            ),
            child: const Text("TALLENNA"),
          ),
        ],
      ),
    );
  }

  Widget _pyoreaNappi(IconData icon, VoidCallback onPressed) {
    return IconButton.filled(onPressed: onPressed, icon: Icon(icon, size: 30));
  }
}

// --- SIVU 2: NOSTA RAHAA ---
class NostaRahaaSivu extends StatefulWidget {
  final FirestoreService service;
  const NostaRahaaSivu({super.key, required this.service});

  @override
  State<NostaRahaaSivu> createState() => _NostaRahaaSivuState();
}

class _NostaRahaaSivuState extends State<NostaRahaaSivu> {
  final _controller = TextEditingController();
  String _kayttaja = 'Aki';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text("NOSTA RAHAA PANKISTA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'Aki', label: Text('Aki')), ButtonSegment(value: 'Janne', label: Text('Janne'))],
            selected: {_kayttaja},
            onSelectionChanged: (val) => setState(() => _kayttaja = val.first),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Summa (€)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.euro)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              double? summa = double.tryParse(_controller.text);
              if (summa != null) {
                await widget.service.nostaRahaa(_kayttaja, summa);
                
                // KORJAUS 2: Tarkistetaan contextin tila asynkronisen gapin jälkeen
                if (!context.mounted) return;
                
                naytaIlmoitus("Nosto suoritettu!", "$_kayttaja nosti $summa €.");
                _controller.clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nosto suoritettu!")));
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(60), 
              backgroundColor: Colors.red.shade400, 
              foregroundColor: Colors.white
            ),
            child: const Text("NOSTA RAHAT"),
          ),
        ],
      ),
    );
  }
}

// --- SIVU 3: YHTEENVETO (Tapahtumalista) ---
class YhteenvetoSivu extends StatelessWidget {
  final FirestoreService service;
  const YhteenvetoSivu({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: service.getTapahtumatStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Ei tapahtumia vielä."));

        return ListView.separated(
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            bool onLisays = doc['tyyppi'] == 'lisays';
            
            String pvmText = "...";
            if (doc['aika'] != null) {
              DateTime pvm = (doc['aika'] as Timestamp).toDate();
              String muotoiltuAika = DateFormat("d.M.yyyy 'klo' HH.mm").format(pvm);
              pvmText = muotoiltuAika;
            }
            
            return ListTile(
              leading: Icon(onLisays ? Icons.add_circle : Icons.remove_circle, color: onLisays ? Colors.green : Colors.red),
              title: Text("${doc['tekija']} (${doc['maara']} ${doc['yksikko']})"),
              subtitle: Text(pvmText),
              trailing: Text(
                "${onLisays ? '+' : '-'}${doc['summa'].toStringAsFixed(2)} €", 
                style: TextStyle(fontWeight: FontWeight.bold, color: onLisays ? Colors.green : Colors.red)
              ),
            );
          },
        );
      },
    );
  }
}