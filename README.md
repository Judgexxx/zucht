# Vogelzucht-App (Android, Flutter)

Mobile Oberfläche für das Ilch-Modul **Vogelzucht** (Version 1.2.0 oder neuer). Die App zeigt und ändert genau
die Daten, die du als Benutzer auch auf der Webseite siehst. Es gibt keine eigene Datenbank in der App:
Jede Änderung geht über die Schnittstelle des Moduls in die MySQL-Datenbank der Seite, und Änderungen aus dem
Browser erscheinen nach dem Aktualisieren (Wischen nach unten oder Sync-Knopf) in der App.

## Was die App kann
- Anmelden mit dem Benutzerkonto der Webseite (Adresse, Benutzername, Passwort). Gespeichert wird nur ein Zugriffs-Token, nie das Passwort.
- Alle Bereiche des Moduls: Vögel, Zuchtpaare, Bruten (mit Eiern), Ringe, Käfige, Gesundheit, Gewichte, Ausstellungen,
  Verkauf/Zukauf, Adressen, Kasse, Termine, Notizen, eigene Arten/Mutationen/Felder. Fotos aus Galerie oder Kamera für Vögel und die Bildergalerie (werden verkleinert, ohne Empfang später hochgeladen).
- Die Formulare entstehen aus den Felddefinitionen des Servers. Neue Felder und Auswahllisten des Moduls erscheinen deshalb ohne App-Update.
- Es gelten dieselben Prüfregeln wie auf der Webseite (doppelte Ringnummer, Elternvögel, Art/Mutation usw.). Fehler erscheinen am Feld.
- Basislisten des Seitenbetreibers (Arten, Mutationen) sind sichtbar, aber schreibgeschützt.
- **Offline-Puffer:** Ohne Empfang werden Änderungen lokal gespeichert und automatisch übertragen, sobald wieder Verbindung besteht
  (beim Start, beim Sync-Knopf und wenn das Netz zurückkommt). Vom Server abgelehnte Änderungen stehen unter „Synchronisieren“ und können wiederholt oder verworfen werden.

## Grenzen (Version 1.0)
- Stammbaum, Vererbungsrechner, Statistik, Kalender und Kaufvertrag gibt es nur auf der Webseite.
- „Jungvogel aus Ei anlegen“ ist in der App nicht vorhanden; lege den Jungvogel als neuen Vogel an (Eltern auswählen).
- Beim gleichzeitigen Bearbeiten desselben Datensatzes in App und Browser gewinnt die zuletzt gespeicherte Änderung.

## Bauen (einmalig auf deinem PC)
Voraussetzung: [Flutter-SDK](https://docs.flutter.dev/get-started/install) mit Android-Toolchain (`flutter doctor` muss grün sein).

```bash
cd vogelzucht_app
flutter create --platforms=android --org de.vogelzucht --project-name vogelzucht_app .
flutter pub get
```

Danach **einmal** die Internet-Berechtigung eintragen, sonst kann die fertige App nicht ins Netz:
in `android/app/src/main/AndroidManifest.xml` direkt über der Zeile `<application` einfügen:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Testen und installieren:

```bash
flutter analyze        # sollte ohne Fehler durchlaufen
flutter test
flutter run            # Handy per USB, Entwickleroptionen/USB-Debugging an
flutter build apk --release   # Ergebnis: build/app/outputs/flutter-apk/app-release.apk
```

Die APK kannst du auf dem Handy installieren (Installation aus unbekannten Quellen erlauben).
Für den Play Store brauchst du zusätzlich eine Signierung (siehe Flutter-Dokumentation „Build and release an Android app“).

## Einrichtung am Server
1. Modul Vogelzucht in Version 1.2.0 hochladen und im Admin-Center unter Module **aktualisieren** (legt zwei neue Tabellen an).
2. In der App als Adresse die Webseite eintragen, z. B. `https://deine-seite.de`. Die App spricht `…/index.php/vogelzucht/api/…` an.
3. **HTTPS ist Pflicht** (Android blockiert unverschlüsselte Verbindungen, und Passwort/Token wären sonst mitlesbar).
4. Wer die App nutzen darf, steuert dieselbe Gruppen-Einstellung wie auf der Webseite (Admin-Center → Vogelzucht → Zugriff).

## Dateien
- `lib/services/api_service.dart` – HTTP-Zugriff, Token im Header, Fehlerbehandlung bei Verbindungsabbruch
- `lib/models/vogel_model.dart` – Vogel mit `fromJson()` / `toJson()`
- `lib/models/schema_model.dart` – Felddefinitionen vom Server
- `lib/state/app_state.dart` – Anmeldung, lokaler Cache, Warteschlange, Synchronisation (Provider)
- `lib/screens/…` – Anmeldung, Übersicht, Listen, Formular, Synchronisation

## APK ohne eigene Entwicklerumgebung (GitHub)
1. Kostenloses Konto auf github.com, dort ein **privates** Repository anlegen (z. B. `vogelzucht-app`).
2. Den Inhalt dieses Ordners (inklusive `.github/workflows/build-apk.yml`) in das Repository hochladen („Add file → Upload files“).
3. Im Repository auf **Actions → APK bauen → Run workflow** klicken. Nach wenigen Minuten steht unter dem Lauf bei „Artifacts“ die Datei `vogelzucht-apk`.
4. Das ZIP entpacken, `app-release.apk` aufs Handy kopieren und installieren.

Schlägt `flutter analyze` oder der Bau fehl, schick mir bitte die rote Fehlermeldung aus dem Lauf, dann korrigiere ich den Code.

## Optik
Die App folgt der Vorlage „AviarySoft“: dunkler Modus (Slate/Smaragd), links eine Seitenleiste (ab ca. 900 px Breite dauerhaft, auf dem Handy als Menü), oben eine Statusleiste mit Sync-Anzeige, Uhrzeit und Profil. Die Startseite „Zucht-Zentrale“ zeigt Kennzahlen (Bestand, Zuchtpaare, Eier/Küken, Volieren), Schnellaktionen („Vogel erfassen“, „Gelege eintragen“), Filter/Suche und Volieren-Karten mit Belegung und Brutstatus (Gelege aktiv, Schlupf bald, Quarantäne, Ruhephase). Alle Werte werden aus den synchronisierten Daten berechnet (`lib/state/dashboard.dart`). Farben und Titel stehen zentral in `lib/brand.dart`. Die Schrift „Inter“ lädt die App beim ersten Start aus dem Internet (danach zwischengespeichert), ohne Netz nimmt sie die Systemschrift.
