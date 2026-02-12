import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Saldo-stream (Pysyy AppBarissa)
  Stream<DocumentSnapshot> getSaldoStream() {
    return _db.collection('pankki').doc('yhteinen_saldo').snapshots();
  }

  // 2. Tapahtumat-stream (Yhteenveto-sivulle)
  Stream<QuerySnapshot> getTapahtumatStream() {
    return _db.collection('tapahtumat')
        .orderBy('aika', descending: true)
        .snapshots();
  }

  // 3. Lisää tunteja
  Future<void> lisaaTunnit(String nimi, double tunnit) async {
    double summa = tunnit * 10;
    DocumentReference saldoRef = _db.collection('pankki').doc('yhteinen_saldo');
    
    // Luodaan uusi dokumenttiviite tapahtumalle valmiiksi
    DocumentReference uusiTapahtumaRef = _db.collection('tapahtumat').doc();

    return _db.runTransaction((transaction) async {
      DocumentSnapshot snap = await transaction.get(saldoRef);
      double uusiSaldo = (snap.exists ? (snap.data() as Map<String, dynamic>)['euroa'] : 0.0) + summa;
      
      // Päivitetään saldo
      transaction.set(saldoRef, {'euroa': uusiSaldo});
      
      // Lisätään tapahtuma käyttämällä set-metodia add-metodin sijaan
      transaction.set(uusiTapahtumaRef, {
        'tekija': nimi,
        'maara': tunnit,
        'yksikko': 'h',
        'summa': summa,
        'tyyppi': 'lisays',
        'aika': FieldValue.serverTimestamp(),
      });
    });
  }

  // 4. Nosta rahaa
  Future<void> nostaRahaa(String nimi, double euroa) async {
    DocumentReference saldoRef = _db.collection('pankki').doc('yhteinen_saldo');
    DocumentReference uusiTapahtumaRef = _db.collection('tapahtumat').doc();
    
    return _db.runTransaction((transaction) async {
      DocumentSnapshot snap = await transaction.get(saldoRef);
      double uusiSaldo = (snap.exists ? (snap.data() as Map<String, dynamic>)['euroa'] : 0.0) - euroa;
      
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