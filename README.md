# TuntiPankki Pro

TuntiPankki Pro on Flutterilla toteutettu mobiilisovellus, joka on suunniteltu työtuntien seurantaan ja yhteisen "tuntipankin" hallinnointiin. Sovelluksessa käyttäjät voivat kirjata tekemiään tunteja, seurata yhteistä saldoa euroina ja tehdä nostoja pankista.

Sovellus on kehitetty osana Mobiiliohjelmointi-kurssia ja se täyttää kaikki asetetut tekniset vaatimukset.

##  Ominaisuudet

- **Reaaliaikainen tietokanta:** Sovellus synkronoi saldon ja tapahtumahistorian kaikkien käyttäjien välillä välittömästi.
- **Tuntien kirjaus:** Käyttäjä voi valita tekijän (Aki/Janne) ja tuntimäärän 0,5 tunnin tarkkuudella.
- **Rahan nosto:** Mahdollisuus nostaa rahaa yhteisestä potista, jolloin saldo päivittyy automaattisesti.
- **Tapahtumahistoria:** Selkeä listaus kaikista tehdyistä kirjauksista ja nostoista suomalaisella aikaleimalla.
- **Järjestelmätason notifikaatiot:** Sovellus lähettää paikallisen ilmoituksen aina, kun tapahtuma tallennetaan onnistuneesti.

##  Tekniikka

Sovellus hyödyntää nykyaikaisia mobiilikehityksen työkaluja:

- **Flutter & Dart:** Sovelluksen käyttöliittymä ja logiikka.
- **Firebase Firestore:** NoSQL-pilvitietokanta datan tallennukseen ja reaaliaikaiseen synkronointiin.
- **Flutter Local Notifications:** Järjestelmätason integraatio ilmoituksia varten (Android-tuki).
- **Intl-paketti:** Käytetty päivämäärien ja valuuttojen lokalisointiin suomalaiseen muotoon.
- **Timezone-paketti:** Varmistaa notifikaatioiden oikeaoppisen ajoituksen ja toimivuuden.

##  Tekninen toteutus

### Reaaliaikaisuus (Streams)
Sovellus ei vaadi sivun päivitystä, vaan se hyödyntää `StreamBuilder`-widgettejä. Kun tietokannassa tapahtuu muutos, sovellus saa siitä tiedon "push"-tyylisesti ja päivittää saldon välittömästi käyttöliittymään.

### Tiedon eheys (Transactions)
Tuntien lisäykset ja nostot on suojattu Firestore-transaktioilla (`runTransaction`). Tämä varmistaa, että saldo päivittyy oikein, vaikka kaksi käyttäjää tekisi kirjauksen täsmälleen samaan aikaan. Transaktio takaa atomisuuden: joko koko päivitys onnistuu tai se hylätään, jolloin rahaa ei katoa "bittiavaruuteen".

### Virhekäsittely ja vakaus
Sovelluksessa on huomioitu asynkroniset katkokset (`async gaps`). Kaikki käyttöliittymäpäivitykset asynkronisten operaatioiden jälkeen on suojattu `mounted`-tarkistuksilla, mikä estää sovelluksen kaatumisen, jos käyttäjä poistuu näkymästä kesken tallennuksen.

### Navigointi
Sovellus käyttää `IndexedStack`-rakennetta, joka säilyttää jokaisen välilehden tilan (esim. tekstikenttään kirjoitetun summan), vaikka käyttäjä vaihtaisi välilehteä.

##  Asennus ja vaatimukset

1. Varmista, että käytössäsi on Flutter SDK.
2. Aja komento `flutter pub get` ladataksesi tarvittavat paketit.
3. Sovellus vaatii Android-laitteen (API 33+ suositeltu notifikaatioiden testaamiseen).
4. `AndroidManifest.xml` on määritetty tarvittavat luvat: `INTERNET`, `VIBRATE` ja `POST_NOTIFICATIONS`.

---
*Kehitetty harjoitustyönä Mobiiliohjelmointi-kurssilla.*
