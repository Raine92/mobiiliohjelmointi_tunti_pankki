import 'package:cloud_firestore/cloud_firestore.dart';

/// Luokka vastaa sovelluksen ja Cloud Firestore -tietokannan välisestä viestinnästä.
/// Täällä määritellään kaikki luku- ja kirjoitusoperaatiot.
class FirestoreService {
  // Alustetaan Firestore-instanssi helposti käytettäväksi muuttujaksi.
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- REAALIAIKAISET VIRRAT (STREAMS) ---

  /// 1. Saldo-stream: Palauttaa jatkuvan virran 'yhteinen_saldo' -dokumentista.
  /// Snapshots() tarkoittaa, että Flutter-sovellus päivittyy automaattisesti 
  /// heti, kun saldon arvo muuttuu tietokannassa (Push-notifikaatioiden kaltainen toiminta).
  Stream<DocumentSnapshot> getSaldoStream() {
    return _db.collection('pankki').doc('yhteinen_saldo').snapshots();
  }

  /// 2. Tapahtumat-stream: Hakee kaikki kirjaukset 'tapahtumat' -kokoelmasta.
  /// .orderBy('aika', descending: true) varmistaa, että uusimmat tapahtumat 
  /// näkyvät listan yläpalkissa.
  Stream<QuerySnapshot> getTapahtumatStream() {
    return _db.collection('tapahtumat')
        .orderBy('aika', descending: true)
        .snapshots();
  }

  // --- KIRJOITUSOPERAATIOT (TRANSACTIONS) ---

  /// 3. Lisää tunteja: Laskee summan ja päivittää saldon sekä lokitapahtuman.
  /// Käytämme transaktiota (runTransaction), jotta saldo päivittyy luotettavasti.
  Future<void> lisaaTunnit(String nimi, double tunnit) async {
    // Laskukaava euroille: $summa = tunnit \times 10$
    double summa = tunnit * 10;
    
    // Viittaukset dokumentteihin (osoitteet tietokannassa)
    DocumentReference saldoRef = _db.collection('pankki').doc('yhteinen_saldo');
    
    // Luodaan uusi uniikki ID tapahtumalle valmiiksi (doc() ilman nimeä generoi ID:n)
    DocumentReference uusiTapahtumaRef = _db.collection('tapahtumat').doc();

    // Transaktio lukee nykyisen saldon, laskee uuden ja kirjoittaa kaiken kerralla.
    // Jos joku muu muuttaa saldoa kesken operaation, tämä yrittää automaattisesti uudelleen.
    return _db.runTransaction((transaction) async {
      DocumentSnapshot snap = await transaction.get(saldoRef);
      
      // Tarkistetaan onko dokumentti olemassa. Jos ei, lähdetään nollasta.
      double nykyinenSaldo = snap.exists ? (snap.data() as Map<String, dynamic>)['euroa'] : 0.0;
      double uusiSaldo = nykyinenSaldo + summa;
      
      // Päivitetään yhteinen potti
      transaction.set(saldoRef, {'euroa': uusiSaldo});
      
      // Luodaan historiatieto tapahtumasta
      transaction.set(uusiTapahtumaRef, {
        'tekija': nimi,
        'maara': tunnit,
        'yksikko': 'h',
        'summa': summa,
        'tyyppi': 'lisays',
        // FieldValue.serverTimestamp() on tärkeä: se käyttää palvelimen kelloa, 
        // jolloin eri aikavyöhykkeet tai käyttäjän puhelimen väärä kellonaika eivät sotke historiaa.
        'aika': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 4. Nosta rahaa: Vähentää euroja yhteisestä potista.
  /// Toimii samalla transaktioperiaatteella kuin tuntien lisäys.
  Future<void> nostaRahaa(String nimi, double euroa) async {
    DocumentReference saldoRef = _db.collection('pankki').doc('yhteinen_saldo');
    DocumentReference uusiTapahtumaRef = _db.collection('tapahtumat').doc();
    
    return _db.runTransaction((transaction) async {
      DocumentSnapshot snap = await transaction.get(saldoRef);
      
      double nykyinenSaldo = snap.exists ? (snap.data() as Map<String, dynamic>)['euroa'] : 0.0;
      double uusiSaldo = nykyinenSaldo - euroa;
      
      transaction.set(saldoRef, {'euroa': uusiSaldo});
      
      transaction.set(uusiTapahtumaRef, {
        'tekija': nimi,
        'maara': euroa,
        'yksikko': '€',
        'summa': euroa,
        'tyyppi': 'nosto',
        'aika': FieldValue.serverTimestamp(),
      });
    });
  }
}