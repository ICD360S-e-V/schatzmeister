# ICD360S e.V - Schatzmeister Portal (Cross-Platform: Windows, macOS, Linux, Android)

**Current Version:** 1.0.15+16 (from pubspec.yaml)

**Supported Platforms:**
- ✅ **Windows** - Primary platform
- ✅ **macOS** - Active development
- ✅ **Android** - APK via F-Droid repo (https://icd360sev.icd360s.de/fdroid/repo)
- ⚠️ **Linux** - Desktop features supported (not extensively tested)
- ⚠️ **iOS** - Mobile support via cross-platform packages (not primary focus)

**Android Package:** `de.icd360sev.schatzmeister`

**Development Environment:**
- **macOS**: `/Users/ionut-claudiuduinea/Documents/icd360sev_schatzmeister`
- **Server**: `ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de` (⚠️ vezi **[Acces server](#acces-server)** — `root` + cheia veche NU mai merg)
- **Database**: MySQL — `icd360sev_user@localhost/icd360sev_db`. Parola stă în `/var/www/icd360sev.icd360s.de/api/config.php` pe server.
  ⚠️ Până pe 2026-08-23 parola era scrisă aici în clar, iar acest fișier e **urmărit într-un repo public**. Scoaterea ei de acum nu o retrage din istoric — e în continuare compromisă. În proiectul `vorsitzer` același `CLAUDE.md` e gitignored; aici nu, ceea ce ar trebui aliniat.
- **F-Droid Repo**: `https://icd360sev.icd360s.de/fdroid/repo`

---

## API dedicat Schatzmeister (2026-08-23)

Namespace propriu sub `/api/schatzmeister/`. **Nu depinde de `/api/admin/`** —
nici endpoint-uri, nici `requireAdminRole()` (acela verifică `vorsitzer` și
excludea tocmai rolul pentru care e făcută aplicația).

Sursa versionată local: [_server_schatzmeister/](_server_schatzmeister/).

### Regula de confidențialitate

Schatzmeister lucrează **pseudonimizat**. Din datele MEMBRILOR nu ies din API
nici numele, nici adresa, nici data nașterii — identificarea se face exclusiv
prin Mitgliedernummer. Lista completă de câmpuri blocate e `SM_PII_FIELDS` în
`lib/sm_auth.php`; `smRedact()` o aplică pe fiecare rând, ca plasă de siguranță
peste un eventual `SELECT *` viitor.

Datele **asociației** (nume, adresă, Steuernummer, Finanzamt) nu intră sub
regula asta — sunt necesare pentru declarația fiscală și pentru
Zuwendungsbescheinigungen, deci se livrează integral.

| Ce vede | Ce NU vede |
|---|---|
| Mitgliedernummer, rol, status | Nume, prenume |
| Sume, date, status plată | Stradă, PLZ, oraș |
| Categorie, referință, descriere | Data și locul nașterii |
| Datele asociației (complete) | Nume donator / contraparte bancară |

### Endpoint-uri

| Metodă | Cale | Rol |
|---|---|---|
| POST | `auth/activate_code.php` | public (bootstrap) |
| POST | `auth/generate_activation_code.php` | **vorsitzer** — el emite codul |
| POST | `auth/recover_device_key.php` | public + device key |
| GET/POST/DELETE | `finanzen/beitragszahlungen.php` | schatzmeister |
| GET/POST/PUT/DELETE | `finanzen/spenden.php` | schatzmeister |
| GET/POST/DELETE | `finanzen/transaktionen.php` | schatzmeister |
| GET | `finanzen/einstellungen.php` | schatzmeister (**doar citire**, POST → 405) |
| GET | `termine/my_termine.php` | schatzmeister |
| POST | `tickets/list.php` | schatzmeister |

Tabele noi: `schatzmeister_activation_codes`, `schatzmeister_code_attempts`
(separate de cele ale vorsitzer-ului, ca un brute-force pe un portal să nu
blocheze celălalt). Schema: `_server_schatzmeister/schema.sql`.

### Fluxul de activare

Ca la vorsitzer, dar cu namespace propriu:

1. Vorsitzer apelează `auth/generate_activation_code.php` cu `target_user_id` →
   primește codul în clar **o singură dată** (în DB stă doar hash-ul).
2. Schatzmeister introduce Nummer + cod în
   [login_with_code_screen.dart](lib/screens/login_with_code_screen.dart)
   (4 câmpuri × 4 caractere, acceptă și lipire directă).
3. `auth/activate_code.php` validează, consumă codul atomic, emite
   `device_key` + JWT.
4. La pornirile următoare: auto-login din stocarea locală; dacă aceasta a fost
   ștearsă (reinstalare), `auth/recover_device_key.php` regăsește device-ul
   după amprenta hardware — fără cod nou.

Alfabetul codului e `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (fără 0/O și 1/I/l),
80 de biți entropie. Rate limit: 5 eșecuri / 15 minute per IP sau Nummer.
Un singur cod valid odată — emiterea unuia nou îl revocă pe precedentul.

⚠️ În JWT nu se pune nume sau e-mail: `generateAccessToken()` primește
Mitgliedernummer pe ambele poziții, ca payload-ul să nu conțină date personale
în clar (JWT-ul e doar semnat, nu criptat).

### Termine și Tickete (adăugate 2026-08-23)

Înainte foloseau endpoint-urile comune `/api/termine/my_termine.php` și
`/api/tickets/list.php`. Ambele livrau nume:

| Câmp comun | Înlocuit cu |
|---|---|
| `created_by_name` (Termine) | `created_by_mitgliedernummer` |
| `participant_vorname` / `_nachname` / `_name` | `participant_mitgliedernummer` |
| `admin_name` (Tickete) | `admin_mitgliedernummer` |

Două schimbări de fond față de originale:

- `SELECT t.*` a fost înlocuit cu listă explicită de coloane. Altfel orice
  coloană adăugată în viitor tabelei `termine` ar ajunge automat în răspuns,
  inclusiv una personală.
- La tickete, Mitgliedernummer **nu mai vine din corpul cererii**, ci din token.
  În endpoint-ul comun corpul decide ale cui tickete se livrează — aici nimeni
  nu-și mai poate cere ticketele altcuiva punând altă numerotare în body.

Modelul `Ticket.fromJson` citește `admin_mitgliedernummer ?? admin_name`, deci
funcționează și cu răspunsuri de la endpoint-ul comun.

### Live chat — funcții adăugate (2026-08-23)

**Reacții la mesaje.** Serverul le suporta deja (`/api/chat/react.php`, din
2026-07-19), doar clientul lipsea. Portat din vorsitzer:
[message_emotion.dart](lib/utils/message_emotion.dart) (12 reacții, identic
caracter cu caracter cu versiunea din vorsitzer — fișierul e gândit să fie
copiat, nu divergent), `ApiService.reactToMessage()`, plus interfața în
[live_chat_dialog.dart](lib/widgets/live_chat_dialog.dart) și în
[chat_message_bubble.dart](lib/widgets/chat_message_bubble.dart).

⚠️ Cine adaugă o reacție nouă trebuie s-o adauge în **trei** locuri, altfel
dispare tăcut: fișierul din celălalt repo, whitelist-ul `$allowed` din
`api/chat/react.php` (altfel HTTP 400), și un release al **ambelor** aplicații.

Salvarea e optimistă: bula arată reacția imediat și o retrage dacă serverul o
refuză. Fără asta, un eșec ar arăta ca un succes.

**Video-Anruf.** Adăugat pe serviciul existent, fără pachetele de sunet din
vorsitzer (`flutter_ringtone_player`, `just_audio`) — ar fi însemnat dependențe
native noi și DLL-uri în plus în installerul Windows.

Ce s-a adăugat în [voice_call_service.dart](lib/services/voice_call_service.dart):
`startCall(..., video: true)`, `offerSendsVideo(sdp)`, constrângeri 1080p cu
`ideal`, și getterii `isVideoCall` / `localStream` / `remoteStream`.

⚠️ `sdp.contains('m=video')` ar fi fost prea larg: și un apel pur vocal poate
purta o linie video `recvonly`. Camera proprie se aprinde doar dacă linia
`m=video` nu e respinsă (port ≠ 0) **și** direcția permite trimiterea.

În [incoming_call_dialog.dart](lib/widgets/incoming_call_dialog.dart), aceeași
`RTCVideoView` care era `Offstage` (necesară pentru redarea sunetului pe
Windows) devine vizibilă la un apel video. ⚠️ La apel vocal trebuie să rămână
în arbore și de 1×1 dp — cu suprafață zero, `flutter_webrtc` nu mai redă sunetul
pe Windows. `Stack` a devenit `Column`, altfel banda verde de comenzi acoperea
exact zona în care se vede fața interlocutorului.

Permisiunile de cameră existau deja pe Android, iOS și macOS — neschimbate.

### Unterschrift — semnarea documentelor (2026-08-23)

Vorsitzer trimite un document, Schatzmeister îl semnează în aplicație.

**Pe server nu a fost nimic de construit** — ambele capete sunt agnostice de rol:

| Endpoint | Ce verifică |
|---|---|
| `vorstand/signatur_manage.php` → `anfordern` | doar că destinatarul **există**: `SELECT 1 FROM users WHERE id = ?`. Fără verificare de rol. |
| `admin/users.php` | listează toate rolurile → Schatzmeister apare deja în selecția Vorsitzer-ului |
| `member/signatur_manage.php` | identitatea din token (`requireAuth()`), fără rol. Fiecare query poartă `user_id = ?`. |

Confirmat și în date: din semnăturile deja depuse, **10 poartă rolul `vorsitzer`**
și 2 `mitgliedergrunder` — fluxul e folosit de mult de mai mult decât `mitglied`.

⚠️ Nu confunda cu `vorstand/signatur_manage.php` pentru *citire*: acela e
`vorsitzer`-only și administrează semnăturile **altora**. Partea de semnat e
`member/`, iar acolo Schatzmeister e un utilizator ca oricare altul.

**Client:** [eigene_unterschriften_screen.dart](lib/screens/eigene_unterschriften_screen.dart),
preluat din vorsitzer `origin/main`. Plus `ApiService.eigeneSignatur()` și
`eigeneSignaturPdf()` → `member/signatur_manage.php` și `member/signatur_pdf.php`.

Fluxul: listă → deschide PDF-ul → cere TAN (SMS la numărul din Verificare
etapa 1) → desenează semnătura → trimite SVG + TAN. Sau respinge cu motiv.
Schatzmeister-ul S42759 **are număr de mobil înregistrat**, deci TAN-ul ajunge.

**O diferență intenționată față de vorsitzer:** acolo intrarea din bară e fără
contor, cu argumentul explicit din cod că Vorsitzer-ul a cerut el însuși
semnătura și știe că e în așteptare. Pentru Schatzmeister e invers — el o
primește — deci aici intrarea numără, la fel ca insigna de chat. Numărătoarea
se face la încărcarea dashboard-ului, fără un ciclu propriu de interogare.

Culorile `F.h(...)` din original au fost înlocuite cu nuanțele Material
directe: acelea comută pe mod întunecat, pe care aplicația asta nu-l are, iar
aducerea lui `app_farben.dart` ar fi însemnat un sistem întreg de culori pentru
două apeluri.

⚠️ **Checkout-urile locale sunt în urma producției.** `vorsitzer` local e pe
ramura `refactor/inwx-konto-tab` la 6.96.1, iar `origin/main` e la **v6.141.0** —
`eigene_unterschriften_screen.dart` nici nu există în copia locală. `mitglieder`
local e cu **44 de commituri** în urmă (local 1.81.4, remote v1.86.1). Pentru
orice comparație cu aceste două aplicații, folosește `git show origin/main:...`,
nu fișierele din working tree.

### Cod inaccesibil — curățat 2026-08-23

O analiză de accesibilitate tranzitivă din `main.dart` arăta **40 din 97 de
fișiere (41%) inaccesibile**. Pentru comparație, mitglieder are 13 din 158
(8%) — deci nu era o normă a proiectului, ci o problemă locală.

Acum: **19 din 89 (21%)**, iar fiecare fișier rămas are un motiv scris mai jos.
Scriptul de verificare e în [tools/erreichbarkeit.py](tools/erreichbarkeit.py) —
rulează-l după orice restructurare de meniu.

#### Meniul din stânga — zis pe scurt

**Actualizat 2026-08-24.** Cele patru module legate pe 23.08 (Archiv,
Routineaufgaben, Statistik, Dienste) plus Vereinverwaltung au fost **scoase
din nou**. Decizia utilizatorului: aparțin aplicației de președinte, nu
trezorierului.

Meniul are acum exact patru intrări:

| # | Intrare |
|---|---|
| 0 | Dashboard |
| 1 | Finanzverwaltung |
| 2 | Meine Tickets |
| 3 | Meine Termine |

Plus butonul de semnături din bara de sus, care nu e în meniul lateral.

Fișierele au rămas în repo, doar nu mai sunt legate — de aceea numărul de
fișiere parcate a sărit de la 19 la 44 (49%). Saltul e intenționat și e
notat în `tools/erreichbarkeit.py`. Ștergerea lor rămâne deschisă până se
decide dacă sunt necesare în aplicația de președinte.

`test/menue_und_leiste_test.dart` verifică **și absența** celor cinci:
fișierele fiind încă în repo, o relegare din greșeală n-ar sări altfel în ochi.

#### `LegalFooter` legat în `bottomNavigationBar`

Stătea pe `null`. Consecințele erau două, ambele tăcute:

1. **Impressum și Datenschutz nu apăreau nicăieri.** Cheile de traducere
   existau (`imprint`, `privacy`), widget-ul care le afișează era orfan. În
   Germania asta e obligație legală, nu confort.
2. **`UpdateService.checkForUpdate()` nu era apelat nici măcar o dată** în tot
   programul viu. Singurul apelant era `LegalFooter`. Aplicația nu avea deci
   nicio verificare automată de actualizări — ceea ce explică de ce nimeni nu
   observase că `version_schatzmeister.json` arată spre un APK inexistent.

Aceeași plasare ca în mitglieder (`mitglied_dashboard.dart:931`).

#### Șterse (înlocuite de ceva viu)

`login_screen`, `login_tab`, `forgot_password_dialog`, `register_tab` —
fluxul cu parolă, înlocuit de activarea prin cod. `register_tab` chema
`auth/register.php`, dezactivat pe server încă dinainte.

`personal_data_dialog` (`getProfile`/`updateProfile` — submulțime a lui
`profile_dialog`, care e viu și face în plus schimbare de e-mail și parolă,
sesiuni, verificare), `dashboard_stats`, `confirm_dialogs`, `user_data_table` —
zero utilizatori, fără echivalent lipsă.

⚠️ La ștergerea lui `login_screen` s-a pierdut o funcție: **consimțământul
pentru diagnostic** rula doar de acolo (`checkAndShowDiagnosticConsent` +
`DiagnosticService().setScreen`), exact cum spune comentariul din `main.dart`.
Regresia fusese introdusă mai devreme, la mutarea pornirii pe ecranul de
activare. Mutat acum în `initState` din
[login_with_code_screen.dart](lib/screens/login_with_code_screen.dart).

#### Rămase parcate, cu motiv

| Fișier(e) | De ce nu se leagă |
|---|---|
| `terminverwaltung_screen`, `termin_dialogs` | folosesc `admin/termine_*` → `requireAdminRole` = `vorsitzer`. Ar da 403. Gestiunea programărilor nu e atribuția trezorierului; el are „Meine Termine" (5). |
| `ticketverwaltung_screen`, `ticket_dialogs`, `ticket_details_dialog`, `user_details_dialog`, `mitglieder_device` | `tickets/admin_list.php` e `vorsitzer`-only. Idem: „Meine Tickets" acoperă rolul. |
| `netzwerk_screen` | director de autorități, spitale, farmacii — sprijin pentru membri, nu finanțe. |
| `notar_screen`, `notar_cards`, `notar_dialogs` | notariat: domeniul președintelui. Are și componentă financiară (Rechnungen, Zahlungen) — de discutat dacă se separă. |
| `arbeitsagentur_screen` | agenția de muncă — sprijin pentru membri. |
| `admin_chat_dialog`, `chat_message_bubble`, `chat_header`, `chat_input_area`, `chat_attachment_item`, `conversation_list_item` | generația veche de chat. `live_chat_dialog` (viu) are propriile bule inline. **Aceleași fișiere sunt moarte și în mitglieder** — moștenire comună, nu o particularitate a acestei aplicații. |
| `news_service` | feed Tagesschau RSS, 311 linii, fără niciun apelant. Păstrat fiindcă e funcțional și s-ar lega ușor de dashboard — dar acum e o decizie, nu o scăpare. |

⚠️ Reacțiile la mesaje pe care le-am adăugat în `chat_message_bubble` sunt
**inerte**: fișierul e parcat. Funcția merge prin `live_chat_dialog`, unde a
fost adăugată separat.

### Modificări în aplicație

- `main.dart` pornește pe `LoginWithCodeScreen` (înainte: `LoginScreen` cu parolă)
- `ApiService`: metodele financiare arată spre `schatzmeister/finanzen/*`
- `ApiService.updateVereineinstellungen()` nu mai face request — returnează
  direct `read_only: true`, fiindcă serverul răspunde 405
- `DeviceKeyService`: adăugate `loadStoredDeviceKey()`, `loadStoredDeviceId()`,
  `getOrGenerateDeviceId()`, `setActivatedCredentials()`, `collectDeviceInfo()`.
  ⚠️ Fluxul de activare **nu** folosește `initialize()`: acela validează la
  server și șterge cheia la orice eșec, deci ar pierde o activare validă la
  o simplă pană de rețea.

### Backup-uri pe server

Cele 8 fișiere `notizen_*` / `routine_*` foloseau `requireAdminRole()` și
dădeau 403 chiar pentru schatzmeister. Corectate; originalele sunt la
`<fisier>.bak_sm_role_20260823` în `/var/www/.../api/schatzmeister/`.

## Semnarea Android (2026-08-24)

Cheia de semnare a fost **regenerată** — cea cu care s-a construit v1.0.17 în
martie 2026 nu mai există nicăieri: nici local, nici pe server, nici ca secret
GitHub. Keystore-ul F-Droid de pe server conține doar aliasul `repo`, care
semnează indexul, nu aplicații.

Cheia nouă și parola stau în `~/Documents/schatzmeister-signing/`, **în afara
repo-ului** — acesta e public. Vezi `README.md` de acolo.

    Alias      schatzmeister
    Tip        PKCS12, RSA 4096, SHA384withRSA
    Valabilă   până 2054-01-08
    SHA-256    BC:55:52:C8:A0:A6:CB:F9:EE:AC:95:95:A7:FA:B1:6B:
               0B:A0:FC:6E:96:EA:3E:8A:5E:8D:58:B7:86:2F:30:25

⚠️ **PKCS12 nu acceptă parole diferite pentru store și cheie.** Prima încercare
le-a avut diferite; `keytool` avertizează, iar Gradle cade apoi cu
`Get Key failed: Given final block not properly padded`. `storePassword` și
`keyPassword` trebuie să fie identice.

### ⚠️ Un dispozitiv trebuie reinstalat

În `device_keys` există exact o instalare Android activă:

    Redmi 21091116UG · Android 13 · app 1.0.17 · creat 2026-03-15

Android refuză actualizarea când semnătura se schimbă. Telefonul trebuie să
**dezinstaleze și să reinstaleze** aplicația. Cu asta se pierde `device_key`-ul
local, deci are nevoie după aceea de un cod de activare nou de la președinte
(`/api/schatzmeister/auth/generate_activation_code.php`).

Instalarea `linux / Testgeraet` din aceeași tabelă e de la o verificare din
2026-08-23 și e deja revocată.

### Secrete în GitHub

Setate pe 2026-08-23 pentru `ICD360S-e-V/schatzmeister`: `KEYSTORE_BASE64`,
`KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`.

Verificat: APK-ul construit de CI poartă amprenta de mai sus, identică cu cea
a cheii locale — deci semnătura e de release, nu de debug.

---

## Acces server

**ACTUALIZAT 2026-08-23** — serverul a fost migrat si intarit pe 2026-07-25. Tot ce era
documentat inainte (`root@`, cheia `vps_icd360sev_icd360s.de`) **nu mai functioneaza**:
`ssh` cu ele raspunde `Permission denied (publickey)`. Verificat live pe 2026-08-23.

### Ce s-a schimbat

| | Vechi (documentat) | Nou (activ) |
|---|---|---|
| Host | `icd360sev.icd360s.de` → OVH 57.129.101.240 | `icd360sev.icd360s.de` → **135.125.189.10** |
| Utilizator | `root` | **`icd360sev`** (uid 5001, grup `wheel`) |
| Port | 36000 | 36000 (neschimbat; **22 e inchis**) |
| Cheie | `vps_icd360sev_icd360s.de` (in repo) | `new_icd360sev.icd360s.de` (**in afara repo-ului**) |
| Parola | — | `PasswordAuthentication no` |
| Root login | permis | `PermitRootLogin no` |

Config-ul de hardening: `/etc/ssh/sshd_config.d/00-hardening.conf`
(`AllowUsers icd360sev`, `MaxAuthTries 3`, `LoginGraceTime 30`).
Host key nou: `SHA256:9JBu7ndiQe9QnqrC6oBDytGy497nRE2ANPu+gCTHKOQ` (ed25519) — la prima
conectare de pe o masina veche e nevoie de `ssh-keygen -R icd360sev.icd360s.de`.

### Cheia SSH

Cheia activa este `new_icd360sev.icd360s.de` (ed25519,
`SHA256:l5M8NYUqsrnzl1759ebURkJK/cXWBYUA9pMTggCKEjk`), instalata in
`/home/icd360sev/.ssh/authorized_keys`. Aceeasi cheie e folosita si de proiectele
`vorsitzer` si `mitglieder`.

⚠️ **Cheia NU se mai tine in folderul proiectului.** Repo-ul asta e **public** pe GitHub,
iar cheia veche a fost commituita in el (`vps_icd360sev_icd360s.de`) — de aceea a si fost
revocata. Tine cheia in `~/.ssh/` si refera-o printr-o variabila:

```bash
export SEV_KEY="$HOME/.ssh/new_icd360sev.icd360s.de"   # chmod 600
```

Pe masina de dezvoltare curenta cheia se afla la
`/home/anonymous_a/Documents/vorsitzer/new_icd360sev.icd360s.de` (acolo e gitignored).

### Comanda de baza

```bash
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de "COMANDA"
```

Contul `icd360sev` **nu poate** citi/scrie direct in `/var/www`, `/etc` sau `/var/log`.
Pentru orice atinge zonele astea, prefixeaza cu **`sudo -n`** (NOPASSWD e configurat in
`/etc/sudoers.d/90-icd360sev`, deci nu cere parola):

```bash
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n cat /var/www/icd360sev.icd360s.de/api/data/version_schatzmeister.json"
```

⚠️ Glob-urile pe cai root (`/root/*`, `/var/www/.../*.apk`) **nu se expandeaza** —
foloseste `sudo -n sh -c "..."` cand ai nevoie de wildcard.

### Wrapper recomandat

```bash
cat > /tmp/ssh_sev.sh << 'EOF'
#!/bin/bash
ssh -i "$HOME/.ssh/new_icd360sev.icd360s.de" \
    -o ConnectTimeout=10 -o LogLevel=ERROR \
    -p 36000 icd360sev@icd360sev.icd360s.de "$@"
EOF
chmod +x /tmp/ssh_sev.sh

/tmp/ssh_sev.sh "sudo -n mysql -N icd360sev_db -e 'SHOW TABLES;' | head"
```

### Upload de fisiere (scp)

`icd360sev` nu poate scrie in `/var/www` — se incarca in `/tmp`, apoi se muta cu `sudo`:

```bash
scp -i "$SEV_KEY" -P 36000 FISIER_LOCAL icd360sev@icd360sev.icd360s.de:/tmp/
/tmp/ssh_sev.sh "sudo -n mv /tmp/FISIER /var/www/icd360sev.icd360s.de/CALE/ && \
                 sudo -n chown nginx:nginx /var/www/icd360sev.icd360s.de/CALE/FISIER"
```

### Banner

Serverul afiseaza un banner "AUTHORIZED ACCESS ONLY" inaintea fiecarei comenzi.
Filtreaza-l cand parsezi output:

```bash
| grep -v -E "AUTHORIZED|prohibited|property|monitor|consent|Violators|activities|^\*"
```

### Dupa orice modificare de PHP

OPcache pastreaza versiunea veche pana la reload:

```bash
/tmp/ssh_sev.sh "sudo -n systemctl reload php85-php-fpm"
```

⚠️ Serviciul se numeste **`php85-php-fpm`** (PHP 8.5.9 din Remi), nu `php-fpm`.
CLI-ul e `/usr/local/bin/php` → `/opt/remi/php85/root/usr/bin/php`.

### Servicii relevante pentru Schatzmeister

| Serviciu | Unde | Comanda |
|---|---|---|
| nginx | vhost `/etc/nginx/conf.d/icd360sev.icd360s.de.conf`, root `/var/www/icd360sev.icd360s.de` | `sudo -n systemctl reload nginx` |
| PHP-FPM | socket `/var/opt/remi/php85/run/php-fpm/www.sock` | `sudo -n systemctl reload php85-php-fpm` |
| MariaDB 10.11 | DB `icd360sev_db`, user `icd360sev_user`@localhost | `sudo -n mysql icd360sev_db` |
| WebSocket | supervisord, `/etc/supervisord.d/websocket-chat.ini`, port 8080 | `sudo -n supervisorctl restart icd360s-websocket` |
| ntfy | port 2586, proxat la `/ntfy/` | `curl https://icd360sev.icd360s.de/ntfy/v1/health` |

⚠️ `supervisorctl` **cere `sudo -n`** — fara el da `PermissionError` pe socket.

### Stare de adaptat (verificat 2026-08-23)

- ✅ **API**: 144 din 145 endpoint-uri apelate de aplicatie exista pe server.
  Singurul lipsa e `/api/auth/register.php` — a fost dezactivat intentionat pe server
  (redenumit `register.php.backup`); inregistrarea se face acum prin
  `/api/schatzmeister/admin_register.php`. In aplicatie, `ApiService.register()` e apelat
  doar din `lib/widgets/register_tab.dart`, care **nu e instantiat nicaieri** (cod mort),
  deci nu se rupe nimic la runtime.
- ⚠️ **F-Droid**: CLI-ul `fdroid` **nu e instalat** pe serverul nou, deci `fdroid update`
  din procedura de release esueaza. Structura `/fdroid/` (config.yml, keystore.jks,
  metadata, repo) a fost migrata, dar **nu exista niciun `.apk` in `/fdroid/repo/`**.
- ⚠️ **Update-ul aplicatiei e rupt**: `version_schatzmeister.json` anunta 1.0.17+18 cu
  `download_url` → `.../fdroid/repo/de.icd360sev.schatzmeister_18.apk`, fisier care **nu
  exista**. Si `/downloads/schatzmeister/` e gol (doar un subfolder `windows/` gol).
  Pana se reincarca APK-ul, orice client care accepta update-ul primeste 404.
- ⚠️ `/fdroid/` a fost restrictionat la `repo/` + `archive/` in nginx (hardening
  2026-07-25c), fiindca `keystore.jks` si `config.yml` erau accesibile public.

---

## REGULA DE AUR - BACKUP OBLIGATORIU

**ÎNAINTE de a modifica ORICE fișier, TREBUIE să faci backup la fișierul original!**

```bash
# Backup individual file (macOS)
cp lib/screens/fisier_original.dart lib/screens/fisier_original.dart.bak

# Restore dacă ceva merge prost
cp lib/screens/fisier_original.dart.bak lib/screens/fisier_original.dart
```

**Reguli:**
1. Fă `.bak` la FIECARE fișier ÎNAINTE de prima modificare
2. Backup-ul se face în același folder cu extensia `.bak`
3. DOAR fișierele care se modifică, nu tot proiectul
4. După ce totul funcționează corect, backup-urile `.bak` pot fi șterse manual

---

## Format Benutzernummer

| Rol | Prefix | Format |
|-----|--------|--------|
| Vorsitzer | V | V00001 |
| Schatzmeister | S | S00001 |
| Kassierer | K | K00001 |
| Mitgliedergrunder | MG | MG00001 |

## Funcționalități

### Start Screen (Tabs)

#### Tab 1: Anmelden (Login)
- Login cu Benutzernummer și parolă
- **Anmeldedaten speichern** - salvează credențialele criptat (Windows Credential Manager)
- **Automatisch anmelden** - auto-login la pornirea aplicației
- **Mit Windows starten** - pornire automată la login Windows
- **Passwort vergessen?** - recuperare parolă cu Benutzernummer + Wiederherstellungscode
- **Single Instance** - aplicația poate rula doar o singură dată

#### Tab 2: Registrieren
- Formular: Name, Email, Passwort, Wiederherstellungscode (6 cifre)
- După succes: Benutzernummer generată random (10000-99999)
- Limitare: max 1 cont per IP per zi

### Dashboard
Accesibil pentru: vorsitzer, schatzmeister, kassierer, mitgliedergrunder

**Sidebar Navigation:**
- Benutzerverwaltung (User management)
- Ticketverwaltung (Ticket system)
- Terminverwaltung (Appointments)
- Finanzverwaltung (Financial management)
- Vereinverwaltung (Organization admin)
- Notar (Notary services)
- Behörden (Government authorities)
- Handelsregister (Trade register)
- Vereinsregister (Association register)
- Deutsche Post (Postal services & tracking)
- Sendungsverfolgung (Package tracking)
- Finanzamt (Tax office)
- Arbeitsagentur (Employment agency)
- GLS Bank / VR Bank (Banking)
- Archiv (Document archive)
- Statistik (Statistics)
- Ordnungsmaßnahmen (Disciplinary measures)
- Routinenaufgaben (Routine tasks)
- Reiseplanung (Travel planning)
- DB Mobilitätsunterstützung (Deutsche Bahn mobility)
- Netzwerk (Network/Partnerships)
- Dienste (Services)
- Google Nonprofit / Microsoft Nonprofit / Stifter-helfen
- JPG2PDF / PDF Manager (Document tools)
- Postcard (Postcard creation)

**User Management:**
- Lista toți utilizatorii cu culori per rol
- Statistici: Total Benutzer, Aktiv, Gesperrt
- Activează/Suspendă/Șterge conturi
- **Click pe utilizator** → Dialog cu:
  - Tab 1: Edit Name, Email, Parolă, Rol
  - Tab 2: Device/Session management cu force logout per device
- **Protecție cont propriu** - nu poți modifica propriul cont

### Terminverwaltung (NEW - v1.0.57+)
**Weekly Calendar System:**
- 📅 Grid 7 coloane: Montag → Sonntag
- 🔢 KW number + date range navigation (< >)
- 🕐 Time slots: 11:00, 🍽️ Mittagspause (12:00-14:00), 14:00-17:00
- 🎨 Color coding: Vorstandssitzung (purple), Mitgliederversammlung (blue), Schulung (green), Sonstiges (amber)
- 🏖️ **Urlaub** în roșu - blochează programări
- ✏️ Click pe termin → Edit dialog (change all fields)
- 🗑️ Delete termine
- 👥 Multi-select participanți cu checkboxes
- 🔗 Optional link la ticket

**Urlaub Management:**
- ➕ Buton "Urlaub" roșu → Create vacation period
- 🏖️ Display în calendar (zilele roșii cu beach icon)
- ✏️ Click pe urlaub → Smart edit:
  - Single day → Delete
  - First day → Remove first OR delete all
  - Last day → Remove last OR delete all
  - Middle day → Delete all only

**Time Restrictions:**
- Termine doar: 11:00-12:00 și 14:00-18:00
- Validare automată la create/edit

### Behördenverwaltung (Government Authorities)
**Features:**
- Contact information for various government authorities
- Forms and document templates
- Application tracking (Anträge)
- Appointment scheduling with authorities
- Document upload/download

### Handelsregister (Trade Register)
**Client-Side Scraping (handelsregister.de):**
- Company search by name or registration number
- Extract company data (name, address, directors, capital)
- View company documents (annual reports, registration certificates)
- HTML parsing with `html` package (client-side, no backend proxy)
- Caching of search results

**Implementation:**
- `lib/services/handelsregister_client_service.dart` - HTTP client + HTML parsing
- `lib/screens/handelsregister_screen.dart` - Search UI + results display

### Vereinsregister (Association Register)
**Features:**
- Search associations by name or registration number
- View association details (name, address, board members, purpose)
- Track association registration status
- Document management (statutes, membership lists)

### Stadtverwaltung (City Administration)
**Note:** `stadtverwaltung_screen.dart` a fost eliminat (doar backup .bak există). Datele sunt servite prin API endpoints `/api/stadtverwaltung/` (behoerden, drogerien, krankenhaeuser, krankenkassen, maerkte, praxen).
**Features:**
- Municipal services overview via API
- Contact information for city departments
- Healthcare facilities (hospitals, practices, pharmacies)
- Markets and drugstores

### Deutsche Post (Postal Services)
**DHL Tracking & Services:**
- Package tracking (Sendungsverfolgung) via DHL API
- Shipping label creation
- Postage calculator
- Pickup scheduling
- Address validation

**Implementation:**
- `lib/screens/deutschepost_screen.dart` - Tracking UI + shipping services
- Integration with DHL API for real-time tracking

### Device Management (v1.0.56+)
**Max 3 Devices:**
- Login verifică sesiuni active
- >3 devices → Dialog cu lista pentru selecție
- Auto-logout device selectat + retry login
- Prevent duplicate sessions per device

**User Self-Service:**
- Tab "Meine Geräte" în profil
- Vezi device name, platform, IP
- Self-service logout per device

### Ticket Notification System (v1.0.58+)
**Cross-Platform Notifications pentru Tickete:**
- Polling la fiecare **10 secunde** pentru notificări noi
- Notificări când:
  - Membri creează tickete noi
  - Membri răspund la tickete existente
  - Adminii răspund (notifică membrii)
- Dual system: WebSocket (real-time) + HTTP Polling (fallback)
- Notificări marcate automat ca trimise după afișare

**Implementare:**
- `lib/services/ticket_notification_service.dart` - Polling service (10s)
- `lib/screens/dashboard_screen.dart` - Start/stop în initState/dispose
- `/api/tickets/poll_notifications.php` - Backend endpoint

**Database:**
- `ticket_notifications` table cu `is_sent` flag
- Notificări create automat la ticket create/comment
- Polling marchează `is_sent = 1` după afișare

### Ticket Camera & Crop Feature (v1.0.24+) - macOS Support
**macOS Camera Capture + Image Cropping pentru Ticket Attachments:**
- **Camera nativă macOS**: `camera_macos` package (AVFoundation)
- **Image cropping**: `crop_your_image` package (pure Dart, cross-platform)
- **3-step flow**: Camera → Crop/Edit → Preview → Upload

**Implementare:**
- `lib/widgets/ticket_details_dialog.dart` - `_MacOSCameraDialog` widget (lines ~1233-1531)
- **Camera capture** → PNG conversion via `dart:ui` codec for crop compatibility
- **Crop UI** → Interactive crop with corner dots, rotation, zoom
- **Preview** → Final preview before upload with retake/back options

**Technical Details:**
- `camera_macos` outputs JPEG by default (set `pictureFormat: PictureFormat.jpg`)
- Convert camera bytes to PNG using `ui.instantiateImageCodec()` before crop
- `crop_your_image` uses `image` Dart package for decoding (not Flutter native codec)
- All photos saved as `.png` on server for consistency

**API Endpoint:**
- `/api/tickets/attachments/upload.php` - Supports image/png, image/jpeg, image/tiff, image/bmp

**Permissions:**
- macOS: `com.apple.security.device.camera` in `macos/Runner/DebugProfile.entitlements`
- macOS: `com.apple.security.device.camera` in `macos/Runner/Release.entitlements`

### Live Chat & Voice Call

**WebSocket Server:** `wss://icd360sev.icd360s.de/wss/`

| Feature | Descriere |
|---------|-----------|
| Live Chat | Mesaje real-time, typing indicator, istoric |
| Voice Call | WebRTC cu STUN servers, mute/unmute, call timer |
| Auto-reject | După 30 secunde fără răspuns |
| **Auto-Reconnect** | **Exponential backoff: 2s, 4s, 8s, 16s, 32s, 60s (max 10 încercări)** |

**Auto-Reconnect System (v1.0.58+):**
- Reconnectare automată când conexiunea cade (network issues, server restart)
- **Exponential backoff**: 2s → 4s → 8s → 16s → 32s → 60s (max)
- Max 10 încercări de reconnectare
- Reset automat la reconnectare cu succes
- Oprire automată la disconnect manual
- Store credentials pentru reconnectare automată

### Native Notifications (Cross-Platform)
**Notification Types:**
- Mesaj nou în chat
- Apel incoming (voice call)
- Update disponibil
- Status conexiune
- Ticket nou creat
- Ticket comment nou

**Implementation:**
- `lib/services/notification_service.dart` - Uses `flutter_local_notifications` (cross-platform)
- **Windows**: Toast notifications via Windows Notification API
- **macOS**: Native macOS notification center
- **Linux**: D-Bus notifications (FreeDesktop specification)
- **Mobile**: Push notifications (Android/iOS native)

### Auto-Update System (v1.0.20+)

**Verificare automată:** La fiecare 5 minute (Timer în LegalFooter)

**Flux update silențios:**
1. User apasă "Jetzt aktualisieren" în UpdateDialog
2. App descarcă installer în `%TEMP%` cu progress bar
3. App afișează "Installation wird gestartet..."
4. App lansează installer cu flags: `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART`
5. App se închide (`exit(0)`)
6. Installer rulează silențios (fără UI)
7. Installer pornește automat aplicația actualizată (flag `postinstall` fără `skipifsilent`)

**Inno Setup flags pentru silent install:**
```
/VERYSILENT      - Fără interfață grafică
/SUPPRESSMSGBOXES - Fără dialog boxes
/NORESTART       - Nu restarta Windows
```

**Fișiere implicate:**
- `lib/services/update_service.dart` - `launchInstaller(path, silent: true)`
- `lib/widgets/update_dialog.dart` - UI pentru download + progress
- `installer/icd360sev_setup.iss` - `[Run]` section cu `postinstall` flag

### Auto-Recovery Launcher (v1.0.37+)

**Problemă rezolvată:** Dacă o actualizare are un DLL lipsă sau altă eroare fatală, aplicația nu poate porni și utilizatorul rămâne blocat.

**Soluție:** Un launcher VBS care monitorizează pornirea aplicației și oferă rollback automat.

**Flux Auto-Recovery:**
1. Shortcut-urile (Desktop + Start Menu) pornesc `Launcher.vbs`, nu EXE-ul direct
2. Launcher-ul pornește `ICD360S_eV.exe` și monitorizează procesul
3. Dacă aplicația se închide în mai puțin de 5 secunde (crash):
   - Afișează dialog: "Die Anwendung konnte nicht gestartet werden. Möchten Sie zur vorherigen Version zurückkehren?"
   - Dacă utilizatorul apasă **Ja**: restaurează automat din `backup\` și repornește
   - Dacă nu există backup: afișează link pentru download manual
4. Dacă aplicația rulează > 5 secunde: launcher-ul se închide silențios

**Backup automat la instalare:**
- Înainte de fiecare update, installer-ul salvează versiunea curentă în `{app}\backup\`
- Se salvează: EXE + toate DLL-urile
- Se creează `Restore_Previous_Version.bat` pentru restaurare manuală

**Fișiere create de installer:**
```
C:\Program Files\ICD360S e.V\
├── ICD360S_eV.exe           # Aplicația principală
├── Launcher.vbs             # Launcher cu auto-recovery
├── *.dll                    # DLL-uri Flutter
└── backup\
    ├── ICD360S_eV.exe       # Backup versiune anterioară
    ├── *.dll                # Backup DLL-uri
    ├── Restore_Previous_Version.bat  # Script restaurare manuală
    └── info.txt             # Info despre backup
```

**Start Menu entries:**
- `ICD360S e.V` → pornește prin Launcher.vbs
- `Vorherige Version wiederherstellen` → rulează Restore_Previous_Version.bat

### Diagnostic Service
- Trimite starea aplicației la fiecare 15 secunde
- Endpoint: `/api/diagnostic/log.php`

### Heartbeat Service (v1.0.1+)
**Real-time Online Status Updates:**
- Trimite heartbeat la fiecare 15 secunde pentru actualizare `last_seen`
- Endpoint: `/api/auth/heartbeat.php`
- Permite membrilor să vadă când schatzmeister-ul este online în timp real
- Automatic start/stop când utilizatorul se loghează/deloghează
- Rulează în background fără să întrerupă aplicația

**Implementare:**
- `lib/services/heartbeat_service.dart` - HeartbeatService cu Timer periodic
- `lib/services/api_service.dart` - `sendHeartbeat()` method
- `lib/screens/dashboard_screen.dart` - Start în `initState()`, stop în `dispose()`

**Rezolvă problema:**
- Membrii vedeau "Zuletzt aktiv vor 35 Minuten" când schatzmeister-ul era de fapt online
- Acum status-ul se actualizează automat la fiecare 15 secunde

### Log Upload System (v1.0.21+)
**Automatic Real-time Log Upload pentru Debugging:**
- Upload automat la fiecare **30 secunde** către server
- Upload **IMEDIAT** pentru toate error-urile
- Re-queue automat dacă upload eșuează
- Buffer max 500 logs în memorie
- **AVANTAJ MAJOR:** Testare locală pe PC fără nevoie de VM sau device remote!

**Implementare:**
- `lib/services/logger_service.dart` - `startUpload()`, `stopUpload()`, `_uploadLogsToServer()`
- `lib/screens/dashboard_screen.dart` - Start în `initState()`, stop în `dispose()`
- **Endpoint:** `/api/logs/schatzmeister_logs.php` (Schatzmeister)
- **Logs salvate:** `/logs/schatzmeister/logs_YYYY-MM-DD.json`

**Payload JSON:**
```json
{
  "mitgliedernummer": "S00001",
  "device_id": "WIN_ABC123...",
  "machine_name": "DESKTOP-XYZ",
  "platform": "windows \"Windows 10 Pro\" 10.0",
  "logs": [
    {
      "timestamp": "2026-02-03T10:30:00.000Z",
      "message": "✓✓✓ Remote stream attached - AUDIO PLAYBACK ENABLED!",
      "level": "info",
      "tag": "CALL-UI"
    }
  ]
}
```

**Monitoring Real-time:**
```bash
# Vezi logs CALL în timp real
tail -f /var/www/icd360sev.icd360s.de/logs/schatzmeister/logs_$(date +%Y-%m-%d).json | \
  jq -r '.logs[] | select(.tag == "CALL" or .tag == "CALL-UI") | "\(.timestamp) [\(.tag)] \(.message)"'
```

**Beneficii pentru Testing:**
- ✅ **NU mai ai nevoie de VM/device remote** - testezi local pe PC-ul tău!
- ✅ Logs apar AUTOMAT pe server la 30s
- ✅ Debugging în timp real fără acces la device
- ✅ Persistență logs pentru analiza ulterioară
- ✅ Tracking probleme pe device-uri remote (Germania, etc.)

## API Endpoints

### Autentificare
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/auth/login_schatzmeister.php` | POST | Login Schatzmeister |
| `/api/auth/register.php` | POST | Registrare |
| `/api/auth/recover.php` | POST | Recuperare parolă |
| `/api/auth/change_password.php` | POST | Schimbă parola |
| `/api/auth/change_email.php` | POST | Schimbă email |
| `/api/auth/refresh.php` | POST | Refresh JWT token |
| `/api/auth/validate.php` | POST | Validează token |
| `/api/auth/get_profile.php` | GET | Obține profil utilizator |
| `/api/auth/update_profile.php` | POST | Actualizează profil |
| `/api/auth/update_personal_data.php` | POST | Actualizează date personale |
| `/api/auth/update_mitgliedsart.php` | POST | Actualizează tipul de membru |
| `/api/auth/update_zahlungsmethode.php` | POST | Actualizează metoda de plată |
| `/api/auth/account_status.php` | GET | Status cont |
| `/api/auth/check_email.php` | POST | Verifică dacă email există |
| `/api/auth/delete_account.php` | POST | Șterge cont |
| `/api/auth/accept_document.php` | POST | Acceptă document |
| `/api/auth/heartbeat.php` | POST | Update last_seen (heartbeat every 15s) |
| `/api/auth/heartbeat_app.php` | POST | Heartbeat pentru app (alternativ) |
| `/api/auth/my_dokumente.php` | GET | Documentele mele |
| `/api/auth/my_dokumente_download.php` | GET | Download document personal |
| `/api/auth/my_verifizierung.php` | GET | Status verificare |
| `/api/auth/my_verwarnungen.php` | GET | Avertismentele mele |

### Admin - User Management
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/users.php` | GET | Lista utilizatori |
| `/api/admin/user_status.php` | POST | Schimbă status |
| `/api/admin/user_delete.php` | POST | Șterge user |
| `/api/admin/user_details.php` | POST | Get user + sessions + devices |
| `/api/admin/user_update.php` | POST | Update name/email/password/rol |
| `/api/admin/user_qualifikationen.php` | POST | Calificări utilizator |
| `/api/admin/user_schulbildung.php` | POST | Educație utilizator |
| `/api/admin/admin_register.php` | POST | Înregistrare admin |
| `/api/admin/session_revoke.php` | POST | Force logout device |
| `/api/admin/status_message.php` | POST | Mesaj status |
| `/api/admin/vereineinstellungen.php` | POST | Setări asociație |
| `/api/admin/verifizierung_list.php` | GET | Lista verificări |
| `/api/admin/verifizierung_update.php` | POST | Actualizează verificare |
| `/api/admin/verwarnungen_create.php` | POST | Crează avertisment |
| `/api/admin/verwarnungen_delete.php` | POST | Șterge avertisment |
| `/api/admin/verwarnungen_list.php` | GET | Lista avertismente |

### Admin - Dokumente
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/dokumente_upload.php` | POST | Upload document |
| `/api/admin/dokumente_download.php` | GET | Download document |
| `/api/admin/dokumente_list.php` | GET | Lista documente |
| `/api/admin/dokumente_delete.php` | POST | Șterge document |

### Admin - Finanzen
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/finanzen_get.php` | GET | Obține date financiare |
| `/api/admin/finanzen_save.php` | POST | Salvează date financiare |
| `/api/admin/finanzverwaltung/beitragszahlungen.php` | GET/POST | Plăți contribuții |
| `/api/admin/finanzverwaltung/spenden.php` | GET/POST | Donații |
| `/api/admin/finanzverwaltung/transaktionen.php` | GET/POST | Tranzacții bancare |
| `/api/admin/grundfreibetrag.php` | GET | Scutire de bază (tax) |
| `/api/admin/pkonto_freibetrag.php` | GET | P-Konto scutire |

### Admin - Arbeitsagentur & Arbeitgeber
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/aa_korr_list.php` | GET | Lista corespondență Arbeitsagentur |
| `/api/admin/aa_korr_upload.php` | POST | Upload corespondență AA |
| `/api/admin/aa_korr_download.php` | GET | Download corespondență AA |
| `/api/admin/aa_korr_delete.php` | POST | Șterge corespondență AA |
| `/api/admin/aa_korr_update_widerspruch.php` | POST | Update contestație AA |
| `/api/admin/arbeitgeber_create.php` | POST | Crează angajator |
| `/api/admin/arbeitgeber_update.php` | POST | Actualizează angajator |
| `/api/admin/arbeitgeber_delete.php` | POST | Șterge angajator |
| `/api/admin/arbeitgeber_list.php` | GET | Lista angajatori |
| `/api/admin/arbeitgeber_docs_upload.php` | POST | Upload documente angajator |
| `/api/admin/arbeitgeber_docs_download.php` | GET | Download documente angajator |
| `/api/admin/arbeitgeber_docs_list.php` | GET | Lista documente angajator |
| `/api/admin/arbeitgeber_docs_delete.php` | POST | Șterge documente angajator |
| `/api/admin/arbeitsvermittler_manage.php` | POST | Management intermediari de muncă |

### Admin - Berufserfahrung & Bildung
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/berufserfahrung_list.php` | GET | Lista experiență profesională |
| `/api/admin/berufserfahrung_save.php` | POST | Salvează experiență |
| `/api/admin/berufserfahrung_delete.php` | POST | Șterge experiență |
| `/api/admin/berufserfahrung_dok_list.php` | GET | Lista documente experiență |
| `/api/admin/berufserfahrung_dok_upload.php` | POST | Upload doc experiență |
| `/api/admin/berufserfahrung_dok_download.php` | GET | Download doc experiență |
| `/api/admin/berufserfahrung_dok_delete.php` | POST | Șterge doc experiență |
| `/api/admin/berufsbezeichnungen_list.php` | GET | Lista denumiri profesii |
| `/api/admin/schulabschluesse_list.php` | GET | Lista diplome |
| `/api/admin/schulbildung_dok.php` | GET/POST | Documente educație |
| `/api/admin/schulbildung_dok_download.php` | GET | Download doc educație |
| `/api/admin/schulen_manage.php` | POST | Management școli |
| `/api/admin/kurs_traeger_manage.php` | POST | Management furnizori cursuri |

### Admin - Gesundheit
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/gesundheit_get.php` | GET | Date sănătate |
| `/api/admin/gesundheit_save.php` | POST | Salvează date sănătate |
| `/api/admin/gesundheit_doc_list.php` | GET | Lista documente sănătate |
| `/api/admin/gesundheit_doc_upload.php` | POST | Upload doc sănătate |
| `/api/admin/gesundheit_doc_download.php` | GET | Download doc sănătate |
| `/api/admin/gesundheit_doc_delete.php` | POST | Șterge doc sănătate |
| `/api/admin/gesundheit_medikamente_list.php` | GET | Lista medicamente |
| `/api/admin/gesundheit_medikamente_save.php` | POST | Salvează medicamente |
| `/api/admin/gesundheit_termine_list.php` | GET | Lista programări medicale |
| `/api/admin/gesundheit_termine_save.php` | POST | Salvează programări medicale |
| `/api/admin/aerzte_manage.php` | POST | Management medici |
| `/api/admin/medikamente_search.php` | GET | Caută medicamente |

### Admin - Behörden & Finanzamt
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/behoerde_get.php` | GET | Date autoritate |
| `/api/admin/behoerde_save.php` | POST | Salvează date autoritate |
| `/api/admin/behoerden_standorte.php` | GET | Locații autorități |
| `/api/admin/behoerde_antrag_docs.php` | GET | Documente cerere autoritate |
| `/api/admin/behoerde_antrag_upload.php` | POST | Upload cerere |
| `/api/admin/behoerde_antrag_download.php` | GET | Download cerere |
| `/api/admin/finanzaemter_list.php` | GET | Lista birouri fiscale |
| `/api/admin/finanzamt/dokumente.php` | GET | Documente Finanzamt |
| `/api/admin/finanzamt/download.php` | GET | Download doc Finanzamt |
| `/api/admin/finanzamt_korrespondenz_list.php` | GET | Corespondență Finanzamt |
| `/api/admin/finanzamt_korrespondenz_upload.php` | POST | Upload coresp. Finanzamt |
| `/api/admin/finanzamt_korrespondenz_download.php` | GET | Download coresp. Finanzamt |
| `/api/admin/finanzamt_korrespondenz_delete.php` | POST | Șterge coresp. Finanzamt |
| `/api/admin/ocr_lohnsteuerbescheinigung.php` | POST | OCR certificat fiscal |

### Admin - Versicherungen & Befreiungen
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/krankenkassen_list.php` | GET | Lista asigurări de sănătate |
| `/api/admin/kk_korrespondenz_list.php` | GET | Corespondență asigurare sănătate |
| `/api/admin/kk_korrespondenz_upload.php` | POST | Upload coresp. asigurare |
| `/api/admin/kk_korrespondenz_download.php` | GET | Download coresp. asigurare |
| `/api/admin/kk_korrespondenz_delete.php` | POST | Șterge coresp. asigurare |
| `/api/admin/befreiung_list.php` | GET | Lista scutiri |
| `/api/admin/befreiung_upload.php` | POST | Upload scutire |
| `/api/admin/befreiung_download.php` | GET | Download scutire |
| `/api/admin/befreiung_update.php` | POST | Actualizează scutire |
| `/api/admin/befreiung_delete.php` | POST | Șterge scutire |
| `/api/admin/ermaessigung_list.php` | GET | Lista reduceri |
| `/api/admin/ermaessigung_update.php` | POST | Actualizează reducere |
| `/api/admin/ermaessigung_download.php` | GET | Download reducere |
| `/api/admin/ermaessigung_delete.php` | POST | Șterge reducere |
| `/api/admin/ermaessigung_poll.php` | POST | Poll reduceri |
| `/api/admin/ermaessigung_remind.php` | POST | Reminder reducere |

### Admin - Kredit & Banken
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/banken_manage.php` | POST | Management bănci |
| `/api/admin/kredit_korr_list.php` | GET | Corespondență credit |
| `/api/admin/kredit_korr_upload.php` | POST | Upload coresp. credit |
| `/api/admin/kredit_korr_download.php` | GET | Download coresp. credit |
| `/api/admin/kredit_korr_delete.php` | POST | Șterge coresp. credit |

### Admin - Routinen & Notizen & Archiv
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/routine_list.php` | GET | Lista rutine |
| `/api/admin/routine_create.php` | POST | Crează rutină |
| `/api/admin/routine_update.php` | POST | Actualizează rutină |
| `/api/admin/routine_delete.php` | POST | Șterge rutină |
| `/api/admin/routine_executions.php` | GET/POST | Execuții rutine |
| `/api/admin/notizen_list.php` | GET | Lista notițe |
| `/api/admin/notizen_create.php` | POST | Crează notiță |
| `/api/admin/notizen_delete.php` | POST | Șterge notiță |
| `/api/admin/archiv_list.php` | GET | Lista arhivă |
| `/api/admin/archiv_upload.php` | POST | Upload în arhivă |
| `/api/admin/archiv_download.php` | GET | Download din arhivă |
| `/api/admin/archiv_delete.php` | POST | Șterge din arhivă |

### Admin - Diverse Listen
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/feiertage_list.php` | GET | Lista sărbători legale |
| `/api/admin/sprachen_list.php` | GET | Lista limbi |
| `/api/admin/staatsangehoerigkeiten_list.php` | GET | Lista cetățenii |
| `/api/admin/fuehrerscheinklassen_list.php` | GET | Categorii permis |
| `/api/admin/deutschlandticket_saetze.php` | GET | Tarife Deutschlandticket |
| `/api/admin/jobcenter_regelsaetze.php` | GET | Tarife standard Jobcenter |
| `/api/admin/kindergeld_saetze.php` | GET | Tarife alocații copii |
| `/api/admin/versorgungsamt_manage.php` | POST | Management oficiu asistență socială |
| `/api/admin/handelsregister.php` | GET | Handelsregister server-side |
| `/api/admin/handelsregister_document.php` | GET | Document Handelsregister |
| `/api/admin/freizeit_get.php` | GET | Date timp liber |
| `/api/admin/freizeit_save.php` | POST | Salvează date timp liber |
| `/api/admin/freizeit_datenbank.php` | GET | Baza de date timp liber |

### Termine (Terminverwaltung)
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/termine_create.php` | POST | Create termin cu participanți |
| `/api/admin/termine_list.php` | GET | Lista termine (weekly filter) |
| `/api/admin/termine_details.php` | POST | Termin + participants |
| `/api/admin/termine_update.php` | POST | Update termin fields |
| `/api/admin/termine_delete.php` | POST | Delete termin |
| `/api/termine/my_termine.php` | GET | My termine (member) |
| `/api/termine/respond.php` | POST | Confirm/Decline/Reschedule |

### Urlaub (Vacation Days)
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/admin/urlaub_create.php` | POST | Create vacation period |
| `/api/admin/urlaub_list.php` | GET | Lista urlaub periods |
| `/api/admin/urlaub_update.php` | POST | Update start/end dates |
| `/api/admin/urlaub_delete.php` | POST | Delete urlaub period |

### Device/Session Management
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/auth/my_sessions.php` | GET | My active sessions (member) |
| `/api/auth/revoke_my_session.php` | POST | Self-service logout |
| `/api/auth/logout_device.php` | POST | Logout before login (max 3) |
| `/api/device/register.php` | POST | Înregistrează device nou |
| `/api/device/validate.php` | POST | Validează device key |

### Chat (Live Chat)
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/chat/start.php` | POST | Pornește conversație nouă |
| `/api/chat/admin_start.php` | POST | Admin pornește conversație |
| `/api/chat/close.php` | POST | Închide conversație |
| `/api/chat/conversations.php` | GET | Lista conversații |
| `/api/chat/messages.php` | GET | Istoric mesaje |
| `/api/chat/send.php` | POST | Trimite mesaj |
| `/api/chat/mark_read.php` | POST | Marchează mesaje ca citite |
| `/api/chat/mute.php` | POST | Mute conversație |
| `/api/chat/upload.php` | POST | Upload fișier atașat |
| `/api/chat/download.php` | GET | Download atașament |
| `/api/chat/support_status.php` | GET | Status suport online |
| `/api/chat/scheduled_messages.php` | GET/POST | Mesaje programate |
| `/api/chat/conversation_scheduled.php` | GET | Mesaje programate per conversație |

### Tickets (Ticketverwaltung)
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/tickets/create.php` | POST | Creează ticket |
| `/api/tickets/admin_create.php` | POST | Admin creează ticket |
| `/api/tickets/list.php` | GET | Lista tickete utilizator |
| `/api/tickets/admin_list.php` | GET | Lista toate ticketele (admin) |
| `/api/tickets/update.php` | POST | Actualizează status ticket |
| `/api/tickets/mark_viewed.php` | POST | Marchează ticket ca vizualizat |
| `/api/tickets/poll_notifications.php` | POST | Poll notificări tickete (admin, polling la 10s) |
| `/api/tickets/poll_notifications_member.php` | POST | Poll notificări tickete (membru) |
| `/api/tickets/comments/add.php` | POST | Adaugă comentariu la ticket |
| `/api/tickets/comments/list.php` | GET | Lista comentarii ticket |
| `/api/tickets/attachments/upload.php` | POST | Upload atașament ticket |
| `/api/tickets/attachments/download.php` | GET | Download atașament ticket |
| `/api/tickets/attachments/delete.php` | POST | Șterge atașament ticket |
| `/api/tickets/aufgaben/list.php` | GET | Lista task-uri ticket |
| `/api/tickets/aufgaben/create.php` | POST | Crează task în ticket |
| `/api/tickets/aufgaben/update.php` | POST | Actualizează task |
| `/api/tickets/aufgaben/toggle.php` | POST | Toggle completare task |
| `/api/tickets/aufgaben/delete.php` | POST | Șterge task |
| `/api/tickets/categories/list.php` | GET | Lista categorii tickete |
| `/api/tickets/history/list.php` | GET | Istoric ticket |
| `/api/tickets/time/start.php` | POST | Start time tracking |
| `/api/tickets/time/stop.php` | POST | Stop time tracking |
| `/api/tickets/time/add.php` | POST | Adaugă timp manual |
| `/api/tickets/time/delete.php` | POST | Șterge înregistrare timp |
| `/api/tickets/time/list.php` | GET | Lista timp per ticket |
| `/api/tickets/time/running.php` | GET | Timere active |
| `/api/tickets/time/sync.php` | POST | Sincronizare timp |
| `/api/tickets/time/user_summary.php` | GET | Sumar timp per utilizator |
| `/api/tickets/time/weekly.php` | GET | Raport timp săptămânal |

### Notar (Notariatsverwaltung)
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/notar/besuche.php` | GET | Lista vizite notar |
| `/api/notar/dokumente.php` | GET | Lista documente notar |
| `/api/notar/rechnungen.php` | GET | Lista facturi notar |
| `/api/notar/zahlungen.php` | GET | Lista plăți notar |
| `/api/notar/aufgaben.php` | GET/POST | Task-uri notar |

### Vereinverwaltung
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/vereinverwaltung/get.php` | GET | Obține date asociație |
| `/api/vereinverwaltung/update.php` | POST | Actualizează date asociație |
| `/api/vereinverwaltung/board_members.php` | GET | Membri consiliu |

### Stadtverwaltung
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/stadtverwaltung/behoerden.php` | GET | Lista autorități locale |
| `/api/stadtverwaltung/drogerien.php` | GET | Lista drogherii |
| `/api/stadtverwaltung/krankenhaeuser.php` | GET | Lista spitale |
| `/api/stadtverwaltung/krankenkassen.php` | GET | Lista asigurări sănătate |
| `/api/stadtverwaltung/maerkte.php` | GET | Lista piețe/magazine |
| `/api/stadtverwaltung/praxen.php` | GET | Lista cabinete medicale |

### Tracking (DHL / Deutsche Post)
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/tracking/dhl.php` | GET/POST | DHL tracking |
| `/api/tracking/dhl_settings.php` | GET/POST | Setări DHL |
| `/api/tracking/filialfinder.php` | GET | Finder filiale DHL |

### Platform (Aufgaben, Notizen, Postcard)
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/platform/aufgaben_list.php` | GET | Lista task-uri |
| `/api/platform/aufgaben_create.php` | POST | Crează task |
| `/api/platform/aufgaben_update.php` | POST | Actualizează task |
| `/api/platform/aufgaben_delete.php` | POST | Șterge task |
| `/api/platform/notizen_list.php` | GET | Lista notițe |
| `/api/platform/notizen_create.php` | POST | Crează notiță |
| `/api/platform/notizen_delete.php` | POST | Șterge notiță |
| `/api/platform/postcard_list.php` | GET | Lista cărți poștale |
| `/api/platform/postcard_create.php` | POST | Crează carte poștală |
| `/api/platform/postcard_update.php` | POST | Actualizează carte poștală |
| `/api/platform/postcard_delete.php` | POST | Șterge carte poștală |
| `/api/platform/postcard_account_get.php` | GET | Cont serviciu cărți poștale |
| `/api/platform/postcard_account_save.php` | POST | Salvează cont serviciu |
| `/api/platform/get_credentials.php` | GET | Obține credențiale |
| `/api/platform/save_credentials.php` | POST | Salvează credențiale |

### Member (Self-Service)
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/member/update_personal_data.php` | POST | Actualizează date personale |
| `/api/member/update_finanzielle_situation.php` | POST | Actualizează situație financiară |
| `/api/member/update_mitgliedschaftsbeginn.php` | POST | Actualizează data începerii |
| `/api/member/update_zahlungsdaten.php` | POST | Actualizează date plată |
| `/api/member/upload_leistungsbescheid.php` | POST | Upload decizie prestații |
| `/api/member/verifizierung_list.php` | GET | Lista verificări membru |

### FCM (Firebase Cloud Messaging)
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/fcm/register.php` | POST | Înregistrare token FCM |
| `/api/fcm/unregister.php` | POST | Dezînregistrare token FCM |

### System & Diagnostics
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/version_schatzmeister.php` | GET | Version check Schatzmeister (protected, requires Device Key) |
| `/api/changelog_schatzmeister.php` | GET | Changelog Schatzmeister (protected, requires Device Key) |
| `/api/debug_messages.php` | GET/POST | Debug messages |
| `/api/diagnostic/log.php` | POST | Log diagnostic app (15s interval) |
| `/api/logs/debug.php` | POST | Log debug messages |
| `/api/logs/store.php` | POST | Store app logs |
| `/api/logs/schatzmeister_logs.php` | POST | **Real-time log upload Schatzmeister (30s interval)** |

### Cron Jobs
| Endpoint | Method | Descriere |
|----------|--------|-----------|
| `/api/cron/auto_suspend.php` | GET | Suspendare automată conturi |
| `/api/cron/auto_delete_expired_docs.php` | GET | Ștergere documente expirate |
| `/api/cron/cleanup_chat.php` | GET | Curățare chat vechi |
| `/api/cron/cleanup_old_scheduled_messages.php` | GET | Curățare mesaje programate vechi |
| `/api/cron/send_scheduled_messages.php` | GET | Trimitere mesaje programate |

### Config & Helpers
| File | Descriere |
|------|-----------|
| `/api/config.php` | Configurație DB + constante |
| `/api/helpers.php` | Funcții helper (JWT, auth, etc.) |
| `/api/helpers/FcmService.php` | Serviciu Firebase Cloud Messaging |
| `/api/helpers/NtfyService.php` | Serviciu ntfy push notifications (Mitglieder, prefix: icd360s_) |
| `/api/helpers/NtfySchatzmeisterService.php` | Serviciu ntfy push notifications (Schatzmeister, prefix: schatzmeister_) |
| `/api/helpers/ip_helper.php` | Helper funcții IP |
| `/api/helpers/TranslationHelper.php` | Helper traduceri |
| `/api/helpers/WebSocketNotifier.php` | Notificări WebSocket |

## Structura Proiect

```
lib/
├── main.dart                        # App entry point + window initialization
├── services/                        # Business logic layer (24 services)
│   ├── http_client_factory.dart     # Certificate pinning (ISRG Root X1 / Let's Encrypt)
│   ├── api_service.dart             # HTTP requests + token management + cert pinning
│   ├── chat_service.dart            # WebSocket chat + call signaling + cert pinning
│   ├── voice_call_service.dart      # WebRTC voice call
│   ├── termin_service.dart          # Termine + Urlaub management
│   ├── ticket_service.dart          # Ticket system
│   ├── ticket_notification_service.dart  # Ticket notification polling (10s)
│   ├── device_key_service.dart      # Device registration + validation
│   ├── update_service.dart          # Auto-update checker + silent installer
│   ├── diagnostic_service.dart      # App diagnostics (15s interval)
│   ├── notification_service.dart    # Cross-platform notifications (flutter_local_notifications)
│   ├── logger_service.dart          # Debug logging + real-time upload
│   ├── tray_service.dart            # System tray management (desktop)
│   ├── startup_service.dart         # Auto-start with OS (desktop)
│   ├── heartbeat_service.dart       # Real-time last_seen updates (15s)
│   ├── dokumente_service.dart       # Document management service
│   ├── handelsregister_client_service.dart  # Handelsregister.de client-side scraping
│   ├── verwarnung_service.dart      # Warning/penalty management
│   ├── platform_service.dart        # Platform detection + capabilities
│   ├── network_info_service.dart    # Network connectivity detection
│   ├── news_service.dart            # News/updates feed
│   ├── routine_service.dart         # Routine tasks management (encrypted)
│   ├── weather_service.dart         # Weather information
│   └── ntfy_service.dart            # Self-hosted push notifications (ntfy, no Google)
├── models/                          # Data models
│   └── user.dart                    # User model (id, mitgliedernummer, role, status)
├── screens/                         # Full-page views (31 screens)
│   ├── login_screen.dart            # Login/Register tabs
│   ├── dashboard_screen.dart        # Admin dashboard (Schatzmeister)
│   ├── terminverwaltung_screen.dart # Weekly calendar + urlaub
│   ├── ticketverwaltung_screen.dart # Ticket management
│   ├── finanzverwaltung_screen.dart # Financial management (Beiträge, Spenden, Transaktionen)
│   ├── vereinverwaltung_screen.dart # Organization admin
│   ├── notar_screen.dart            # Notary functions
│   ├── webview_screen.dart          # Embedded browser
│   ├── behoerden_screen.dart        # Government authorities screen
│   ├── deutschepost_screen.dart     # Deutsche Post tracking & services
│   ├── sendungsverfolgung.dart      # Package tracking (DHL)
│   ├── handelsregister_screen.dart  # Trade register (Handelsregister.de)
│   ├── vereinregister_screen.dart   # Association register
│   ├── finanzamt_screen.dart        # Tax office (Finanzamt)
│   ├── arbeitsagentur_screen.dart   # Employment agency (Arbeitsagentur)
│   ├── gls_bank_screen.dart         # GLS Bank online banking
│   ├── vr_bank_screen.dart          # VR Bank online banking
│   ├── archiv_screen.dart           # Document archive
│   ├── statistik_screen.dart        # Statistics & reports
│   ├── ordnungsmassnahmen_screen.dart # Disciplinary measures
│   ├── routinenaufgaben_screen.dart # Routine tasks management
│   ├── reiseplanung_screen.dart     # Travel planning
│   ├── db_mobilitat_unterstutzung_screen.dart # DB mobility support
│   ├── netzwerk_screen.dart         # Network & partnerships
│   ├── dienste_screen.dart          # Services overview
│   ├── google_nonprofit_screen.dart # Google for Nonprofits
│   ├── microsoft_nonprofit_screen.dart # Microsoft Nonprofits
│   ├── stifter_helfen_screen.dart   # Stifter-helfen (IT donations)
│   ├── jpg2pdf_screen.dart          # JPG to PDF converter
│   ├── pdf_manager_screen.dart      # PDF document manager
│   └── postcard.dart                # Postcard creation & sending
├── widgets/                         # Reusable UI components (30 widgets)
│   ├── dashboard_sidebar.dart       # Navigation sidebar
│   ├── dashboard_stats.dart         # Statistics cards
│   ├── user_data_table.dart         # User list table
│   ├── user_details_dialog.dart     # Edit user + device/session management
│   ├── profile_dialog.dart          # User profile view
│   ├── personal_data_dialog.dart    # Edit personal info
│   ├── login_tab.dart               # Login form
│   ├── register_tab.dart            # Register form
│   ├── forgot_password_dialog.dart  # Password recovery
│   ├── admin_chat_dialog.dart       # Admin chat interface
│   ├── live_chat_dialog.dart        # Member chat interface
│   ├── chat_header.dart             # Chat dialog header
│   ├── chat_message_bubble.dart     # Message display
│   ├── chat_input_area.dart         # Message input
│   ├── chat_attachment_item.dart    # File attachment display
│   ├── conversation_list_item.dart  # Chat list item + online status
│   ├── incoming_call_dialog.dart    # Voice call UI
│   ├── termin_dialogs.dart          # Create/Edit termine
│   ├── ticket_dialogs.dart          # Create/View tickets
│   ├── ticket_details_dialog.dart   # View ticket details + camera capture + crop
│   ├── notar_dialogs.dart           # Notar-specific dialogs
│   ├── notar_cards.dart             # Notar info cards
│   ├── confirm_dialogs.dart         # Generic confirmations
│   ├── legal_footer.dart            # Footer + version + changelog + update checker
│   ├── changelog.dart               # Changelog viewer dialog
│   ├── update_dialog.dart           # Update notification + download
│   ├── debug_console.dart           # Debug output console
│   ├── diagnostic_consent_dialog.dart # Diagnostic opt-in
│   ├── file_viewer_dialog.dart      # File preview dialog (PDF, images)
│   ├── responsive_layout.dart       # Responsive layout wrapper
│   └── visitenkarte.dart            # Business card widget
└── utils/                           # Helper functions
    └── role_helpers.dart            # Role colors, prefixes, status helpers

installer/
├── icd360sev_setup.iss              # Inno Setup installer script
├── vc_redist.x64.exe                # Visual C++ redistributable
└── MicrosoftEdgeWebView2RuntimeInstallerX64.exe  # WebView2 runtime

assets/
└── app_icon.ico                     # Windows app icon

windows/                             # Native Windows integration
├── CMakeLists.txt                   # Windows build config
├── flutter/                         # Flutter Windows wrapper
└── runner/                          # Native Windows runner
```

### Services Directory (lib/services/) - Detailed (22 Services)

| Service | Descriere |
|---------|-----------|
| `api_service.dart` | HTTP client, JWT token management, device key validation, refresh token |
| `chat_service.dart` | WebSocket connection, auto-reconnect, real-time chat, online status tracking, call signaling |
| `voice_call_service.dart` | WebRTC voice calls, ICE candidates, audio codec management |
| `termin_service.dart` | Appointment management, vacation periods, weekly calendar data |
| `ticket_service.dart` | Ticket CRUD operations, status management |
| `ticket_notification_service.dart` | Ticket notification polling (10s interval), native notifications |
| `device_key_service.dart` | Generate unique device keys, device registration |
| `update_service.dart` | Version checking, installer download, silent update launch |
| `notification_service.dart` | Cross-platform notifications (flutter_local_notifications) |
| `diagnostic_service.dart` | App telemetry (15s interval), performance monitoring |
| `heartbeat_service.dart` | Real-time last_seen updates (15s interval), online status tracking |
| `logger_service.dart` | Centralized logging, device ID generation, real-time log upload to server |
| `startup_service.dart` | Auto-start with OS configuration (desktop only) |
| `tray_service.dart` | System tray management, minimize to tray (desktop only) |
| `dokumente_service.dart` | Document management service (upload, download, organize) |
| `handelsregister_client_service.dart` | Client-side handelsregister.de scraping (HTML parsing) |
| `verwarnung_service.dart` | Warning/penalty management system |
| `platform_service.dart` | Platform detection (Windows/macOS/Linux/Android/iOS) and capabilities check |
| `network_info_service.dart` | Network connectivity detection and monitoring |
| `news_service.dart` | News/updates feed service |
| `routine_service.dart` | Routine tasks management with AES-256 encryption |
| `weather_service.dart` | Weather information service |
| `ntfy_service.dart` | Self-hosted push notifications via ntfy (topic: schatzmeister_{mitgliedernummer}) |
| `http_client_factory.dart` | Certificate pinning factory (ISRG Root X1 / Let's Encrypt only) |

### Screens Directory (lib/screens/) - Detailed (31 Screens)

| Screen | Descriere |
|--------|-----------|
| `login_screen.dart` | Login/Register tabs, credential saving, password recovery |
| `dashboard_screen.dart` | Schatzmeister dashboard, user management, statistics, heartbeat start |
| `terminverwaltung_screen.dart` | Weekly calendar, appointment scheduling, vacation management (Urlaub) |
| `ticketverwaltung_screen.dart` | Ticket management system with camera capture + crop support |
| `finanzverwaltung_screen.dart` | Financial management - Beitragszahlungen, Spenden, Transaktionen |
| `vereinverwaltung_screen.dart` | Organization/association administration |
| `notar_screen.dart` | Notary functions and documents |
| `webview_screen.dart` | Embedded browser for external content |
| `behoerden_screen.dart` | Government authorities (Behörden) - contact info, forms, tracking |
| `deutschepost_screen.dart` | Deutsche Post tracking & services |
| `sendungsverfolgung.dart` | DHL package tracking (Sendungsverfolgung) |
| `handelsregister_screen.dart` | Trade register (Handelsregister.de) - client-side scraping, company search |
| `vereinregister_screen.dart` | Association register (Vereinsregister) - search and view associations |
| `finanzamt_screen.dart` | Tax office (Finanzamt) - correspondence, documents, OCR |
| `arbeitsagentur_screen.dart` | Employment agency (Arbeitsagentur) - correspondence, Widerspruch |
| `gls_bank_screen.dart` | GLS Bank - online banking integration |
| `vr_bank_screen.dart` | VR Bank - online banking integration |
| `archiv_screen.dart` | Document archive management (upload, download, organize) |
| `statistik_screen.dart` | Statistics and reports dashboard |
| `ordnungsmassnahmen_screen.dart` | Disciplinary measures (Ordnungsmaßnahmen) |
| `routinenaufgaben_screen.dart` | Routine tasks management with scheduling |
| `reiseplanung_screen.dart` | Travel planning and booking |
| `db_mobilitat_unterstutzung_screen.dart` | Deutsche Bahn mobility support |
| `netzwerk_screen.dart` | Network, partnerships and contacts |
| `dienste_screen.dart` | Services overview and management |
| `google_nonprofit_screen.dart` | Google for Nonprofits integration |
| `microsoft_nonprofit_screen.dart` | Microsoft Nonprofits integration |
| `stifter_helfen_screen.dart` | Stifter-helfen IT donations platform |
| `jpg2pdf_screen.dart` | JPG to PDF converter tool |
| `pdf_manager_screen.dart` | PDF document manager |
| `postcard.dart` | Postcard creation and sending |

### Widgets Directory (lib/widgets/) - Detailed (30 Widgets)

**Dialog Components:**
- `user_details_dialog.dart` - View/edit user, device/session management
- `profile_dialog.dart` - User profile display and settings
- `forgot_password_dialog.dart` - Password recovery flow
- `personal_data_dialog.dart` - Personal information editor
- `termin_dialogs.dart` - Create/edit appointments with participants
- `ticket_dialogs.dart` - Create/view tickets with attachments
- `ticket_details_dialog.dart` - **View ticket details + macOS camera capture + crop/edit photo** (NEW!)
- `notar_dialogs.dart` - Notary-specific dialogs
- `confirm_dialogs.dart` - Generic confirmation dialogs
- `update_dialog.dart` - App update notification + download progress
- `incoming_call_dialog.dart` - Incoming voice call UI
- `diagnostic_consent_dialog.dart` - Diagnostic data opt-in
- `file_viewer_dialog.dart` - File preview dialog (PDF, images) with pdfrx

**Chat Components:**
- `admin_chat_dialog.dart` - Admin chat interface with online user list
- `live_chat_dialog.dart` - Member chat interface, message history
- `chat_header.dart` - Chat dialog header with user status
- `chat_message_bubble.dart` - Individual message display
- `chat_input_area.dart` - Message input & send functionality
- `conversation_list_item.dart` - Chat list item with online status indicator
- `chat_attachment_item.dart` - File attachment display

**Dashboard Components:**
- `dashboard_sidebar.dart` - Navigation sidebar with role-based menu
- `dashboard_stats.dart` - Statistics cards (total users, active, suspended)
- `user_data_table.dart` - User list table with sorting/filtering

**Login Components:**
- `login_tab.dart` - Login form with credential save option
- `register_tab.dart` - Registration form

**Other Components:**
- `legal_footer.dart` - Footer with version, changelog, update checker (5min timer)
- `changelog.dart` - Changelog viewer dialog (reads from server API)
- `debug_console.dart` - Debug output console
- `notar_cards.dart` - Notary information cards
- `responsive_layout.dart` - Responsive layout wrapper for cross-platform UI
- `visitenkarte.dart` - Business card widget (contact info display)

## Pachete Flutter

```yaml
dependencies:
  # ============================================================
  # CORE PACKAGES
  # ============================================================
  http: ^1.2.0                      # HTTP requests
  shared_preferences: ^2.3.0        # Local storage for tokens
  provider: ^6.1.0                  # State management
  flutter_secure_storage: ^10.0.0   # Encrypted credentials (DPAPI/Keychain/libsecret)
  cupertino_icons: ^1.0.8           # iOS style icons

  # ============================================================
  # NETWORKING & REAL-TIME
  # ============================================================
  web_socket_channel: ^3.0.1        # WebSocket for real-time chat
  flutter_webrtc: ^1.2.1            # WebRTC for voice/video calls
  connectivity_plus: ^7.0.0         # Network connectivity detection
  html: ^0.15.4                     # HTML parsing for handelsregister.de scraping

  # ============================================================
  # UI & LOCALIZATION
  # ============================================================
  flutter_localizations:            # German date/time pickers (SDK)
    sdk: flutter
  intl: ^0.20.2                     # Date formatting + week number calculation

  # ============================================================
  # FILE HANDLING & MEDIA
  # ============================================================
  path_provider: ^2.1.0             # Temp directory access
  file_picker: ^8.0.0               # File attachments (chat, tickets)
  image_picker: ^1.1.2              # Image picker for camera capture (mobile)
  camera_macos: ^0.0.9              # Native macOS camera capture (AVFoundation)
  crop_your_image: ^2.0.0           # Image cropping (pure Dart, cross-platform)
  signature: ^6.3.0                 # Handwritten signature capture (pure Dart)
  url_launcher: ^6.2.0              # Open URLs in browser
  open_filex: ^4.5.0                # Open files with default app
  pdfrx: ^2.2.24                    # PDF viewer/renderer
  image: ^4.5.4                     # Image processing for PDF compression
  archive: ^4.0.9                   # Archive utilities

  # ============================================================
  # PDF GENERATION & PRINTING
  # ============================================================
  pdf: ^3.11.0                      # PDF generation (Zuwendungsbestätigung/Spendequittung)
  printing: ^5.13.0                 # PDF printing/sharing/saving

  # ============================================================
  # SECURITY & ENCRYPTION
  # ============================================================
  encrypt: ^5.0.3                   # AES-256 encryption for routine data

  # ============================================================
  # NOTIFICATIONS
  # ============================================================
  flutter_local_notifications: ^18.0.0  # Cross-platform notifications

  # ============================================================
  # DEVICE & PLATFORM
  # ============================================================
  device_info_plus: ^12.3.0         # Device identification
  uuid: ^3.0.7                      # UUID generation for device ID
  battery_plus: ^7.0.0              # Battery level monitoring for diagnostics

  # ============================================================
  # DESKTOP-ONLY PACKAGES (Windows, macOS, Linux)
  # ============================================================
  windows_single_instance: ^1.0.1   # Single instance - prevent multiple windows
  webview_windows: ^0.4.0           # WebView for Windows (WebView2)
  window_manager: ^0.5.1            # Window control (size, position, maximize)
  tray_manager: ^0.5.2               # System tray - minimize to tray
  launch_at_startup: ^0.5.1         # Auto-start with OS login
  windows_taskbar: ^1.1.2           # Windows taskbar flash icon and badge

  # ============================================================
  # MOBILE-ONLY PACKAGES (Android, iOS)
  # ============================================================
  webview_flutter: ^4.10.0          # WebView for mobile (Android/iOS)
```

## Server Architecture

### WebSocket Server
**Location:** `/var/www/icd360sev.icd360s.de/websocket/`
**URL:** `wss://icd360sev.icd360s.de/wss/`
**Framework:** Ratchet PHP WebSocket library

**Files:**
- `server.php` - WebSocket entry point, bootstrapper
- `src/ChatServer.php` - Main WebSocket logic (chat, presence, call signaling)

**Event Types (WebSocket Messages):**
| Type | Direction | Descriere |
|------|-----------|-----------|
| `auth` | Client→Server | Autentificare WebSocket cu token |
| `auth_success` | Server→Client | Auth succes + listă online_users |
| `auth_error` | Server→Client | Auth eșuat |
| `chat_message` | Client→Server | Trimite mesaj chat |
| `message` | Server→Client | Mesaj nou primit |
| `typing` | Client→Server | User scrie mesaj |
| `typing_indicator` | Server→Client | Altcineva scrie |
| `read_receipt` | Server→Client | Mesaj citit de destinatar |
| `online_users` | Server→Client | Lista completă utilizatori online (periodic) |
| `user_joined` | Server→Client | Utilizator intră online |
| `user_left` | Server→Client | Utilizator iese offline |
| `user_disconnected` | Server→Client | Utilizator deconectat neașteptat |
| `call_offer` | Server→Client | Ofertă apel voice (WebRTC SDP) |
| `call_answer` | Server→Client | Răspuns apel (WebRTC SDP) |
| `call_rejected` | Server→Client | Apel respins |
| `call_busy` | Server→Client | Apelat ocupat |
| `call_ended` | Server→Client | Apel închis |
| `ice_candidate` | Server→Client | WebRTC ICE candidate |
| `new_device_login` | Server→Client | Notificare device nou detectat |

**WebSocket Server Management:**
```bash
# Verificare status
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n supervisorctl status icd360s-websocket"

# Restart server
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n supervisorctl restart icd360s-websocket"

# View logs
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n tail -f /var/log/icd360s-websocket.out.log"
```

### API Server Structure
**Location:** `/var/www/icd360sev.icd360s.de/api/`
**Base URL:** `https://icd360sev.icd360s.de/api/`

**Directory Structure (223 PHP files, 17 directories):**
```
/var/www/icd360sev.icd360s.de/api/
├── config.php                  # DB config + constante
├── helpers.php                 # JWT, auth, utility functions
├── debug_messages.php          # Debug messages
├── version_schatzmeister.php   # Version check Schatzmeister
├── changelog_schatzmeister.php # Changelog Schatzmeister
├── helpers/                    # Helper classes
│   ├── FcmService.php          # Firebase Cloud Messaging
│   ├── NtfyService.php         # ntfy push notifications (Mitglieder, prefix: icd360s_)
│   ├── NtfySchatzmeisterService.php  # ntfy push notifications (Schatzmeister, prefix: schatzmeister_)
│   ├── ip_helper.php           # IP helper functions
│   ├── TranslationHelper.php   # Translation helper
│   └── WebSocketNotifier.php   # WebSocket notifier
├── auth/                       # Autentificare (20 files)
│   ├── login_schatzmeister.php  # Login Schatzmeister
│   ├── register.php
│   ├── recover.php
│   ├── change_password.php / change_email.php
│   ├── refresh.php / validate.php
│   ├── get_profile.php / update_profile.php
│   ├── update_personal_data.php / update_mitgliedsart.php / update_zahlungsmethode.php
│   ├── account_status.php / check_email.php / delete_account.php / accept_document.php
│   ├── heartbeat.php / heartbeat_app.php
│   ├── my_sessions.php / revoke_my_session.php / logout_device.php
│   └── my_dokumente.php / my_dokumente_download.php / my_verifizierung.php / my_verwarnungen.php
├── schatzmeister/              # Schatzmeister-specific endpoints (31 files, role: schatzmeister)
│   ├── archiv_*.php            # Archive (4 files)
│   ├── befreiung_*.php         # Exemptions (5 files)
│   ├── ermaessigung_*.php      # Discounts (6 files)
│   ├── dokumente_*.php         # Documents (4 files)
│   ├── verwarnungen_*.php      # Warnings (3 files)
│   ├── routine_*.php           # Routines (5 files)
│   ├── notizen_*.php           # Notes (3 files)
│   └── admin_register.php      # Admin registration
├── admin/                      # Admin endpoints (~120 files, role: vorsitzer)
│   ├── users.php / user_*.php  # User management (8 files)
│   ├── termine_*.php           # Termine (5 files)
│   ├── urlaub_*.php            # Urlaub (4 files)
│   ├── dokumente_*.php         # Documents (4 files)
│   ├── finanzen_*.php          # Finance (2 files)
│   ├── finanzverwaltung/       # Financial management (3 files)
│   ├── finanzamt/              # Tax office (2 files)
│   ├── finanzamt_korrespondenz_*.php  # Tax correspondence (4 files)
│   ├── aa_korr_*.php           # Arbeitsagentur correspondence (5 files)
│   ├── arbeitgeber_*.php       # Employer management (7 files)
│   ├── berufserfahrung_*.php   # Work experience (7 files)
│   ├── gesundheit_*.php        # Health management (10 files)
│   ├── kk_korrespondenz_*.php  # Health insurance corr. (4 files)
│   ├── kredit_korr_*.php       # Credit correspondence (4 files)
│   ├── befreiung_*.php         # Exemptions (5 files)
│   ├── ermaessigung_*.php      # Discounts (6 files)
│   ├── routine_*.php           # Routines (5 files)
│   ├── notizen_*.php           # Notes (3 files)
│   ├── archiv_*.php            # Archive (4 files)
│   ├── verwarnungen_*.php      # Warnings (3 files)
│   ├── verifizierung_*.php     # Verification (2 files)
│   ├── behoerde_*.php          # Authorities (6 files)
│   ├── handelsregister*.php    # Trade register (2 files)
│   └── *_list.php / *_manage.php  # Various reference lists (~15 files)
├── chat/                       # Live Chat (12 files)
│   ├── start.php / admin_start.php / close.php
│   ├── conversations.php / messages.php / send.php / mark_read.php
│   ├── upload.php / download.php / mute.php
│   └── support_status.php / scheduled_messages.php / conversation_scheduled.php
├── termine/                    # Termine - member access (3 files)
│   ├── my_termine.php / respond.php / calendar.php
├── tickets/                    # Ticket system (20+ files)
│   ├── create.php / admin_create.php / list.php / admin_list.php / update.php / mark_viewed.php
│   ├── poll_notifications.php / poll_notifications_member.php
│   ├── comments/               # Comments (2 files)
│   ├── attachments/            # Attachments (3 files)
│   ├── aufgaben/               # Task management (5 files)
│   ├── categories/             # Categories (1 file)
│   ├── history/                # History (1 file)
│   └── time/                   # Time tracking (9 files)
├── device/                     # Device management (2 files)
├── notar/                      # Notary system (5 files)
├── vereinverwaltung/           # Organization admin (3 files)
├── stadtverwaltung/            # City admin data (6 files)
├── tracking/                   # DHL tracking (3 files)
├── platform/                   # Platform features (15 files)
├── member/                     # Member self-service (6 files)
├── fcm/                        # Firebase Cloud Messaging (2 files)
├── diagnostic/                 # App diagnostics (1 file)
├── logs/                       # Logging (5 files)
├── cron/                       # Scheduled tasks (6 files)
└── data/                       # Protected JSON files
    ├── version_schatzmeister.json
    ├── changelog_schatzmeister.json
    └── changelog_schatzmeister.json
```

### Database Tables (MySQL)
**Location:** Server MySQL (credentials în `/api/config.php`)

**Key Tables:**
- `users` - User accounts (id, mitgliedernummer, email, password_hash, role, status)
- `sessions` - Active sessions (session_token, user_id, device_key, expires_at)
- `devices` - Registered devices (device_key, user_id, device_name, platform, ip_address)
- `chat_conversations` - Chat conversations (id, mitgliedernummer, admin_id, status)
- `chat_messages` - Chat messages (id, conversation_id, sender_id, message, created_at)
- `chat_attachments` - File attachments (id, message_id, filename, filepath)
- `termine` - Appointments (id, title, date, time, type, created_by)
- `termine_participants` - Appointment participants (termin_id, user_id, status)
- `urlaub` - Vacation periods (id, start_date, end_date, created_by)
- `tickets` - Support tickets (id, user_id, subject, description, status, priority)
- `diagnostic_logs` - App diagnostics (id, user_id, device_key, data, timestamp)

## DLL Files în Inno Setup

**⚠️ CRITICAL:** După adăugarea unui pachet Flutter nativ în `pubspec.yaml`, TREBUIE să adaugi DLL-ul corespunzător în `installer/icd360sev_setup.iss`!

**Dacă uiți să adaugi un DLL, aplicația NU va porni după update și utilizatorul trebuie să descarce manual de pe site!**

### Verificare DLL-uri după build
```bash
# Listează toate DLL-urile din build (rulează după flutter build windows --release)
ls build/windows/x64/runner/Release/*.dll

# Compară cu cele din icd360sev_setup.iss - toate trebuie să fie prezente!
```

### Lista DLL-uri curente (Windows Build)
| DLL File | Pachet Flutter |
|----------|----------------|
| `flutter_windows.dll` | Flutter core |
| `flutter_secure_storage_windows_plugin.dll` | flutter_secure_storage |
| `flutter_webrtc_plugin.dll` | flutter_webrtc |
| `libwebrtc.dll` | flutter_webrtc |
| `flutter_local_notifications_plugin.dll` | flutter_local_notifications (NEW - replaced local_notifier) |
| `screen_retriever_windows_plugin.dll` | window_manager |
| `tray_manager_plugin.dll` | tray_manager |
| `webview_windows_plugin.dll` | webview_windows |
| `WebView2Loader.dll` | webview_windows |
| `window_manager_plugin.dll` | window_manager |
| `windows_single_instance_plugin.dll` | windows_single_instance |
| `url_launcher_windows_plugin.dll` | url_launcher |
| `file_selector_windows_plugin.dll` | file_picker |
| `windows_taskbar_plugin.dll` | windows_taskbar (NEW) |

**Removed DLLs** (no longer needed):
- `desktop_audio_capture_plugin.dll` - Package removed from pubspec.yaml
- `local_notifier_plugin.dll` - Replaced with flutter_local_notifications (cross-platform)

## Comenzi Build & Deploy

### ⚠️ CHECKLIST RELEASE NOU (NU SĂRI PAȘI!)

**Pas 1: Actualizează versiunea în CODUL APLICAȚIEI:**
```
□ pubspec.yaml                     → version: X.X.X+Y
□ lib/services/update_service.dart → currentVersion = 'X.X.X', currentBuildNumber = Y
□ installer/icd360sev_setup.iss    → #define MyAppVersion "X.X.X"
```

**⚠️ ATENȚIE:** Installer-ul (icd360sev_setup.iss) are în prezent MyAppVersion = "1.0.0" — TREBUIE actualizat la release!

**Pas 2: Build APK (obfuscated + split-per-abi):**
```bash
# macOS:
/Users/ionut-claudiuduinea/development/flutter/bin/flutter build apk --release \
  --obfuscate --split-debug-info=build/symbols --split-per-abi

# Windows (Git Bash):
/c/flutter/bin/flutter build apk --release \
  --obfuscate --split-debug-info=build/symbols --split-per-abi

# Output: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (~33MB)
# IMPORTANT: Salvează symbols pentru de-obfuscation crash reports!
mkdir -p ~/symbols/schatzmeister_vX.X.X
cp -r build/symbols/* ~/symbols/schatzmeister_vX.X.X/
```

**Pas 3: Upload APK pe server (F-Droid):**
```bash
# F-Droid naming: de.icd360sev.schatzmeister_{versionCode}.apk
scp -i "$SEV_KEY" -P 36000 \
  "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" \
  icd360sev@icd360sev.icd360s.de:/tmp/de.icd360sev.schatzmeister_Y.apk
# contul `icd360sev` nu poate scrie direct in /var/www -> muta cu sudo:
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n mv /tmp/de.icd360sev.schatzmeister_Y.apk /var/www/icd360sev.icd360s.de/fdroid/repo/ && sudo -n chown nginx:nginx /var/www/icd360sev.icd360s.de/fdroid/repo/de.icd360sev.schatzmeister_Y.apk"

# Apoi rulează fdroid update pe server
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n sh -c 'cd /var/www/icd360sev.icd360s.de/fdroid && fdroid update'"
# ⚠️ CLI-ul `fdroid` NU e instalat pe serverul nou (verificat 2026-08-23) — pasul asta esueaza.
```

**Pas 4: VERIFICĂ MAI ÎNTÂI changelog-ul curent pe server:**
```bash
# CRITICAL: Citește changelog-ul ÎNAINTE de a adăuga versiune nouă!
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n cat /var/www/icd360sev.icd360s.de/api/data/changelog_schatzmeister.json | head -20"

# Verifică:
# 1. Care este ultima versiune (prima în listă cu "is_latest": true)
# 2. Build number-ul ultimei versiuni
# 3. NU adăuga o versiune mai veche decât cea latest!
```

**Pas 5: Actualizează CHANGELOG pe server (detaliat):**
```bash
# Editează changelog_schatzmeister.json
ssh -t -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n nano /var/www/icd360sev.icd360s.de/api/data/changelog_schatzmeister.json"

# Adaugă noua versiune la ÎNCEPUTUL array-ului "versions":
# {
#   "version": "X.X.X",
#   "date": "DD.MM.YYYY",
#   "changes": [
#     "Prima modificare făcută",
#     "A doua modificare făcută",
#     "..."
#   ],
#   "is_latest": true
# }
#
# IMPORTANT: Setează "is_latest": false pentru versiunea veche!
# VERIFICĂ că noua versiune e mai mare decât versiunea anterioară!
# Actualizează "last_updated": "YYYY-MM-DDTHH:MM:SSZ"
```

**Pas 6: Actualizează VERSION INFO pe server (pentru trigger update):**
```bash
# Editează version_schatzmeister.json
ssh -t -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n nano /var/www/icd360sev.icd360s.de/api/data/version_schatzmeister.json"

# Actualizează TOATE câmpurile:
# {
#     "version": "X.X.X",                    # Versiunea nouă
#     "build_number": Y,                     # Build number nou
#     "download_url": "...",                 # Același URL (nu se schimbă)
#     "fallback_url": "...",                 # Același URL (nu se schimbă)
#     "fallback_version": "X.X.Z",           # Versiunea anterioară stabilă
#     "changelog": "Version X.X.X\n\n- Modificarea principală făcută...",  # Changelog SCURT
#     "min_version": null,
#     "force_update": false,
#     "release_date": "YYYY-MM-DD",
#     "file_size": "XX MB"
# }
```

**Pas 7: Verifică pe server:**
```bash
# Verifică version info
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n cat /var/www/icd360sev.icd360s.de/api/data/version_schatzmeister.json"

# Verifică changelog
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n cat /var/www/icd360sev.icd360s.de/api/data/changelog_schatzmeister.json | head -50"
```

### ⚠️ IMPORTANT: ORDINE & TIMING

**CÂND să actualizezi fișierele:**

| CÂND? | CE? | UNDE? | DE CE? |
|-------|-----|-------|--------|
| **ÎNAINTE de build** | Code version | `pubspec.yaml`, `update_service.dart`, `icd360sev_setup.iss` | Versiunea trebuie compilată în .exe |
| **DUPĂ upload APK** | **VERIFICĂ changelog curent** | `cat changelog_schatzmeister.json` (server) | **CRITICAL:** Verifică care e ultima versiune să nu adaugi una mai veche! |
| **DUPĂ verificare** | Changelog detaliat | `/api/data/changelog_schatzmeister.json` (server) | Adaugă noua versiune cu `is_latest: true` |
| **DUPĂ changelog** | Version info | `/api/data/version_schatzmeister.json` (server) | Trigger update în aplicații (UpdateService) |

**DE CE în această ordine?**
1. ✅ Build-ul conține versiunea corectă în cod
2. ✅ APK-ul este disponibil pe server ÎNAINTE ca aplicațiile să primească notificare de update
3. ✅ **VERIFICARE:** Citești changelog-ul curent să știi care e ultima versiune (previne adăugarea versiuni mai vechi!)
4. ✅ Changelog-ul este actualizat cu modificările din noua versiune (doar dacă versiunea nouă > versiunea latest!)
5. ✅ Version info actualizat → aplicațiile primesc notificare de update → descarcă .exe-ul deja disponibil

**DACĂ inversezi ordinea sau NU verifici changelog-ul:**
- ❌ Actualizezi version info ÎNAINTE de upload APK → aplicațiile vor primi update notification dar APK-ul nu există pe server → eroare la download!
- ❌ **NU citești changelog-ul înainte** → poți adăuga o versiune mai veche (ex: 1.0.1) când ultima versiune e 1.0.3 → cronologie greșită!
- ❌ Adaugi versiune veche cu `is_latest: true` → aplicațiile vor downgrade în loc să upgrade → **VERY BAD!**
- ❌ **CRITICAL:** Setezi `version_schatzmeister.json` la o versiune mai mare decât APK-ul urcat → **INFINITE UPDATE LOOP!**
  - Exemplu: APK urcat = 1.0.1, dar version_schatzmeister.json = 1.0.3
  - Aplicația 1.0.1 vede "1.0.3 disponibil" → descarcă → primește tot 1.0.1 → restart → vede iar "1.0.3 disponibil" → LOOP!

### Comenzi Flutter (Bash - pentru Claude)

**Windows (Git Bash):**
```bash
# Navigare la proiect
cd /c/Users/icd_U/Documents/icd360sev_schatzmeister

# Flutter analyze (verificare erori)
/c/flutter/bin/flutter analyze

# Flutter build Windows release
/c/flutter/bin/flutter build windows --release

# Flutter pub get (instalare dependențe)
/c/flutter/bin/flutter pub get

# Flutter pub upgrade (actualizare pachete)
/c/flutter/bin/flutter pub upgrade --major-versions
```

**macOS:**
```bash
# Navigare la proiect
cd /Users/ionut-claudiuduinea/Documents/icd360sev_schatzmeister

# Flutter analyze (verificare erori)
/Users/ionut-claudiuduinea/development/flutter/bin/flutter analyze

# Flutter build macOS release
/Users/ionut-claudiuduinea/development/flutter/bin/flutter build macos --release

# Flutter build APK (obfuscated + split-per-abi)
/Users/ionut-claudiuduinea/development/flutter/bin/flutter build apk --release \
  --obfuscate --split-debug-info=build/symbols --split-per-abi

# Flutter run (development mode)
/Users/ionut-claudiuduinea/development/flutter/bin/flutter run -d macos

# Flutter pub get (instalare dependențe)
/Users/ionut-claudiuduinea/development/flutter/bin/flutter pub get

# Flutter pub upgrade (actualizare pachete)
/Users/ionut-claudiuduinea/development/flutter/bin/flutter pub upgrade --major-versions
```

### Build & Upload (PowerShell - pentru user)
```powershell
# Build release (obfuscated + split-per-abi)
cd "c:\Users\icd_U\Documents\icd360sev_schatzmeister"
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat build apk --release --obfuscate --split-debug-info=build\symbols --split-per-abi

# Salvează symbols
mkdir -Force ~\symbols\schatzmeister_vX.X.X
cp -Recurse build\symbols\* ~\symbols\schatzmeister_vX.X.X\

# Upload APK to F-Droid repo (arm64-v8a, ~33MB)
scp -i "$SEV_KEY" -P 36000 "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" icd360sev@icd360sev.icd360s.de:/tmp/de.icd360sev.schatzmeister_Y.apk
# apoi, tot din PowerShell:
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de "sudo -n mv /tmp/de.icd360sev.schatzmeister_Y.apk /var/www/icd360sev.icd360s.de/fdroid/repo/"
```

### ⚠️ Backup Stable Version (ÎNAINTE de upload!)
```bash
# IMPORTANT: Rulează înainte de a uploada o nouă versiune!
# Salvează APK-ul curent ca fallback
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n cp /var/www/icd360sev.icd360s.de/fdroid/repo/icd360sev_schatzmeister.apk \
      /var/www/icd360sev.icd360s.de/fdroid/repo/icd360sev_schatzmeister_stable.apk"
```

### Rollback rapid (dacă noua versiune are probleme)
```bash
# Restaurează versiunea stabilă
ssh -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n cp /var/www/icd360sev.icd360s.de/fdroid/repo/icd360sev_schatzmeister_stable.apk \
      /var/www/icd360sev.icd360s.de/fdroid/repo/icd360sev_schatzmeister.apk"
```

### Paths

**Windows:**
```
c:\Users\icd_U\Documents\icd360sev_schatzmeister\  (Project Root)
│                                      # ⚠️ cheia veche vps_icd360sev_icd360s.de a fost
│                                      # STEARSA din repo (revocata + era publica pe GitHub).
│                                      # Cheia activa se tine IN AFARA repo-ului, vezi $SEV_KEY.
├── lib/                                # Flutter source code
├── windows/                            # Windows native
├── android/                            # Android native
├── installer/                          # Inno Setup installer script
│   └── icd360sev_setup.iss
├── build/windows/x64/runner/Release/   # Windows build output
├── build/symbols/                      # Obfuscation symbols (for crash de-obfuscation)
└── build/app/outputs/flutter-apk/      # Android APK output
    └── app-arm64-v8a-release.apk       # Obfuscated, arm64 only (~33MB)
```

**macOS:**
```
/Users/ionut-claudiuduinea/Documents/icd360sev_schatzmeister/  (Project Root)
│                                      # ⚠️ cheia veche vps_icd360sev_icd360s.de a fost
│                                      # STEARSA din repo (revocata + era publica pe GitHub).
│                                      # Cheia activa se tine IN AFARA repo-ului, vezi $SEV_KEY.
├── lib/                                # Flutter source code
├── macos/                              # macOS native
│   ├── Runner/
│   │   ├── DebugProfile.entitlements  # Camera permission
│   │   └── Release.entitlements       # Camera permission
├── android/                            # Android native
├── build/macos/Build/Products/Release/ # macOS build output
├── build/symbols/                      # Obfuscation symbols
└── build/app/outputs/flutter-apk/      # Android APK output (arm64, obfuscated)
```

Server:
/var/www/icd360sev.icd360s.de/
├── fdroid/repo/                        # Schatzmeister F-Droid repo
│   └── icd360sev_schatzmeister.apk
├── downloads/schatzmeister/            # Schatzmeister downloads
├── api/data/                           # Protected JSON files
│   ├── version_schatzmeister.json      # Version info Schatzmeister (chmod 640, root:nginx)
│   ├── changelog_schatzmeister.json    # Changelog Schatzmeister (chmod 640, root:nginx)
├── api/                                # REST API endpoints
│   ├── config.php
│   ├── helpers.php
│   ├── auth/
│   ├── admin/
│   ├── chat/
│   └── ...
└── websocket/                          # WebSocket server
    ├── server.php                      # Entry point
    └── src/ChatServer.php              # Main logic (chat, presence, calls)
```

### version_schatzmeister.json Format (Current on Server)
```json
{
    "version": "1.0.9",
    "build_number": 10,
    "download_url": "https://icd360sev.icd360s.de/fdroid/repo/icd360sev_schatzmeister.apk",
    "fallback_url": "https://icd360sev.icd360s.de/fdroid/repo/icd360sev_schatzmeister.apk",
    "fallback_version": "1.0.8",
    "changelog": "Version 1.0.9\n\n- Live Chat: Fotos erscheinen sofort nach dem Senden\n- Upload Response-Format korrigiert",
    "min_version": null,
    "force_update": false,
    "release_date": "2026-03-25",
    "file_size": "120 MB"
}
```

---

## Version & Changelog Management

**IMPORTANT:** Atât version info cât și changelog-ul sunt stocate pe server în folder protejat, NU în cod!

### ⚠️ Diferența dintre cele 2 JSON-uri:

| Aspect | version_schatzmeister.json | changelog_schatzmeister.json |
|--------|---------------------------|-------------------------------|
| **Scop** | Trigger update notification în aplicație | Changelog detaliat vizibil în dialog |
| **Accesat de** | UpdateService (automat, la 5 minute) | User manual (click pe "Änderungsprotokoll") |
| **Changelog format** | **SCURT** - 1-2 fraze principale | **DETALIAT** - listă completă modificări per versiune |
| **Exemplu changelog** | `"Version 1.0.9\n\n- Live Chat Fotos fix"` | `["Live Chat: Fotos erscheinen sofort", "Upload Response-Format korrigiert"]` |
| **Câte versiuni?** | Doar versiunea CURENTĂ | **TOATE** versiunile (istoric complet) |
| **Când se actualizează?** | **LA FINAL** (după upload APK) | Înainte de version info |

**Regula de aur:**
1. **changelog_schatzmeister.json** = ce s-a modificat în detaliu (pentru utilizatori curioși)
2. **version_schatzmeister.json** = "există versiune nouă + rezumat scurt" (pentru notificare update)

---

### Version Management (Update Check)

**Fișier Server (PROTECTED):**
```
/var/www/icd360sev.icd360s.de/api/data/version_schatzmeister.json
Permisiuni: chmod 640, root:nginx (doar root write, nginx read)
```

**API Endpoint:**
```
https://icd360sev.icd360s.de/api/version_schatzmeister.php (GET, requires Device Key)
```

**Cum să actualizezi version info:**

1. **Editează fișierul pe server** (SSH):
```bash
ssh -t -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n nano /var/www/icd360sev.icd360s.de/api/data/version_schatzmeister.json"
```

2. **Actualizează informațiile versiunii:**
```json
{
    "version": "1.0.9",
    "build_number": 10,
    "download_url": "https://icd360sev.icd360s.de/fdroid/repo/icd360sev_schatzmeister.apk",
    "fallback_url": "https://icd360sev.icd360s.de/fdroid/repo/icd360sev_schatzmeister.apk",
    "fallback_version": "1.0.8",
    "changelog": "Version 1.0.9\n\n- Live Chat: Fotos erscheinen sofort nach dem Senden",
    "min_version": null,
    "force_update": false,
    "release_date": "2026-03-25",
    "file_size": "120 MB"
}
```

**IMPORTANT:** Changelog-ul aici trebuie să fie SCURT (1-2 fraze principale). Pentru detalii complete, utilizatorul va deschide changelog-ul detaliat din aplicație.

**Fișiere în aplicație:**
- [lib/services/update_service.dart](lib/services/update_service.dart) - `checkForUpdate()` method cu Device Key

**Securitate:**
- ✅ **Protected endpoint:** Doar aplicația instalată poate accesa (Device Key required)
- ✅ **Blochează browsere:** User-Agent verification pe server
- ✅ **Legacy fallback:** Suport pentru versiuni vechi cu Legacy API Key

---

### Changelog Management (Detailed Changelog)

**Fișier Server (PROTECTED):**
```
/var/www/icd360sev.icd360s.de/api/data/changelog_schatzmeister.json
Permisiuni: chmod 640, root:nginx (doar root write, nginx read)
```

**API Endpoint:**
```
https://icd360sev.icd360s.de/api/changelog_schatzmeister.php (GET, requires Device Key)
```

### Cum să adaugi o versiune nouă:

1. **Editează fișierul pe server** (SSH):
```bash
ssh -t -i "$SEV_KEY" -p 36000 icd360sev@icd360sev.icd360s.de \
  "sudo -n nano /var/www/icd360sev.icd360s.de/api/data/changelog_schatzmeister.json"
```

2. **Adaugă noua versiune la ÎNCEPUTUL array-ului `versions`**:
```json
{
  "versions": [
    {
      "version": "1.0.9",
      "date": "25.03.2026",
      "changes": [
        "Live Chat: Fotos erscheinen jetzt sofort nach dem Senden",
        "Bugfix: Server-Response-Format für Upload korrigiert"
      ],
      "is_latest": true
    },
    {
      "version": "1.0.8",
      "date": "25.03.2026",
      "changes": [
        "Mehrsprachig: Vollständige Übersetzung DE + RO",
        "Live Chat: Download-Fehler behoben"
      ],
      "is_latest": false  // IMPORTANT: Setează false pentru versiunea veche!
    },
    ...
  ]
}
```

**IMPORTANT:** Aici poți adăuga cât de multe detalii dorești - utilizatorul va vedea lista completă în dialog.

3. **Actualizează `last_updated`**:
```json
"last_updated": "2026-01-23T20:00:00Z"
```

**Fișiere în aplicație:**
- [lib/services/api_service.dart](lib/services/api_service.dart) - `getChangelog()` method
- [lib/widgets/changelog.dart](lib/widgets/changelog.dart) - Citește changelog prin API protejat
- [lib/widgets/legal_footer.dart](lib/widgets/legal_footer.dart) - Deschide dialog cu changelog

---

### Avantaje Generale (Version + Changelog):
- ✅ **Securitate maximă:** Ambele endpoint-uri protejate cu Device Key (nu public)
- ✅ **Blochează accesul neautorizat:** Browserele nu pot accesa datele
- ✅ **Flexibilitate:** Nu trebuie rebuild pentru actualizări metadata
- ✅ **Consistență:** Toate versiunile aplicației văd aceleași date actualizate
- ✅ **Corectabilitate:** Poți corecta erori fără deployment
- ✅ **Istoric complet:** Changelog disponibil pentru toate versiunile
- ✅ **Fallback sigur:** Legacy API Key pentru compatibilitate cu versiuni vechi

**Last updated:** 2026-04-05 (Schatzmeister Portal v1.0.15+16)

---

## Battery Monitoring & Optimization

### Battery Monitoring
- **Package:** `battery_plus: ^7.0.0`
- **Integrat în:** `lib/services/diagnostic_service.dart`
- Trimite `battery_level` și `battery_state` la fiecare diagnostic report
- Serverul salvează automat în `battery_logs` / `diagnostic_logs`

### Battery Optimization (reducere consum ~15% → ~2-3%/zi)

| Timer | Înainte | Acum | Fișier |
|-------|---------|------|--------|
| Heartbeat | 15s | 60s | `heartbeat_service.dart` |
| Diagnostic | 15s | 120s | `diagnostic_service.dart` |
| Ticket polling | 10s | 60s | `ticket_notification_service.dart` |
| Network ping | fiecare request | cache 5min | `network_info_service.dart` |

**WidgetsBindingObserver** pe `dashboard_screen.dart`:
- App paused (background) → oprește UI timere (ticket refresh, payment reminder)
- App resumed (foreground) → repornește timere + refresh date
- NU oprește: WebSocket, ntfy, heartbeat, log upload (trebuie să funcționeze în background)

### Obfuscation & Split-per-ABI

**Build command:**
```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols --split-per-abi
```

| Aspect | Înainte | Acum |
|--------|---------|------|
| APK size | ~120 MB (universal) | ~33 MB (arm64-v8a) |
| Cod Dart | Lizibil | Obfuscat |
| Symbols | Nu | `build/symbols/` (salvate per versiune) |

**De-obfuscate crash reports:**
```bash
flutter symbolize -i crash_log.txt -d ~/symbols/schatzmeister_vX.X.X/
```

**F-Droid naming:** `de.icd360sev.schatzmeister_{versionCode}.apk`

---

## Certificate Pinning (ISRG Root X1 / Let's Encrypt)

**Implementat în:** `lib/services/http_client_factory.dart`

- Acceptă DOAR certificate semnate de Let's Encrypt (ISRG Root X1)
- Protejează contra MITM attacks (certificate false pe WiFi public)
- Pinning activ MEREU (debug + release)
- ISRG Root X1 valid până 2035, zero mentenanță la cert renewal (certbot auto-renew la 90 zile)

**Integrat în:**
| Serviciu | Fișier | Conexiune |
|----------|--------|-----------|
| REST API | `api_service.dart` | `IOClient(HttpClientFactory.createPinnedHttpClient())` |
| WebSocket | `chat_service.dart` | `WebSocket.connect(url, customClient: pinnedClient)` |
| ntfy stream | `ntfy_service.dart` | `IOClient(HttpClientFactory.createPinnedHttpClient())` |

---

## ntfy Push Notifications (Self-Hosted, fără Google/FCM)

**Server:** ntfy activ pe port 2586, proxied prin nginx la `/ntfy/`
**Auth:** `icd360s_admin / ICD360sNtfy2026!` (role: admin)
**Config:** `/etc/ntfy/server.yml`, `auth-default-access: deny-all`

### Topic-uri per portal (separate, nu se amestecă):
| Portal | Prefix | Exemplu topic | Service PHP |
|--------|--------|---------------|-------------|
| Schatzmeister | `schatzmeister_` | `schatzmeister_s00001` | `NtfySchatzmeisterService.php` |
| Mitglieder | `icd360s_` | `icd360s_m00001` | `NtfyService.php` |
| Vorsitzer | `vorsitzer_` | `vorsitzer_v00001` | `NtfyVorsitzerService.php` |

### Permisiuni ntfy:
- Anonymous (`*`) are **read-only** pe `schatzmeister_*`, `icd360s_*`, `vorsitzer_*`
- Admin (`icd360s_admin`) are **read-write** pe toate topicele

### Flux notificări chat:
1. Vorsitzer trimite mesaj → `chat/send.php`
2. `send.php` verifică rolul destinatarului
3. Destinatar schatzmeister → `NtfySchatzmeisterService::notifyNewMessage()` → topic `schatzmeister_s00001`
4. App Schatzmeister ascultă pe `https://icd360sev.icd360s.de/ntfy/schatzmeister_s00001/json` (NDJSON stream)
5. Primește mesaj → afișează notificare locală (flutter_local_notifications)

### Fișiere:
- **Server:** `/api/helpers/NtfySchatzmeisterService.php` — trimite notificări
- **Server:** `/api/chat/send.php` — routing per rol (NtfyService / NtfySchatzmeisterService)
- **App:** `lib/services/ntfy_service.dart` — subscribe pe topic, JSON stream, auto-reconnect 5s
- **App:** `lib/screens/dashboard_screen.dart` — `NtfyService().start()` / `.stop()`

---

## Schatzmeister API Endpoints (`/api/schatzmeister/`)

Endpoint-uri dedicate cu `$adminRoles = ["schatzmeister"]` (separate de `/api/admin/` care au role vorsitzer).

**31 fișiere PHP** copiate din `/api/admin/` cu rolul schimbat:
- `archiv_list.php`, `archiv_upload.php`, `archiv_download.php`, `archiv_delete.php`
- `befreiung_list.php`, `befreiung_upload.php`, `befreiung_update.php`, `befreiung_delete.php`, `befreiung_download.php`
- `ermaessigung_list.php`, `ermaessigung_update.php`, `ermaessigung_delete.php`, `ermaessigung_download.php`, `ermaessigung_poll.php`, `ermaessigung_remind.php`
- `dokumente_list.php`, `dokumente_upload.php`, `dokumente_download.php`, `dokumente_delete.php`
- `verwarnungen_list.php`, `verwarnungen_create.php`, `verwarnungen_delete.php`
- `routine_list.php`, `routine_create.php`, `routine_update.php`, `routine_delete.php`, `routine_executions.php`
- `notizen_list.php`, `notizen_create.php`, `notizen_delete.php`
- `admin_register.php`

**Aplicația folosește `/api/schatzmeister/` în:**
- `lib/services/api_service.dart` — archiv, befreiung, ermaessigung, notizen, admin_register
- `lib/services/dokumente_service.dart` — dokumente_upload/list/delete/download
- `lib/services/verwarnung_service.dart` — verwarnungen_create/list/delete
- `lib/services/routine_service.dart` — routine_list/create/update/delete/executions
- `lib/services/ticket_notification_service.dart` — ermaessigung_poll

**Endpoint-uri care rămân pe `/api/admin/` (funcționează fără role check):**
user_status, user_delete, user_details, user_update, session_revoke, vereineinstellungen, finanzamt/*, finanzverwaltung/*, status_message, verifizierung_*, termine_*, urlaub_*, feiertage_list

---

## Recent Changes & Updates

### v1.0.15+16 (Current - 05.04.2026)
**Sicherheit & Live Chat:**
- ✅ **ntfy Token-Authentifizierung** - Anonymous access geblockt, Token vom Server geholt (nicht hardcoded)
- ✅ **ntfy Auto-Token-Refresh** - Bei 401/403 automatisch neuer Token + Reconnect
- ✅ **Live Chat: Klickbare Links** - URLs in Nachrichten öffnen sich im Browser

### v1.0.14+15 (04.04.2026)
**Bugfix:**
- ✅ **Update-Erkennung** - version_schatzmeister.json wurde nicht aktualisiert

### v1.0.13+14 (04.04.2026)
**Package-Upgrades & File-Viewer:**
- ✅ **battery_plus** - 6.x → 7.x (aktuellere Battery-API)
- ✅ **connectivity_plus** - 6.x → 7.x (aktuellere Netzwerk-API)
- ✅ **system_tray → tray_manager** - Migration auf aktiv gepflegtes Package (leanflutter.dev, gleicher Publisher wie window_manager)
- ✅ **local_notifier** - Komplett entfernt (flutter_local_notifications deckt alle Plattformen ab)
- ✅ **Interner File-Viewer** - PDF und Bilder direkt in der App öffnen (Zoom, Navigation, Drucken, Speichern)
- ✅ **pdfrx** - PDF-Rendering integriert (kein externes Programm nötig)

### v1.0.12+13 (03.04.2026)
**Datenschutz & Diagnostics:**
- ✅ **Finanzverwaltung** - Beitragszahlungen zeigt nur Mitgliedernummer (kein Name)
- ✅ **Diagnostics** - Mitgliedernummer korrekt gesetzt (nicht mehr 'unknown' auf Server)
- ✅ **Battery Diagnostics** - Level + State werden korrekt mit Benutzer verknüpft

### v1.0.11+12 (03.04.2026)
**Batterie & Sicherheit:**
- ✅ **Battery Monitoring** - battery_plus integriert (Level + State in Diagnostics)
- ✅ **Timer-Optimierung** - Heartbeat 60s, Diagnostic 120s, Tickets 60s (statt 15s/15s/10s)
- ✅ **WidgetsBindingObserver** - UI-Timer stoppen im Hintergrund
- ✅ **Netzwerk-Ping Cache** - 5 Minuten statt bei jedem Request
- ✅ **APK Obfuscation** - Dart-Code nicht mehr lesbar
- ✅ **Split-per-ABI** - 42 MB statt 120 MB (nur arm64-v8a)

### v1.0.10+11 (03.04.2026)
**Sicherheit & Push-Benachrichtigungen:**
- ✅ **Certificate Pinning** - ISRG Root X1 / Let's Encrypt für alle Verbindungen (API, WebSocket, ntfy)
- ✅ **Eigene API-Endpoints** - /api/schatzmeister/ (31 Dateien, unabhängig von Admin-Rolle)
- ✅ **ntfy Push** - Self-hosted (kein Google/FCM), Topic-Prefix schatzmeister_
- ✅ **Chat Notifications** - Vorsitzer-Nachrichten lösen Push-Benachrichtigung aus
- ✅ **Easter-Theme** - Saisonale Dekorationen im April (paintBehind für Chat)
- ✅ **Bugfix Live Chat** - AppLocalizations in didChangeDependencies, setState nach dispose

### v1.0.9+10 (25.03.2026)
**Bugfix:**
- ✅ **Live Chat Upload** - Fotos erscheinen jetzt sofort nach dem Senden (nicht erst nach erneutem Öffnen)
- ✅ **Upload Response** - Server-Response-Format korrigiert (`result['message_id']` statt `result['data']['message_id']`)

**Technical Changes:**
- `live_chat_dialog.dart`: Upload-Response direkt aus root statt aus `result['data']`
- Version: 1.0.9+10

### v1.0.8+9 (25.03.2026)
**Mehrsprachig:**
- ✅ **Vollständige Übersetzung DE + RO** - Automatische Spracherkennung basierend auf Gerätesprache
- ✅ **500+ übersetzte Texte** - Alle Bildschirme, Dialoge, Fehlermeldungen, Benachrichtigungen
- ✅ **app_localizations.dart** - ~1430 Zeilen mit `_t('Deutsch', 'Română')` Pattern

**Bugfix:**
- ✅ **Live Chat Download** - Server-Response-Format korrigiert (`result['content']` statt `result['data']['content']`)

**Technical Changes:**
- `lib/l10n/app_localizations.dart`: ~500 neue Lokalisierungsschlüssel (DE + RO)
- Alle Screens und Widgets importieren und verwenden `AppLocalizations.of(context)`
- `live_chat_dialog.dart`: Download-Keys direkt aus result statt result['data']
- Version: 1.0.8+9

### v1.0.7+8 (24.03.2026)
**Bugfix:**
- ✅ **Live Chat Download** - Anhänge (Fotos, Dateien) können jetzt heruntergeladen werden (falscher JSON-Schlüssel korrigiert: `content` statt `file_data`)

**Technical Changes:**
- `live_chat_dialog.dart`: Download-Schlüssel von `file_data` auf `content` geändert (passend zum Server-Response)
- Version: 1.0.7+8

### v1.0.6+7 (24.03.2026)
**Live Chat:**
- ✅ **Kamera-Button** - Dokumente direkt fotografieren im Live Chat (neben Datei-Anhang)

**Terminverwaltung:**
- ✅ **Server-Fix** - SQL-Fehler in `my_termine.php` behoben (fehlende Anführungszeichen bei String-Werten)
- ✅ **Termine werden jetzt korrekt angezeigt** - Schatzmeister sieht alle eigenen Termine

**Technical Changes:**
- `image_picker` für Kamera-Integration im Live Chat
- Server: `my_termine.php` SQL prepared statements korrigiert
- Version: 1.0.6+7

### v1.0.5+6 (23.03.2026)
**Terminverwaltung:**
- ✅ **Nur eigene Termine** - Schatzmeister sieht nur Termine wo er Teilnehmer ist (nicht alle Admin-Termine)
- ✅ **Auto-Refresh** - Termine werden alle 30 Sekunden automatisch aktualisiert
- ✅ **Nur-Lesen-Ansicht** - Admin-Buttons entfernt (Neuer Termin, Urlaub erstellen, Bearbeiten)

**Technical Changes:**
- Server: `my_termine.php` unterstützt jetzt `from/to` Datumsbereich-Filter
- Android: `allowBackup=true` + `hasFragileUserData=true` (Daten bleiben bei Deinstallation)
- APK mit Release-Signatur (CN=ICD360S e.V. Schatzmeister)
- Version: 1.0.5+6

### v1.0.4+5 (22.03.2026)
**Chat & Benachrichtigungen:**
- ✅ **Eigene Konversationen** - Schatzmeister sieht nur eigene Chat-Konversationen
- ✅ **System-Notifications ignoriert** - Keine Benachrichtigungen von Admin-an-Mitglieder Nachrichten
- ✅ **Ticket-Notifications** - Eigene Aktionen werden nicht als Notification angezeigt

### v1.0.3+4 (20.03.2026)
**UI & Mobile:**
- ✅ **Footer entfernt** - LegalFooter aus Login und Dashboard entfernt
- ✅ **Doppeltes Menü entfernt** - Sidebar + Bottom Nav war redundant
- ✅ **Mobile Login** - Formular direkt sichtbar (kein Card-Wrapper)
- ✅ **Mobile Dashboard** - Responsive GridView Karten, scrollbare Tabs

**Technical Changes:**
- Logger: Automatischer Log-Upload zum Server (30s Intervall)
- Batterie: Battery Optimization Exemption für Android

### v1.0.2+3 (18.03.2026)
**Bug Fixes:**
- ✅ **Chat-Benachrichtigungen** - Nachrichten vom Vorsitzer werden jetzt angezeigt (isAdmin-Filter entfernt)
- ✅ **Android 13+ Notifications** - Runtime-Berechtigung POST_NOTIFICATIONS wird automatisch angefordert
- ✅ **Akku-Optimierung** - App fordert Battery Optimization Exemption an (WebSocket bleibt im Hintergrund aktiv)

**UI Changes:**
- ✅ **Bottom Navigation entfernt** - Kein doppeltes Menü mehr (Sidebar + Bottom Nav war redundant)

### v1.0.1+2 (11.03.2026)
**New Features:**
- ✅ **Terminverwaltung** - 3-Tab Ansicht (Kommende/Aktuelle/Erledigt)
- ✅ **Ticketverwaltung** - 5-Tab Ansicht (Aktuell/Alle/Aktive/In Bearbeitung/Erledigt)
- ✅ **F-Droid Repository** - APK verfügbar unter https://icd360sev.icd360s.de/fdroid/repo

### v1.0.0+1 (Initial - 11.03.2026)
- Initial Schatzmeister Portal (duplicated from Vorsitzer)
- Finanzverwaltung: Beitragszahlung, Banktransaktionen, Spenden
- Live Chat, Ticketverwaltung, Terminverwaltung
- Benutzerverwaltung, Vereinverwaltung

---
