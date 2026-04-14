import 'package:flutter/material.dart';

/// Custom localization class for DE (German) and RO (Romanian)
/// Usage: AppLocalizations.of(context).someKey
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String _t(String deText, String roText) {
    return locale.languageCode == 'ro' ? roText : deText;
  }

  // ============================================================
  // APP GENERAL
  // ============================================================
  String get appTitle => _t('ICD360S e.V - Schatzmeister Portal', 'ICD360S e.V - Portal Trezorier');
  String get appName => 'ICD360S e.V';
  String get portalName => _t('Schatzmeister Portal', 'Portal Trezorier');
  String get appInBackground => _t('App im Hintergrund', 'Aplicație în fundal');
  String get appRunningInBackground => _t(
    'ICD360S e.V läuft weiter im Hintergrund. Klicken Sie auf das Tray-Icon zum Öffnen.',
    'ICD360S e.V rulează în fundal. Faceți clic pe pictograma din tray pentru a deschide.',
  );
  String get allRightsReserved => _t('Alle Rechte vorbehalten.', 'Toate drepturile rezervate.');
  String copyrightText(int year) => '© 2025 - $year ICD360S e.V. $allRightsReserved';

  // ============================================================
  // LOGIN SCREEN
  // ============================================================
  String get login => _t('Anmelden', 'Autentificare');
  String get autoLogin => _t('Automatische Anmeldung...', 'Autentificare automată...');
  String get userNumber => _t('Benutzernummer', 'Număr utilizator');
  String get pleaseEnterUserNumber => _t('Bitte Benutzernummer eingeben', 'Vă rugăm introduceți numărul de utilizator');
  String get password => _t('Passwort', 'Parolă');
  String get pleaseEnterPassword => _t('Bitte Passwort eingeben', 'Vă rugăm introduceți parola');
  String get saveCredentials => _t('Anmeldedaten speichern', 'Salvează datele de autentificare');
  String get autoLoginCheckbox => _t('Automatisch anmelden', 'Autentificare automată');
  String get startWithWindows => _t('Mit Windows starten', 'Pornire cu Windows');
  String get startWithWindowsTooltip => _t('App startet automatisch beim Windows-Login', 'Aplicația pornește automat la autentificarea Windows');
  String get forgotPassword => _t('Passwort vergessen?', 'Ați uitat parola?');
  String get loginFailed => _t('Anmeldung fehlgeschlagen', 'Autentificare eșuată');
  String get connectionError => _t('Verbindungsfehler', 'Eroare de conexiune');
  String tooManyAttempts(String remaining) => _t(
    'Zu viele Anmeldeversuche. Bitte warten Sie $remaining Minuten.',
    'Prea multe încercări de autentificare. Vă rugăm așteptați $remaining minute.',
  );
  String get accountTempLocked => _t(
    'Account temporär gesperrt für 5 Minuten nach zu vielen Versuchen.',
    'Cont blocat temporar pentru 5 minute după prea multe încercări.',
  );

  // ============================================================
  // DEVICE MANAGEMENT
  // ============================================================
  String get tooManyDevices => _t('Zu viele Geräte', 'Prea multe dispozitive');
  String get alreadyLoggedOn3Devices => _t(
    'Sie sind bereits auf 3 Geräten angemeldet.\nWählen Sie ein Gerät zum Abmelden:',
    'Sunteți deja autentificat pe 3 dispozitive.\nSelectați un dispozitiv pentru deconectare:',
  );
  String get unknownDevice => _t('Unbekanntes Gerät', 'Dispozitiv necunoscut');
  String get unknown => _t('Unbekannt', 'Necunoscut');
  String get cancel => _t('Abbrechen', 'Anulare');
  String get logoutError => _t('Fehler beim Abmelden', 'Eroare la deconectare');

  // ============================================================
  // BRANDING PANEL (Login Left Side)
  // ============================================================
  String get memberManagement => _t('Mitgliederverwaltung', 'Administrarea membrilor');
  String get appointmentManagement => _t('Terminverwaltung', 'Administrarea programărilor');
  String get ticketManagement => _t('Ticketverwaltung', 'Administrarea tichetelor');
  String get organizationManagement => _t('Vereinverwaltung', 'Administrarea asociației');

  // ============================================================
  // DASHBOARD SIDEBAR
  // ============================================================
  String get dashboard => 'Dashboard';
  String get financialManagement => _t('Finanzverwaltung', 'Administrare financiară');
  String get myTickets => _t('Meine Tickets', 'Tichetele mele');
  String get myAppointments => _t('Meine Termine', 'Programările mele');

  // ============================================================
  // DASHBOARD SCREEN
  // ============================================================
  String weatherIn(String city) => _t('Wetter in $city', 'Vremea în $city');
  String get noWeatherAlerts => _t('Keine DWD Warnungen aktiv', 'Nicio alertă DWD activă');
  String get noHourlyData => _t('Keine stündlichen Daten verfügbar', 'Nu sunt disponibile date orare');
  String get noForecast => _t('Keine Vorhersage verfügbar', 'Nu este disponibilă prognoza');
  String get logout => _t('Abmelden', 'Deconectare');
  String get logoutConfirm => _t('Möchten Sie sich abmelden?', 'Doriți să vă deconectați?');
  String get confirm => _t('Bestätigen', 'Confirmare');
  String get profile => _t('Profil', 'Profil');
  String get liveChat => 'Live Chat';
  String get supportInCall => _t('Der Support ist bereits in einem anderen Anruf', 'Suportul este deja într-un alt apel');
  String get chatStartError => _t('Fehler beim Starten des Chats', 'Eroare la pornirea chat-ului');

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================
  String get forgotPasswordTitle => _t('Passwort vergessen', 'Parolă uitată');
  String get forgotPasswordDesc => _t(
    'Geben Sie Ihre Benutzernummer und den Wiederherstellungscode ein, den Sie bei der Registrierung erstellt haben.',
    'Introduceți numărul de utilizator și codul de recuperare pe care l-ați creat la înregistrare.',
  );
  String get recoveryCode => _t('Wiederherstellungscode (6 Ziffern)', 'Cod de recuperare (6 cifre)');
  String get pleaseEnterRecoveryCode => _t('Bitte Wiederherstellungscode eingeben', 'Vă rugăm introduceți codul de recuperare');
  String get codeMust6Digits => _t('Code muss genau 6 Ziffern haben', 'Codul trebuie să aibă exact 6 cifre');
  String get newPassword => _t('Neues Passwort', 'Parolă nouă');
  String get pleaseEnterNewPassword => _t('Bitte neues Passwort eingeben', 'Vă rugăm introduceți parola nouă');
  String get passwordMin6Chars => _t('Passwort muss mindestens 6 Zeichen haben', 'Parola trebuie să aibă cel puțin 6 caractere');
  String get confirmPassword => _t('Passwort bestätigen', 'Confirmați parola');
  String get pleaseConfirmPassword => _t('Bitte Passwort bestätigen', 'Vă rugăm confirmați parola');
  String get passwordsDoNotMatch => _t('Passwörter stimmen nicht überein', 'Parolele nu se potrivesc');
  String get passwordResetSuccess => _t(
    'Passwort erfolgreich zurückgesetzt!\n\nSie können sich jetzt mit Ihrem neuen Passwort anmelden.',
    'Parola a fost resetată cu succes!\n\nVă puteți autentifica acum cu noua parolă.',
  );
  String get passwordResetFailed => _t('Passwort-Zurücksetzung fehlgeschlagen', 'Resetarea parolei a eșuat');

  // ============================================================
  // DIAGNOSTIC CONSENT
  // ============================================================
  String get diagnosticData => _t('Diagnose-Daten', 'Date de diagnostic');
  String get diagnosticQuestion => _t('Möchten Sie uns helfen, die App zu verbessern?', 'Doriți să ne ajutați să îmbunătățim aplicația?');
  String get anonymousStats => _t('Anonyme Nutzungsstatistiken', 'Statistici anonime de utilizare');
  String get errorReports => _t('Fehlermeldungen zur Verbesserung', 'Rapoarte de erori pentru îmbunătățire');
  String get performanceData => _t('App-Performance-Daten', 'Date de performanță a aplicației');
  String get noPersonalData => _t(
    'Keine persönlichen Daten werden gesammelt. Diese Einstellung kann jederzeit geändert werden.',
    'Nu se colectează date personale. Această setare poate fi modificată oricând.',
  );
  String get noThanks => _t('Nein, danke', 'Nu, mulțumesc');
  String get yesEnable => _t('Ja, aktivieren', 'Da, activează');

  // ============================================================
  // UPDATE DIALOG
  // ============================================================
  String get updateAvailable => _t('Update verfügbar', 'Actualizare disponibilă');
  String newVersionAvailable(String version) => _t(
    'Eine neue Version ist verfügbar: $version',
    'O nouă versiune este disponibilă: $version',
  );
  String currentVersionLabel(String version) => _t(
    'Aktuelle Version: $version',
    'Versiunea curentă: $version',
  );
  String get changes => _t('Änderungen:', 'Modificări:');
  String downloadProgress(String percent) => _t('Download: $percent%', 'Descărcare: $percent%');
  String get installationStarting => _t('Installation wird gestartet...', 'Instalarea începe...');
  String get appWillRestart => _t('Die Anwendung wird automatisch neu gestartet.', 'Aplicația va fi repornită automat.');
  String get later => _t('Später', 'Mai târziu');
  String get updateNow => _t('Jetzt aktualisieren', 'Actualizează acum');
  String get downloading => _t('Wird heruntergeladen...', 'Se descarcă...');
  String get downloadFailed => _t(
    'Download fehlgeschlagen. Bitte versuchen Sie es später erneut.',
    'Descărcarea a eșuat. Vă rugăm încercați din nou mai târziu.',
  );

  // ============================================================
  // LEGAL FOOTER
  // ============================================================
  String get searchingUpdates => _t('Suche nach Updates...', 'Se caută actualizări...');
  String get appUpToDate => _t('Die App ist auf dem neuesten Stand', 'Aplicația este la zi');
  String get updateCheckError => _t('Fehler bei der Update-Prüfung', 'Eroare la verificarea actualizării');
  String get imprint => _t('Impressum', 'Imprint');
  String get privacy => _t('Datenschutz', 'Confidențialitate');
  String get withdrawal => _t('Widerrufsrecht', 'Drept de retragere');
  String get cancellation => _t('Kündigung', 'Reziliere');
  String get statute => _t('Satzung', 'Statut');
  String get checkForUpdates => _t('Nach Updates suchen', 'Caută actualizări');

  // ============================================================
  // CONFIRM DIALOGS
  // ============================================================
  String get active => _t('Aktiv', 'Activ');
  String get suspended => _t('Gesperrt', 'Suspendat');
  String get terminated => _t('Gekündigt', 'Reziliat');
  String get changeStatus => _t('Status ändern', 'Schimbă status');
  String changeStatusConfirm(String name, String status) => _t(
    'Möchten Sie den Status von "$name" auf "$status" ändern?',
    'Doriți să schimbați statusul lui "$name" în "$status"?',
  );
  String get deleteUser => _t('Benutzer löschen', 'Șterge utilizator');
  String deleteUserConfirm(String name, String number) => _t(
    'Möchten Sie "$name" ($number) wirklich löschen?\n\nDiese Aktion kann nicht rückgängig gemacht werden!',
    'Doriți cu adevărat să ștergeți "$name" ($number)?\n\nAceastă acțiune nu poate fi anulată!',
  );
  String get delete => _t('Löschen', 'Șterge');

  // ============================================================
  // INCOMING CALL
  // ============================================================
  String get incomingCall => _t('Eingehender Anruf', 'Apel primit');
  String ringingFor(int seconds) => _t('Klingelt seit ${seconds}s', 'Sună de ${seconds}s');
  String get decline => _t('Ablehnen', 'Respinge');
  String get accept => _t('Annehmen', 'Acceptă');
  String get speakerOff => _t('Lautsprecher aus', 'Difuzor oprit');
  String get speakerOn => _t('Lautsprecher an', 'Difuzor pornit');
  String get unmute => _t('Stummschaltung aufheben', 'Activează microfonul');
  String get mute => _t('Stummschalten', 'Dezactivează microfonul');
  String get hangUp => _t('Auflegen', 'Închide');
  String get connectionExcellent => _t('Verbindung: Ausgezeichnet', 'Conexiune: Excelentă');
  String get connectionConnecting => _t('Verbindung: Wird hergestellt...', 'Conexiune: Se conectează...');
  String get connectionDisconnected => _t('Verbindung: Getrennt', 'Conexiune: Deconectat');
  String get connectionFailed => _t('Verbindung: Fehlgeschlagen', 'Conexiune: Eșuată');
  String get connectionUnknown => _t('Verbindung: Unbekannt', 'Conexiune: Necunoscută');
  String get calling => _t('Anrufen...', 'Se apelează...');

  // ============================================================
  // NOTIFICATIONS
  // ============================================================
  String get notificationChannelName => _t('ICD360S e.V Benachrichtigungen', 'ICD360S e.V Notificări');
  String get notificationChannelDesc => _t(
    'Benachrichtigungen für Chat, Anrufe und Updates',
    'Notificări pentru chat, apeluri și actualizări',
  );
  String get open => _t('Öffnen', 'Deschide');

  // ============================================================
  // FINANZVERWALTUNG
  // ============================================================
  String get financialAdmin => _t('Finanzverwaltung', 'Administrare financiară');
  String get january => _t('Januar', 'Ianuarie');
  String get february => _t('Februar', 'Februarie');
  String get march => _t('März', 'Martie');
  String get april => _t('April', 'Aprilie');
  String get may => _t('Mai', 'Mai');
  String get june => _t('Juni', 'Iunie');
  String get july => _t('Juli', 'Iulie');
  String get august => _t('August', 'August');
  String get september => _t('September', 'Septembrie');
  String get october => _t('Oktober', 'Octombrie');
  String get november => _t('November', 'Noiembrie');
  String get december => _t('Dezember', 'Decembrie');

  List<String> get months => [january, february, march, april, may, june, july, august, september, october, november, december];

  // ============================================================
  // COMMON
  // ============================================================
  String get save => _t('Speichern', 'Salvează');
  String get close => _t('Schließen', 'Închide');
  String get edit => _t('Bearbeiten', 'Editează');
  String get back => _t('Zurück', 'Înapoi');
  String get next => _t('Weiter', 'Continuă');
  String get yes => _t('Ja', 'Da');
  String get no => _t('Nein', 'Nu');
  String get ok => 'OK';
  String get error => _t('Fehler', 'Eroare');
  String get success => _t('Erfolg', 'Succes');
  String get loading => _t('Laden...', 'Se încarcă...');
  String get noData => _t('Keine Daten vorhanden', 'Nu există date');
  String get search => _t('Suchen', 'Caută');
  String get filter => _t('Filtern', 'Filtrează');
  String get refresh => _t('Aktualisieren', 'Actualizează');
  String get settings => _t('Einstellungen', 'Setări');
  String get help => _t('Hilfe', 'Ajutor');
  String get send => _t('Senden', 'Trimite');
  String get reset => _t('Zurücksetzen', 'Resetează');
  String get create => _t('Erstellen', 'Creează');
  String get add => _t('Hinzufügen', 'Adaugă');
  String get remove => _t('Entfernen', 'Elimină');
  String get details => _t('Details', 'Detalii');
  String get description => _t('Beschreibung', 'Descriere');
  String get date => _t('Datum', 'Data');
  String get time => _t('Uhrzeit', 'Ora');
  String get status => 'Status';
  String get type => _t('Typ', 'Tip');
  String get name => _t('Name', 'Nume');
  String get email => 'E-Mail';
  String get phone => _t('Telefon', 'Telefon');
  String get address => _t('Adresse', 'Adresă');
  String get note => _t('Notiz', 'Notă');
  String get notes => _t('Notizen', 'Note');
  String get amount => _t('Betrag', 'Sumă');
  String get total => _t('Gesamt', 'Total');
  String get paid => _t('Bezahlt', 'Plătit');
  String get unpaid => _t('Unbezahlt', 'Neplătit');
  String get pending => _t('Ausstehend', 'În așteptare');
  String get completed => _t('Erledigt', 'Finalizat');
  String get inProgress => _t('In Bearbeitung', 'În lucru');
  String get all => _t('Alle', 'Toate');
  String get current => _t('Aktuell', 'Curent');
  String get upcoming => _t('Kommende', 'Viitoare');
  String get today => _t('Heute', 'Astăzi');
  String get yesterday => _t('Gestern', 'Ieri');
  String get tomorrow => _t('Morgen', 'Mâine');
  String get week => _t('Woche', 'Săptămână');
  String get month => _t('Monat', 'Lună');
  String get year => _t('Jahr', 'An');
  String get from => _t('Von', 'De la');
  String get to => _t('Bis', 'Până la');
  String get at => _t('um', 'la');
  String get on => _t('am', 'pe');
  String get with_ => _t('mit', 'cu');
  String get without => _t('ohne', 'fără');
  String get selected => _t('Ausgewählt', 'Selectat');
  String get none => _t('Keine', 'Niciuna');
  String get actions => _t('Aktionen', 'Acțiuni');
  String get upload => _t('Hochladen', 'Încarcă');
  String get download => _t('Herunterladen', 'Descarcă');
  String get file => _t('Datei', 'Fișier');
  String get files => _t('Dateien', 'Fișiere');
  String get attachment => _t('Anhang', 'Atașament');
  String get attachments => _t('Anhänge', 'Atașamente');
  String get message => _t('Nachricht', 'Mesaj');
  String get messages => _t('Nachrichten', 'Mesaje');
  String get comment => _t('Kommentar', 'Comentariu');
  String get comments => _t('Kommentare', 'Comentarii');
  String get reply => _t('Antworten', 'Răspunde');
  String get subject => _t('Betreff', 'Subiect');
  String get priority => _t('Priorität', 'Prioritate');
  String get high => _t('Hoch', 'Ridicată');
  String get medium => _t('Mittel', 'Medie');
  String get low => _t('Niedrig', 'Scăzută');
  String get title => _t('Titel', 'Titlu');

  // ============================================================
  // DASHBOARD - WEATHER
  // ============================================================
  String get temperature => _t('Temperatur', 'Temperatură');
  String get wind => 'Wind';
  String get humidity => _t('Feuchtigkeit', 'Umiditate');
  String get hourly => _t('Stündlich', 'Pe oră');
  String get noWeatherData => _t('Keine stündlichen Daten verfügbar', 'Nu sunt disponibile date orare');
  String get weatherDataSource => _t('Daten: Open-Meteo • Warnungen: DWD via Bright Sky', 'Date: Open-Meteo • Avertizări: DWD via Bright Sky');
  String get todayShort => _t('Heu.', 'Azi');

  // ============================================================
  // DASHBOARD - WELCOME & NAV
  // ============================================================
  String welcome(String name) => _t('Willkommen, $name', 'Bine ați venit, $name');
  String get menu => _t('Menü', 'Meniu');
  String get myProfile => _t('Mein Profil', 'Profilul meu');
  String get finances => _t('Finanzen', 'Finanțe');
  String get association => _t('Verein', 'Asociație');

  // ============================================================
  // DASHBOARD - FINANCE OVERVIEW
  // ============================================================
  String get financialOverview => _t('Finanzübersicht', 'Prezentare financiară');
  String get accountBalance => _t('Kontostand', 'Sold cont');
  String get income => _t('Einnahmen', 'Venituri');
  String get expenses => _t('Ausgaben', 'Cheltuieli');
  String get openContributions => _t('Offene Beiträge', 'Contribuții restante');
  String get membershipFees => _t('Mitgliedsbeiträge', 'Cotizații membri');
  String get overdue => _t('Überfällig', 'Întârziate');
  String get reminders => _t('Mahnungen', 'Somații');

  // ============================================================
  // DASHBOARD - TICKETS
  // ============================================================
  String get statusOpen => _t('Offen', 'Deschis');
  String get statusClosed => _t('Geschlossen', 'Închis');
  String get waitingForReply => _t('Warten auf Antwort', 'Așteptare răspuns');
  String get waitingForAuthority => _t('Warten auf Behörde', 'Așteptare autoritate');
  String get noTicketsThisWeek => _t('Keine Tickets diese Woche', 'Niciun tichet săptămâna aceasta');
  String get noTicketsAvailable => _t('Keine Tickets vorhanden', 'Nu există tichete');
  String get noActiveTickets => _t('Keine aktiven Tickets', 'Niciun tichet activ');
  String get noTicketsInProgress => _t('Keine Tickets in Bearbeitung', 'Niciun tichet în lucru');
  String get noCompletedTickets => _t('Keine erledigten Tickets', 'Niciun tichet finalizat');
  String get thisWeek => _t('Diese Woche', 'Săptămâna aceasta');
  String get nextWeek => _t('Nächste Woche', 'Săptămâna viitoare');
  String get lastWeek => _t('Letzte Woche', 'Săptămâna trecută');
  String currentTab(int count) => _t('Aktuell ($count)', 'Curent ($count)');
  String allTab(int count) => _t('Alle ($count)', 'Toate ($count)');
  String activeTab(int count) => _t('Aktive ($count)', 'Active ($count)');
  String inProgressTab(int count) => _t('In Bearbeitung ($count)', 'În lucru ($count)');
  String completedTab(int count) => _t('Erledigt ($count)', 'Finalizat ($count)');

  // ============================================================
  // DASHBOARD - TERMINE
  // ============================================================
  String get noUpcomingAppointments => _t('Keine kommenden Termine', 'Nicio programare viitoare');
  String get noCurrentAppointments => _t('Keine aktuellen Termine', 'Nicio programare curentă');
  String get noCompletedAppointments => _t('Keine erledigten Termine', 'Nicio programare finalizată');
  String upcomingTab(int count) => _t('Kommende ($count)', 'Viitoare ($count)');
  String currentAppTab(int count) => _t('Aktuelle ($count)', 'Curente ($count)');
  String completedAppTab(int count) => _t('Erledigt ($count)', 'Finalizate ($count)');
  String get withoutTitle => _t('Ohne Titel', 'Fără titlu');

  // ============================================================
  // PAYMENT REMINDER
  // ============================================================
  String get paymentReminder => _t('Zahlungserinnerung', 'Memento de plată');
  String get transfer => _t('Überweisung', 'Transfer bancar');
  String get cash => _t('Barzahlung', 'Plata în numerar');
  String get standingOrder => _t('Dauerauftrag', 'Ordin permanent');

  // ============================================================
  // LOGOUT
  // ============================================================
  String get logoutQuestion => _t('Möchten Sie sich abmelden?', 'Doriți să vă deconectați?');

  // ============================================================
  // REGISTER TAB
  // ============================================================
  String get register => _t('Registrieren', 'Înregistrare');
  String get firstAndLastName => _t('Vorname und Nachname', 'Prenume și Nume de familie');
  String get pleaseEnterFirstAndLastName => _t('Bitte Vorname und Nachname eingeben', 'Vă rugăm introduceți prenumele și numele de familie');
  String get nameMin2Chars => _t('Name muss mindestens 2 Zeichen haben', 'Numele trebuie să aibă cel puțin 2 caractere');
  String get onlyLettersAndHyphen => _t('Nur Buchstaben und Bindestrich erlaubt', 'Doar litere și cratimă sunt permise');
  String get emailAddress => _t('E-Mail-Adresse', 'Adresă de e-mail');
  String get pleaseEnterEmail => _t('Bitte E-Mail eingeben', 'Vă rugăm introduceți e-mail-ul');
  String get pleaseEnterValidEmail => _t('Bitte gültige E-Mail eingeben', 'Vă rugăm introduceți un e-mail valid');
  String get pleaseEnterPasswordField => _t('Bitte Passwort eingeben', 'Vă rugăm introduceți parola');
  String get recoveryCodeHelper => _t('Merken Sie sich diesen Code für Passwort-Wiederherstellung', 'Rețineți acest cod pentru recuperarea parolei');
  String get pleaseEnterRecoveryCodeField => _t('Bitte Wiederherstellungscode eingeben', 'Vă rugăm introduceți codul de recuperare');
  String registrationSuccess(String mitgliedernummer) => _t(
    'Registrierung erfolgreich!\n\nIhre Benutzernummer: $mitgliedernummer\n\nBitte merken Sie sich diese Nummer für die Anmeldung.\n\nWeiterleitung zur Anmeldung in 10 Sekunden...',
    'Înregistrare reușită!\n\nNumărul dvs. de utilizator: $mitgliedernummer\n\nVă rugăm să rețineți acest număr pentru autentificare.\n\nRedirecționare către autentificare în 10 secunde...',
  );
  String get registrationFailed => _t('Registrierung fehlgeschlagen', 'Înregistrare eșuată');
  String connectionErrorWith(String error) => _t('Verbindungsfehler: $error', 'Eroare de conexiune: $error');

  // ============================================================
  // DASHBOARD STATS
  // ============================================================
  String get totalUsers => _t('Gesamt Benutzer', 'Total utilizatori');
  String get newLabel => _t('Neu', 'Nou');

  // ============================================================
  // TICKETVERWALTUNG SCREEN
  // ============================================================
  String get newTicket => _t('Neues Ticket', 'Tichet nou');
  String get noTickets => _t('Keine Tickets', 'Fără tichete');
  String nTickets(int count) => count == 1 ? '1 Ticket' : '$count Tickets';
  String todayDash(String dayName, String dateStr) => _t('Heute — $dayName, $dateStr', 'Astăzi — $dayName, $dateStr');
  String get noTicketsForToday => _t('Keine Tickets für heute', 'Niciun tichet pentru astăzi');
  String get previousWeek => _t('Vorherige Woche', 'Săptămâna anterioară');
  String get nextWeekNav => _t('Nächste Woche', 'Săptămâna următoare');
  String get weekView => _t('Woche', 'Săptămână');
  String get waitingMember => _t('Warten Benutzer', 'Așteptare utilizator');
  String get waitingStaff => _t('Warten Mitarbeiter', 'Așteptare personal');
  String get waitingAuthority => _t('Warten Behörde', 'Așteptare autoritate');
  String get waitingDocuments => _t('Warten Unterlagen', 'Așteptare documente');
  String get monday => _t('Montag', 'Luni');
  String get tuesday => _t('Dienstag', 'Marți');
  String get wednesday => _t('Mittwoch', 'Miercuri');
  String get thursday => _t('Donnerstag', 'Joi');
  String get friday => _t('Freitag', 'Vineri');
  String get saturday => _t('Samstag', 'Sâmbătă');
  String get sunday => _t('Sonntag', 'Duminică');

  // ============================================================
  // TERMINVERWALTUNG SCREEN
  // ============================================================
  String get terminverwaltung => _t('Terminverwaltung', 'Administrarea programărilor');
  String get onlyNational => _t('Nur national', 'Doar național');
  String get holiday => _t('Feiertag', 'Sărbătoare legală');
  String get vacation => _t('Urlaub', 'Concediu');
  String get lunchBreak => _t('Mittagspause', 'Pauza de prânz');

  // ============================================================
  // TICKET DIALOGS
  // ============================================================
  String get noOpenTickets => _t('Keine offenen Tickets', 'Niciun tichet deschis');
  String get haveQuestionOrProblem => _t(
    'Haben Sie eine Frage oder ein Problem?\nErstellen Sie ein neues Ticket.',
    'Aveți o întrebare sau o problemă?\nCreați un tichet nou.',
  );
  String get createNewTicket => _t('Neues Ticket erstellen', 'Creează tichet nou');
  String get createTicketForMember => _t('Ticket für Mitglied erstellen', 'Creează tichet pentru membru');
  String get selectMember => _t('Mitglied auswählen:', 'Selectați membrul:');
  String get searchNameOrNumber => _t('Name oder Mitgliedernummer suchen...', 'Caută după nume sau număr de membru...');
  String get noMembersFound => _t('Keine Mitglieder gefunden', 'Niciun membru găsit');
  String get pleaseSelectMember => _t('Bitte wählen Sie ein Mitglied aus', 'Vă rugăm selectați un membru');
  String get pleaseFillSubjectAndMessage => _t('Bitte Betreff und Nachricht ausfüllen', 'Vă rugăm completați subiectul și mesajul');
  String get ticketCreated => _t('Ticket wurde erstellt', 'Tichetul a fost creat');
  String ticketCreatedFor(String name) => _t('Ticket für $name wurde erstellt', 'Tichetul pentru $name a fost creat');
  String get errorCreatingTicket => _t('Fehler beim Erstellen des Tickets', 'Eroare la crearea tichetului');
  String get submit => _t('Absenden', 'Trimite');
  String get createTicket => _t('Ticket erstellen', 'Creează tichet');
  String priorityLabel(String prio) => _t('Priorität: $prio', 'Prioritate: $prio');
  String get messageLabel => _t('Nachricht:', 'Mesaj:');
  String createdLabel(String date) => _t('Erstellt: $date', 'Creat: $date');
  String processorLabel(String name) => _t('Bearbeiter: $name', 'Procesat de: $name');
  String get scheduledDate => _t('Geplanter Termin: *', 'Data programată: *');

  // ============================================================
  // TERMIN DIALOGS
  // ============================================================
  String get newTermin => _t('Neuer Termin', 'Programare nouă');
  String get editTermin => _t('Termin bearbeiten', 'Editează programarea');
  String get category => _t('Kategorie', 'Categorie');
  String get categoryRequired => _t('Kategorie *', 'Categorie *');
  String get boardMeeting => _t('Vorstandssitzung', 'Ședință de conducere');
  String get generalAssembly => _t('Mitgliederversammlung', 'Adunare generală');
  String get training => _t('Schulung', 'Instruire');
  String get other => _t('Sonstiges', 'Altele');
  String get titleRequired => _t('Titel *', 'Titlu *');
  String get titleIsRequired => _t('Titel erforderlich', 'Titlul este obligatoriu');
  String get required => _t('Erforderlich', 'Obligatoriu');
  String get durationMinutes => _t('Dauer (Min.)', 'Durata (min.)');
  String get locationRequired => _t('Ort *', 'Locație *');
  String get locationIsRequired => _t('Ort erforderlich', 'Locația este obligatorie');
  String participantsSelected(int count) => _t(
    'Teilnehmer ($count ausgewählt) *',
    'Participanți ($count selectați) *',
  );
  String get selectAll => _t('Alle auswählen', 'Selectează toate');
  String get selectNone => _t('Keine', 'Niciuna');
  String get linkedTicketOptional => _t('Verknüpftes Ticket (optional)', 'Tichet asociat (opțional)');
  String get noTicketLinked => _t('Kein Ticket', 'Niciun tichet');
  String get createTermin => _t('Termin erstellen', 'Creează programare');
  String get atLeastOneParticipant => _t('Bitte mindestens einen Teilnehmer auswählen', 'Vă rugăm selectați cel puțin un participant');
  String get terminTimeRestriction => _t(
    'Termine sind nur möglich:\n08:00-12:00 und 14:00-18:00 Uhr',
    'Programările sunt posibile doar:\n08:00-12:00 și 14:00-18:00',
  );
  String get terminCreatedSuccess => _t('Termin erfolgreich erstellt', 'Programare creată cu succes');
  String get terminUpdated => _t('Termin aktualisiert', 'Programare actualizată');
  String get terminDeleted => _t('Termin gelöscht', 'Programare ștearsă');
  String get deleteTermin => _t('Termin löschen?', 'Ștergeți programarea?');
  String deleteTerminConfirm(String title) => _t(
    'Möchten Sie "$title" wirklich löschen?',
    'Doriți cu adevărat să ștergeți "$title"?',
  );
  String errorMessage(String msg) => _t('Fehler: $msg', 'Eroare: $msg');

  // ============================================================
  // LIVE CHAT DIALOG
  // ============================================================
  String get connected => _t('Verbunden', 'Conectat');
  String get offline => 'Offline';
  String get callSupport => _t('Anrufen', 'Apelează');
  String get startConversation => _t('Starten Sie eine Konversation!', 'Începeți o conversație!');
  String get staffWillReply => _t('Ein Mitarbeiter wird Ihnen bald antworten.', 'Un membru al personalului vă va răspunde în curând.');
  String typingIndicator(String name) => _t('$name schreibt...', '$name scrie...');
  String get enterMessage => _t('Nachricht eingeben...', 'Introduceți mesajul...');
  String get takePhoto => _t('Foto aufnehmen', 'Fotografiați');
  String get attachFiles => _t('Dateien anhängen (PDF, PNG, JPEG, TXT)', 'Atașați fișiere (PDF, PNG, JPEG, TXT)');
  String get maxTotalSize => _t('Maximale Gesamtgröße: 100 MB', 'Dimensiune maximă totală: 100 MB');
  String get maxFileSize => _t('Maximale Dateigröße: 100 MB', 'Dimensiune maximă fișier: 100 MB');
  String get errorSelectingFiles => _t('Fehler beim Auswählen der Dateien', 'Eroare la selectarea fișierelor');
  String get errorTakingPhoto => _t('Fehler beim Aufnehmen des Fotos', 'Eroare la capturarea fotografiei');
  String get errorUploading => _t('Fehler beim Hochladen', 'Eroare la încărcare');
  String errorUploadingWith(String error) => _t('Fehler beim Hochladen: $error', 'Eroare la încărcare: $error');
  String get errorDownloading => _t('Fehler beim Herunterladen', 'Eroare la descărcare');
  String errorDownloadingWith(String error) => _t('Fehler beim Herunterladen: $error', 'Eroare la descărcare: $error');
  String get errorSending => _t('Fehler beim Senden', 'Eroare la trimitere');
  String errorSendingWith(String error) => _t('Fehler beim Senden: $error', 'Eroare la trimitere: $error');
  String get callEnded => _t('Anruf beendet', 'Apel încheiat');
  String get supportBusy => _t('Support ist beschäftigt', 'Suportul este ocupat');
  String get callRejected => _t('Anruf wurde abgelehnt', 'Apelul a fost respins');
  String get callCouldNotConnect => _t('Anruf konnte nicht verbunden werden', 'Apelul nu a putut fi conectat');
  String get noMicrophoneFound => _t(
    'Kein Mikrofon gefunden. Bitte schließen Sie ein Mikrofon an und versuchen Sie es erneut.',
    'Nu s-a găsit un microfon. Vă rugăm conectați un microfon și încercați din nou.',
  );
  String errorStartingCall(String error) => _t('Fehler beim Starten des Anrufs: $error', 'Eroare la pornirea apelului: $error');
  String errorConnecting(String error) => _t('Fehler beim Verbinden: $error', 'Eroare la conectare: $error');
  String errorAccepting(String error) => _t('Fehler beim Annehmen: $error', 'Eroare la acceptare: $error');

  // ============================================================
  // PROFILE DIALOG
  // ============================================================
  String get profileTab => _t('Profil', 'Profil');
  String get myDevices => _t('Meine Geräte', 'Dispozitivele mele');
  String get businessCard => _t('Visitenkarte', 'Carte de vizită');
  String get warnings => _t('Verwarnungen', 'Avertismente');
  String get documents => _t('Dokumente', 'Documente');
  String get membership => _t('Mitgliedschaft', 'Calitate de membru');
  String get verification => _t('Verifizierung', 'Verificare');
  String get addPhoneNumber => _t('Telefonnummer hinzufügen', 'Adăugați număr de telefon');
  String get changeEmail => _t('E-Mail ändern', 'Schimbă e-mail');
  String get changePassword => _t('Passwort ändern', 'Schimbă parola');
  String get newEmailAddress => _t('Neue E-Mail-Adresse', 'Adresă de e-mail nouă');
  String get currentPassword => _t('Aktuelles Passwort', 'Parola curentă');
  String get saveEmail => _t('E-Mail speichern', 'Salvează e-mail');
  String get savePassword => _t('Passwort speichern', 'Salvează parola');
  String get passwordsDoNotMatchError => _t('Passwörter stimmen nicht überein', 'Parolele nu se potrivesc');
  String get passwordMin8Chars => _t('Passwort muss mindestens 8 Zeichen lang sein', 'Parola trebuie să aibă cel puțin 8 caractere');
  String get passwordChangedSuccess => _t('Passwort erfolgreich geändert', 'Parola a fost schimbată cu succes');
  String get errorChangingPassword => _t('Fehler beim Ändern des Passworts', 'Eroare la schimbarea parolei');
  String get pleaseEnterValidEmailAddress => _t('Bitte geben Sie eine gültige E-Mail-Adresse ein', 'Vă rugăm introduceți o adresă de e-mail validă');
  String get emailChangedSuccess => _t('E-Mail erfolgreich geändert', 'E-mail-ul a fost schimbat cu succes');
  String get errorChangingEmail => _t('Fehler beim Ändern der E-Mail', 'Eroare la schimbarea e-mail-ului');
  String get pleaseEnterPhoneNumber => _t('Bitte Telefonnummer eingeben', 'Vă rugăm introduceți numărul de telefon');
  String get phoneNumberSaved => _t('Telefonnummer gespeichert', 'Număr de telefon salvat');
  String get errorSaving => _t('Fehler beim Speichern', 'Eroare la salvare');
  String get logoutDevice => _t('Gerät abmelden', 'Deconectează dispozitiv');
  String logoutDeviceConfirm(String device) => _t(
    'Möchten Sie das Gerät "$device" wirklich abmelden?',
    'Doriți cu adevărat să deconectați dispozitivul "$device"?',
  );
  String get deviceLoggedOutSuccess => _t('Gerät erfolgreich abgemeldet', 'Dispozitiv deconectat cu succes');
  String get errorLoggingOut => _t('Fehler beim Abmelden', 'Eroare la deconectare');
  String get noActiveDevices => _t('Keine aktiven Geräte', 'Niciun dispozitiv activ');
  String get unknownDeviceName => _t('Unbekanntes Gerät', 'Dispozitiv necunoscut');
  String get lastActive => _t('Zuletzt aktiv:', 'Ultima activitate:');
  String get currentDevice => _t('Aktuelles Gerät', 'Dispozitivul curent');
  String lastSeenLabel(String time) => _t('Zuletzt aktiv: $time', 'Ultima activitate: $time');
  String get justNow => _t('Gerade eben', 'Chiar acum');
  String minutesAgo(int min) => _t('vor $min Min.', 'acum $min min.');
  String hoursAgo(int hours) => _t('vor $hours Std.', 'acum $hours ore');
  String daysAgo(int days) => _t('vor $days Tagen', 'acum $days zile');
  String get never => _t('Nie', 'Niciodată');

  // Profile - Roles
  String get roleVorsitzer => 'Vorsitzer';
  String get roleSchatzmeister => 'Schatzmeister';
  String get roleKassierer => 'Kassierer';
  String get roleGruender => _t('Gründer', 'Fondator');

  // Profile - Verwarnungen
  String get warningTypeTotal => _t('Gesamt', 'Total');
  String get warningTypeErmahnung => _t('Ermahnung', 'Mustrare');
  String get warningTypeAbmahnung => _t('Abmahnung', 'Avertisment');
  String get warningTypeLetzte => _t('Letzte', 'Ultima');
  String get warningsNotAvailable => _t('Verwarnungen nicht verfügbar', 'Avertismente indisponibile');
  String myWarnings(int count) => _t('Meine Verwarnungen ($count)', 'Avertismentele mele ($count)');
  String get noWarningsAvailable => _t('Keine Verwarnungen vorhanden', 'Niciun avertisment');
  String createdBy(String name) => _t('Erstellt von: $name', 'Creat de: $name');

  // Profile - Dokumente
  String get documentsNotAvailable => _t('Dokumente nicht verfügbar', 'Documente indisponibile');
  String myDocuments(int count) => _t('Meine Dokumente ($count)', 'Documentele mele ($count)');
  String get noDocumentsAvailable => _t('Keine Dokumente vorhanden', 'Niciun document');
  String savedFile(String filename) => _t('Gespeichert: $filename', 'Salvat: $filename');
  String get openFile => _t('Öffnen', 'Deschide');
  String errorSavingWith(String error) => _t('Fehler beim Speichern: $error', 'Eroare la salvare: $error');
  String uploadedBy(String name) => _t('Hochgeladen von: $name', 'Încărcat de: $name');

  // Profile - Mitgliedschaft
  String get memberNumber => _t('Mitgliedernummer', 'Număr de membru');
  String get role => _t('Rolle', 'Rol');
  String get membershipType => _t('Mitgliedsart', 'Tip de membru');
  String get paymentMethod => _t('Zahlungsmethode', 'Metoda de plată');
  String get registeredOn => _t('Registriert am', 'Înregistrat la');
  String get lastLogin => _t('Letzter Login', 'Ultima autentificare');
  String get memberSince => _t('Mitglied seit', 'Membru din');
  String get notSet => _t('Nicht festgelegt', 'Nestabilit');
  String get notYetActivated => _t('Noch nicht aktiviert', 'Încă neactivat');
  String get neverLoggedIn => _t('Noch nie', 'Niciodată');
  String get ordinaryMember => _t('Ordentliches Mitglied', 'Membru ordinar');
  String get supportingMember => _t('Fördermitglied', 'Membru susținător');
  String get honoraryMember => _t('Ehrenmitglied', 'Membru de onoare');
  String get bankTransfer => _t('Überweisung', 'Transfer bancar');
  String get sepaDirectDebit => _t('SEPA-Lastschrift', 'Debitare directă SEPA');
  String get permanentOrder => _t('Dauerauftrag', 'Ordin permanent');

  // Profile - Verifizierung
  String get verificationNotAvailable => _t('Verifizierung nicht verfügbar', 'Verificare indisponibilă');
  String stagesVerified(int verified, int total) => _t('$verified/$total Stufen geprüft', '$verified/$total etape verificate');
  String stageName(int stufe) {
    switch (stufe) {
      case 1: return _t('Persönliche Daten', 'Date personale');
      case 2: return _t('Mitgliedsart', 'Tip de membru');
      case 3: return _t('Zahlungsmethode', 'Metoda de plată');
      case 4: return _t('Satzung', 'Statut');
      case 5: return _t('Datenschutz', 'Protecția datelor');
      case 6: return _t('Widerrufsbelehrung', 'Instrucțiuni de retragere');
      default: return _t('Stufe $stufe', 'Etapa $stufe');
    }
  }
  String get statusVerified => _t('Geprüft', 'Verificat');
  String get statusRejected => _t('Abgelehnt', 'Respins');
  String get statusOpenVerif => _t('Offen', 'Deschis');
  String verifiedOnBy(String date, String name) => _t(
    'Geprüft am $date von $name',
    'Verificat la $date de $name',
  );
  String get changesAfterVerification => _t(
    'Änderungen nach Verifizierung nur über Live-Chat mit Nachweisdokumenten möglich.',
    'Modificările după verificare sunt posibile doar prin Live-Chat cu documente justificative.',
  );
  String get personalDataSaved => _t('Persönliche Daten gespeichert', 'Date personale salvate');
  String get paymentDataSaved => _t('Zahlungsdaten gespeichert', 'Date de plată salvate');
  String get noPaymentMethodChosen => _t('Keine Zahlungsmethode gewählt.', 'Nicio metodă de plată selectată.');
  String get selectPaymentMethod => _t('Zahlungsmethode auswählen', 'Selectați metoda de plată');
  String get paymentDay => _t('Zahlungstag (monatliche Erinnerung)', 'Ziua de plată (memento lunar)');
  String get dayOfMonth => _t('Tag des Monats', 'Ziua lunii');
  String paymentDayReminder(int day) => _t(
    'Sie werden jeden $day. des Monats an die Überweisung erinnert.',
    'Veți fi notificat în fiecare $day a lunii despre transfer.',
  );
  String get changeLabel => _t('Ändern', 'Schimbă');

  // Profile - IP & Connection
  String get ipClean => _t('IP sauber - nicht gelistet', 'IP curat - nelistat');

  // ============================================================
  // PERSONAL DATA DIALOG
  // ============================================================
  String get personalData => _t('Persönliche Daten', 'Date personale');
  String get updateContactData => _t('Aktualisieren Sie Ihre Kontaktdaten', 'Actualizați-vă datele de contact');
  String get dataLoading => _t('Daten werden geladen...', 'Datele se încarcă...');
  String get firstName => _t('Vorname', 'Prenume');
  String get lastName => _t('Nachname', 'Nume de familie');
  String get pleaseEnterFirstName => _t('Bitte Vorname eingeben', 'Vă rugăm introduceți prenumele');
  String get pleaseEnterLastName => _t('Bitte Nachname eingeben', 'Vă rugăm introduceți numele de familie');
  String get street => _t('Straße', 'Strada');
  String get houseNumber => _t('Nr.', 'Nr.');
  String get postalCode => _t('PLZ', 'Cod poștal');
  String get city => _t('Ort', 'Localitate');
  String get birthDate => _t('Geburtsdatum', 'Data nașterii');
  String get birthDateHint => _t('TT.MM.JJJJ', 'ZZ.LL.AAAA');
  String get phoneNumber => _t('Telefonnummer', 'Număr de telefon');
  String get saveData => _t('Daten speichern', 'Salvează datele');
  String get dataSavedSuccess => _t('Daten erfolgreich gespeichert', 'Date salvate cu succes');

  // ============================================================
  // USER DETAILS DIALOG
  // ============================================================
  String get noChanges => _t('Keine Änderungen', 'Nicio modificare');
  String get userUpdatedSuccess => _t('Benutzer erfolgreich aktualisiert', 'Utilizator actualizat cu succes');
  String errorLoading(String msg) => _t('Fehler beim Laden: $msg', 'Eroare la încărcare: $msg');
  String connectionErrorWith2(String e) => _t('Verbindungsfehler: $e', 'Eroare de conexiune: $e');
  String get errorUpdating => _t('Fehler beim Aktualisieren', 'Eroare la actualizare');
  String errorWith(String e) => _t('Fehler: $e', 'Eroare: $e');
  String get sessionRevoked => _t('Sitzung widerrufen - Benutzer wurde abgemeldet', 'Sesiune revocată - Utilizatorul a fost deconectat');
  String get pleaseSelectViolationCategory => _t('Bitte Verstoß-Kategorie auswählen', 'Vă rugăm selectați categoria de încălcare');
  String get pleaseSelectMeasure => _t('Bitte Maßnahme auswählen', 'Vă rugăm selectați măsura');
  String get pleaseDescribeFacts => _t('Bitte Sachverhalt beschreiben', 'Vă rugăm descrieți situația de fapt');
  String measureCreatedFor(String measure, String name) => _t('$measure für $name erstellt', '$measure creat pentru $name');
  String get errorCreatingWarning => _t('Fehler beim Erstellen der Verwarnung', 'Eroare la crearea avertismentului');
  String get deleteWarningTitle => _t('Verwarnung löschen?', 'Ștergeți avertismentul?');
  String deleteWarningConfirm(String typ, String date) => _t('$typ vom $date wirklich löschen?', 'Ștergeți $typ din $date?');
  String get warningDeleted => _t('Verwarnung gelöscht', 'Avertisment șters');
  String get errorDeleting => _t('Fehler beim Löschen', 'Eroare la ștergere');
  String get createPdf => _t('PDF erstellen', 'Creează PDF');
  String get deleteWarning => _t('Verwarnung löschen', 'Șterge avertisment');
  String get accountDeactivated => _t('Konto deaktiviert', 'Cont dezactivat');
  String get accountActive => _t('Konto aktiv', 'Cont activ');
  String get accountData => _t('Kontodaten', 'Date cont');
  String get accountTab => _t('Konto', 'Cont');
  String get sessionsTab => _t('Sitzungen', 'Sesiuni');
  String get warningsTab => _t('Verwarnungen', 'Avertismente');
  String get documentsTab => _t('Dokumente', 'Documente');
  String get membershipTab => _t('Mitgliedschaft', 'Calitate de membru');
  String get verificationTab => _t('Verifizierung', 'Verificare');
  String get discountTab => _t('Ermäßigung', 'Reducere');
  String get notesTab => _t('Notizen', 'Note');
  String get ticketsTab => _t('Tickets', 'Tichete');
  String get appointmentsTab => _t('Termine', 'Programări');
  String get registrationSection => _t('Registrierung', 'Înregistrare');
  String get deactivationSection => _t('Deaktivierung', 'Dezactivare');
  String get deactivatedOn => _t('Deaktiviert am', 'Dezactivat la');
  String get notRecorded => _t('Nicht erfasst', 'Neînregistrat');
  String get reason => _t('Grund', 'Motiv');
  String get noReasonGiven => _t('Kein Grund angegeben', 'Niciun motiv specificat');
  String get autoDeactivationInfo => _t(
    'Dieses Konto wurde automatisch deaktiviert, da die Verifizierung nicht innerhalb von 30 Tagen nach der Registrierung abgeschlossen wurde.',
    'Acest cont a fost dezactivat automat deoarece verificarea nu a fost finalizată în termen de 30 de zile de la înregistrare.',
  );
  String editFieldLabel(String label) => _t('$label bearbeiten', 'Editează $label');
  String get editName => _t('Name bearbeiten', 'Editează numele');
  String get editEmail => _t('E-Mail bearbeiten', 'Editează e-mail');
  String get editRole => _t('Rolle bearbeiten', 'Editează rolul');
  String get changePasswordTitle => _t('Passwort ändern', 'Schimbă parola');
  String get minChars8 => _t('Mindestens 8 Zeichen', 'Cel puțin 8 caractere');
  String get activeSessions => _t('Aktive Sitzungen', 'Sesiuni active');
  String get noActiveSessions => _t('Keine aktiven Sitzungen', 'Niciun sesiune activă');
  String get registeredDevices => _t('Registrierte Geräte', 'Dispozitive înregistrate');
  String loggedInOn(String date) => _t('Angemeldet: $date', 'Autentificat: $date');
  String expiresOnDate(String date) => _t('Läuft ab: $date', 'Expiră: $date');
  String get revokeSessionTooltip => _t('Sitzung widerrufen (Force Logout)', 'Revocă sesiune (Deconectare forțată)');
  String get inactive => _t('Inaktiv', 'Inactiv');
  String lastUsed(String date) => _t('Zuletzt verwendet: $date', 'Ultima utilizare: $date');
  String get newDisciplinaryMeasure => _t('Neue Ordnungsmaßnahme', 'Măsură disciplinară nouă');
  String get violationLabel => _t('Verstoß:', 'Încălcare:');
  String get factsLabel => _t('Sachverhalt (was ist passiert?)', 'Situația de fapt (ce s-a întâmplat?)');
  String get measureSectionLabel => _t('Maßnahme (§6 Abs. 6):', 'Măsură (§6 alin. 6):');
  String get amountMax100 => _t('Betrag (max. 100 €)', 'Sumă (max. 100 €)');
  String get issueMeasurePdf => _t('Maßnahme ausstellen + PDF', 'Emite măsură + PDF');
  String warningsCount(int count) => _t('Verwarnungen ($count)', 'Avertismente ($count)');
  String get noWarnings => _t('Keine Verwarnungen vorhanden', 'Niciun avertisment');
  String get max10FilesPerUpload => _t('Maximum 10 Dateien pro Upload', 'Maximum 10 fișiere per încărcare');
  String fileTooLarge(String name) => _t('"$name" ist zu groß (max. 100 MB)', '"$name" este prea mare (max. 100 MB)');
  String get uploadAssociationDoc => _t('Vereindokument hochladen', 'Încarcă document asociație');
  String get uploadAuthorityDoc => _t('Behörde Unterlagen hochladen', 'Încarcă documente autoritate');
  String get documentName => _t('Dokumentname', 'Nume document');
  String get documentType => _t('Dokumenttyp', 'Tip document');
  String get descriptionOptional => _t('Beschreibung (optional)', 'Descriere (opțional)');
  String get expiryDate => _t('Ablaufdatum', 'Data de expirare');
  String get noExpiryDate => _t('Kein Ablaufdatum', 'Fără dată de expirare');
  String get expiryAutoDeleteInfo => _t('Dokumente mit Ablaufdatum werden nach Ablauf automatisch gelöscht.', 'Documentele cu dată de expirare vor fi șterse automat după expirare.');
  String uploadFilesCount(int count) => _t('$count ${count == 1 ? "Datei" : "Dateien"} hochladen', '$count ${count == 1 ? "fișier" : "fișiere"} încarcă');
  String documentUploaded(String name) => _t('Dokument "$name" hochgeladen', 'Document "$name" încărcat');
  String get errorUploading2 => _t('Fehler beim Hochladen', 'Eroare la încărcare');
  String documentsUploaded(int count) => _t('$count Dokumente hochgeladen', '$count documente încărcate');
  String get deleteDocumentTitle => _t('Dokument löschen?', 'Ștergeți documentul?');
  String deleteDocumentConfirm(String name, String filename) => _t('"$name" ($filename) wirklich löschen?', 'Ștergeți "$name" ($filename)?');
  String get documentDeleted => _t('Dokument gelöscht', 'Document șters');
  String get previewOnlyPdfImages => _t('Vorschau nur für PDF und Bilder verfügbar', 'Previzualizarea este disponibilă doar pentru PDF și imagini');
  String get fileLoading => _t('Datei wird geladen...', 'Fișierul se încarcă...');
  String get errorLoadingFile => _t('Fehler beim Laden der Datei', 'Eroare la încărcarea fișierului');
  String errorDisplaying(String e) => _t('Fehler beim Anzeigen: $e', 'Eroare la afișare: $e');
  String savedFilename(String filename) => _t('Gespeichert: $filename', 'Salvat: $filename');
  String get errorSaving2 => _t('Fehler beim Speichern', 'Eroare la salvare');
  String errorSavingWith2(String e) => _t('Fehler beim Speichern: $e', 'Eroare la salvare: $e');
  String get associationDocuments => _t('Vereindokumente', 'Documente asociație');
  String get authorityDocuments => _t('Behörde Unterlagen', 'Documente autoritate');
  String associationDocsCount(int count) => _t('Vereindokumente ($count)', 'Documente asociație ($count)');
  String authorityDocsCount(int count) => _t('Behörde Unterlagen ($count)', 'Documente autoritate ($count)');
  String get noAssociationDocs => _t('Keine Vereindokumente vorhanden', 'Niciun document asociație');
  String get noAuthorityDocs => _t('Keine Behörde Unterlagen vorhanden', 'Niciun document autoritate');
  String get associationDocInfo => _t('Beitrittsantrag, Aufnahmebestätigung, Kündigung usw. | PDF, JPG, PNG, TXT (max. 100 MB, 10 Dateien)', 'Cerere de aderare, confirmare, reziliere etc. | PDF, JPG, PNG, TXT (max. 100 MB, 10 fișiere)');
  String get authorityDocInfo => _t('Krankenkasse, Finanzamt usw. | Dokumente mit Ablaufdatum werden automatisch gelöscht', 'Asigurări de sănătate, Finanțe etc. | Documentele cu dată de expirare vor fi șterse automat');
  String get aes256Encrypted => _t('AES-256 verschlüsselt', 'Criptat AES-256');
  String get preview => _t('Vorschau', 'Previzualizare');
  String get revokeSessionTitle => _t('Sitzung widerrufen?', 'Revocați sesiunea?');
  String get revokeSessionInfo => _t('Der Benutzer wird von diesem Gerät abgemeldet und muss sich neu anmelden.', 'Utilizatorul va fi deconectat de pe acest dispozitiv și va trebui să se autentifice din nou.');
  String get revoke => _t('Widerrufen', 'Revocă');
  String get changeStatusButton => _t('Status ändern', 'Schimbă status');
  String get currentStatusLabel => _t('Aktueller Status: ', 'Status curent: ');
  String get newStatusLabel => _t('Neuer Status:', 'Status nou:');
  String statusChanged(String status) => _t('Status geändert: $status', 'Status schimbat: $status');
  String get membershipDateSaved => _t('Mitgliedschaftsdatum gespeichert', 'Data de membru salvată');
  String get changeDateRetroactive => _t('Datum ändern (z.B. rückwirkend)', 'Schimbă data (ex. retroactiv)');
  String get feeExemption => _t('Beitragsbefreiung', 'Scutire de contribuții');
  String get exemptLabel => _t('Befreit', 'Scutit');
  String get uploadCertificate => _t('Bescheid hochladen', 'Încarcă decizia');
  String get noExemptionInfo => _t('Keine Befreiung vorhanden. Bewilligungsbescheid vom Jobcenter oder Sozialamt hochladen.', 'Nu există scutire. Încărcați decizia de aprobare de la Jobcenter sau Oficiul de asistență socială.');
  String get noVerificationData => _t('Keine Verifizierungsdaten geladen', 'Nicio dată de verificare încărcată');
  String get reloadData => _t('Erneut laden', 'Reîncarcă');
  String stagesChecked(int checked, int total) => _t('$checked/$total Stufen geprüft', '$checked/$total etape verificate');
  String stageLabel(int stufe, String stageName) => _t('Stufe $stufe: $stageName', 'Etapa $stufe: $stageName');
  String checkedOnBy(String date, String byName) => _t('Geprüft am $date von $byName', 'Verificat la $date de $byName');
  String get resetLabel => _t('Zurücksetzen', 'Resetează');
  String get rejectLabel => _t('Ablehnen', 'Respinge');
  String get checkedStatus => _t('Geprüft', 'Verificat');
  String get filledIn => _t('Ausgefüllt', 'Completat');
  String get rejectedStatus => _t('Abgelehnt', 'Respins');
  String get openStatus => _t('Offen', 'Deschis');
  String get notSpecified => _t('Nicht angegeben', 'Nespecificat');
  String get memberHasNotChosenType => _t('Das Mitglied hat noch keine Mitgliedsart gewählt.', 'Membrul nu a ales încă tipul de membru.');
  String get memberHasNotSpecifiedFinancial => _t('Das Mitglied hat noch keine Angabe zur finanziellen Situation gemacht.', 'Membrul nu a specificat încă situația financiară.');
  String get noPaymentMethod => _t('Keine Zahlungsmethode gewählt.', 'Nicio metodă de plată selectată.');
  String get memberChosenStartDate => _t('Das Mitglied hat gewählt, ab wann die Mitgliedschaft beginnen soll.', 'Membrul a ales de când ar trebui să înceapă calitatea de membru.');
  String get feeExemptRetroactive => _t('Beitragsbefreit (Ermäßigung) – 0 € retroaktiv', 'Scutit de contribuții (reducere) - 0 € retroactiv');
  String get paymentMethodSaved => _t('Zahlungsmethode gespeichert', 'Metoda de plată salvată');
  String acceptedAtRegistrationDate(String date) => _t('Bei Registrierung akzeptiert am $date', 'Acceptat la înregistrare pe $date');
  String get statuteLabel2 => _t('Satzung', 'Statut');
  String get statuteDesc => _t('Die Satzung des Vereins muss vom Mitglied gelesen und akzeptiert werden.', 'Statutul asociației trebuie citit și acceptat de membru.');
  String get openStatute => _t('Satzung öffnen', 'Deschide statutul');
  String get privacyLabel => _t('Datenschutz', 'Protecția datelor');
  String get privacyDesc => _t('Die Datenschutzerklärung muss vom Mitglied gelesen und akzeptiert werden.', 'Declarația de confidențialitate trebuie citită și acceptată de membru.');
  String get openPrivacy => _t('Datenschutz öffnen', 'Deschide confidențialitatea');
  String get withdrawalLabelFull => _t('Widerrufsbelehrung', 'Instrucțiuni de retragere');
  String get withdrawalDesc => _t('Die Widerrufsbelehrung muss vom Mitglied gelesen und akzeptiert werden.', 'Instrucțiunile de retragere trebuie citite și acceptate de membru.');
  String get openWithdrawal => _t('Widerrufsbelehrung öffnen', 'Deschide instrucțiunile de retragere');
  String rejectStage(int stufe) => _t('Stufe $stufe ablehnen', 'Respinge etapa $stufe');
  String get rejectionReasonOptional => _t('Grund der Ablehnung (optional)', 'Motivul respingerii (opțional)');
  String stageCheckedMsg(int stufe) => _t('Stufe $stufe geprüft', 'Etapa $stufe verificată');
  String stageRejectedMsg(int stufe) => _t('Stufe $stufe abgelehnt', 'Etapa $stufe respinsă');
  String stageResetMsg(int stufe) => _t('Stufe $stufe zurückgesetzt', 'Etapa $stufe resetată');
  String get deleteExemptionTitle => _t('Befreiung löschen', 'Șterge scutirea');
  String get deleteExemptionConfirm => _t('Soll diese Befreiung mit dem Dokument endgültig gelöscht werden?', 'Doriți să ștergeți definitiv această scutire împreună cu documentul?');
  String get exemptionDeleted => _t('Befreiung gelöscht', 'Scutire ștearsă');
  String get rejectExemptionTitle => _t('Befreiung ablehnen', 'Respinge scutirea');
  String get exemptionApproved => _t('Befreiung genehmigt', 'Scutire aprobată');
  String get exemptionRejected => _t('Befreiung abgelehnt', 'Scutire respinsă');
  String get statusResetLabel => _t('Status zurückgesetzt', 'Status resetat');
  String get statusUpdated => _t('Status aktualisiert', 'Status actualizat');
  String get approveLabel => _t('Genehmigen', 'Aprobă');
  String get approvalCertificate => _t('Bewilligungsbescheid', 'Decizie de aprobare');
  String get authorityRequired => _t('Behörde *', 'Autoritate *');
  String get certificateDateLabel => _t('Bescheid-Datum', 'Data deciziei');
  String get selectDatePlaceholder => _t('Datum wählen...', 'Selectați data...');
  String get validFromRequired => _t('Gültig von *', 'Valabil de la *');
  String get selectStartDate => _t('Startdatum wählen... *', 'Selectați data de început... *');
  String get validUntilRequired => _t('Gültig bis *', 'Valabil până la *');
  String get selectEndDate => _t('Enddatum wählen... *', 'Selectați data de sfârșit... *');
  String get approvalCertificateRequired => _t('Bewilligungsbescheid *', 'Decizie de aprobare *');
  String get selectApprovalCertificate => _t('Bewilligungsbescheid auswählen', 'Selectați decizia de aprobare');
  String get selectFileLabel => _t('Datei auswählen (PDF, JPG, PNG)...', 'Selectați fișier (PDF, JPG, PNG)...');
  String get noteFieldLabel => _t('Notiz', 'Notă');
  String get optionalNote => _t('Optionale Anmerkung...', 'Notă opțională...');
  String get certificateUploaded => _t('Bewilligungsbescheid hochgeladen', 'Decizie de aprobare încărcată');
  String get errorDownloading2 => _t('Fehler beim Download', 'Eroare la descărcare');
  String get discountApplications => _t('Ermäßigungsanträge', 'Cereri de reducere');
  String openCountLabel(int count) => _t('$count offen', '$count deschise');
  String get noDiscountApplications => _t('Keine Ermäßigungsanträge vorhanden.', 'Nu există cereri de reducere.');
  String get submittedStatus => _t('Eingereicht', 'Depus');
  String get approvedStatus => _t('Genehmigt', 'Aprobat');
  String get rejectedStatus2 => _t('Abgelehnt', 'Respins');
  String get expiredStatus => _t('Abgelaufen', 'Expirat');
  String daysOpen(int days) => _t('$days Tage offen', '$days zile deschise');
  String get checkSectionLabel => _t('Prüfung', 'Verificare');
  String get documentReadable => _t('Dokument lesbar', 'Document lizibil');
  String get benefitTypeRecognizable => _t('Leistungsart erkennbar', 'Tip de prestație recognoscibil');
  String get currentWithin12Months => _t('Aktuell (innerhalb 12 Monate)', 'Actual (în ultimele 12 luni)');
  String get readableShort => _t('Lesbar', 'Lizibil');
  String get benefitTypeShort => _t('Leistungsart', 'Tip prestație');
  String get currentShortLabel => _t('Aktuell', 'Actual');
  String get rejectionReasonHeading => _t('Ablehnungsgrund:', 'Motiv respingere:');
  String get deleteApplicationTitle => _t('Antrag löschen', 'Șterge cererea');
  String get deleteApplicationConfirm => _t('Soll dieser Ermäßigungsantrag endgültig gelöscht werden?', 'Doriți să ștergeți definitiv această cerere de reducere?');
  String get applicationDeleted => _t('Antrag gelöscht', 'Cerere ștearsă');
  String get discountApproved => _t('Ermäßigung genehmigt', 'Reducere aprobată');
  String get discountRejected => _t('Ermäßigung abgelehnt', 'Reducere respinsă');
  String get rejectDiscountTitle => _t('Ermäßigung ablehnen', 'Respinge reducerea');
  String get rejectionReasonRequired => _t('Bitte geben Sie den Grund der Ablehnung an (Pflichtfeld):', 'Vă rugăm indicați motivul respingerii (câmp obligatoriu):');
  String get rejectionReasonField => _t('Ablehnungsgrund *', 'Motiv respingere *');
  String get rejectionReasonMandatory => _t('Ablehnungsgrund ist Pflicht', 'Motivul respingerii este obligatoriu');
  String get newNote => _t('Neue Notiz', 'Notă nouă');
  String get internalNoteHint => _t('Interne Notiz über dieses Mitglied...', 'Notă internă despre acest membru...');
  String get importantLabel => _t('Wichtig', 'Important');
  String get noNotesAvailable => _t('Keine Notizen vorhanden', 'Niciun notă disponibilă');
  String get noteSaved => _t('Notiz gespeichert', 'Notă salvată');
  String get deleteNoteTitle => _t('Notiz löschen', 'Șterge nota');
  String get deleteNoteConfirm => _t('Möchten Sie diese Notiz wirklich löschen?', 'Doriți cu adevărat să ștergeți această notă?');
  String get noteDeleted => _t('Notiz gelöscht', 'Notă ștearsă');
  String notesCountInfo(int count) => _t('$count Notiz${count == 1 ? '' : 'en'} — Nur für Admins sichtbar', '$count ${count == 1 ? 'notă' : 'note'} - Vizibil doar pentru administratori');
  String fromAuthor(String authorName, String number) => _t('von $authorName ($number)', 'de la $authorName ($number)');
  String get noTicketsAvailable2 => _t('Keine Tickets vorhanden', 'Niciun tichet disponibil');
  String ticketsCount(int count) => _t('$count Tickets', '$count tichete');
  String get openTickets => _t('Offen', 'Deschise');
  String get inWorkTickets => _t('In Arbeit', 'În lucru');
  String get doneTickets => _t('Erledigt', 'Finalizate');
  String get timeTracking => _t('Zeiterfassung', 'Urmărire timp');
  String get totalShortLabel => _t('gesamt', 'total');
  String get travelTime => _t('Fahrzeit', 'Timp deplasare');
  String get workTime => _t('Arbeitszeit', 'Timp lucru');
  String get waitTime => _t('Wartezeit', 'Timp așteptare');
  String get noAppointmentsAvailable => _t('Keine Termine vorhanden', 'Nicio programare disponibilă');
  String appointmentsCount(int count) => _t('$count Termine', '$count programări');
  String get upcomingAppointments => _t('Anstehende Termine', 'Programări viitoare');
  String get pastAppointments => _t('Vergangene Termine', 'Programări trecute');
  String get upcomingShort => _t('Anstehend', 'Viitoare');
  String get pastShort => _t('Vergangen', 'Trecute');
  String get cancelledStatus => _t('Abgesagt', 'Anulat');
  String confirmedOfTotal(int confirmed, int totalCount) => _t('$confirmed/$totalCount bestätigt', '$confirmed/$totalCount confirmate');
  String get ipCleanNotListed => _t('IP sauber - nicht gelistet', 'IP curat - nelistat');
  String get validFromLabel => _t('Gültig von', 'Valabil de la');
  String get validUntilLabel => _t('Gültig bis', 'Valabil până la');
  String get certificateFrom => _t('Bescheid vom', 'Decizie din');
  String expiredOnDate(String date) => _t('Abgelaufen am $date', 'Expirat la $date');
  String validUntilDate(String date) => _t('Gültig bis $date', 'Valabil până la $date');
  String validUntilDays(String date, int days) => _t('Gültig bis $date ($days Tage)', 'Valabil până la $date ($days zile)');
  String get fromFieldLabel => _t('Von:', 'De la:');
  String nDocumentsLabel(int count) => _t('$count Dokumente', '$count documente');
  String get categoryLabel => _t('Kategorie', 'Categorie');

  // ============================================================
  // CHANGELOG DIALOG
  // ============================================================
  String get changelog => _t('Änderungsprotokoll', 'Jurnal modificări');
  String get retryLabel => _t('Erneut versuchen', 'Încearcă din nou');
  String get errorLoadingData => _t('Fehler beim Laden', 'Eroare la încărcare');
  String get currentLabel => _t('AKTUELL', 'CURENT');

  // ============================================================
  // WEATHER
  // ============================================================
  String get weatherCurrentTab => _t('Aktuell', 'Curent');
  String get hourlyTab => _t('Stündlich', 'Pe oră');
  String get threeDays => _t('3 Tage', '3 zile');
  String get weatherWeekTab => _t('Woche', 'Săptămână');
  String dwdWarnings(int count) => _t('DWD Warnungen ($count)', 'Alerte DWD ($count)');

  // ============================================================
  // MISC / SHARED
  // ============================================================
  String unreadMessages(int count) => _t('$count ungelesene Nachrichten', '$count mesaje necitite');
  String get code => _t('Code', 'Cod');

  // ============================================================
  // ADMIN CHAT DIALOG
  // ============================================================
  String get liveChatSupport => _t('Live Chat - Support', 'Live Chat - Suport');
  String get newConversation => _t('Neue Konversation', 'Conversație nouă');
  String get noConversations => _t('Keine Konversationen', 'Nicio conversație');
  String get selectConversation => _t('Wählen Sie eine Konversation', 'Selectați o conversație');
  String get noMessages => _t('Keine Nachrichten', 'Niciun mesaj');
  String get closeConversation => _t('Konversation schließen', 'Închide conversația');
  String get closeConversationConfirm => _t(
    'Möchten Sie diese Konversation wirklich schließen?',
    'Doriți cu adevărat să închideți această conversație?',
  );
  String get conversationClosed => _t('Konversation geschlossen', 'Conversație închisă');
  String get muteTitle => _t('Stummschalten', 'Dezactivează sunetul');
  String get muteDurationQuestion => _t(
    'Wie lange soll diese Konversation stummgeschaltet werden?',
    'Cât timp doriți să dezactivați notificările pentru această conversație?',
  );
  String get eightHours => _t('8 Stunden', '8 ore');
  String get oneWeek => _t('1 Woche', '1 săptămână');
  String get always => _t('Immer', 'Întotdeauna');
  String get conversationMuted => _t('Konversation stummgeschaltet', 'Conversație cu sunetul dezactivat');
  String get muteRemoved => _t('Stummschaltung aufgehoben', 'Sunetul a fost reactivat');
  String get userBusyInCall => _t('Der Benutzer ist bereits in einem anderen Anruf', 'Utilizatorul este deja într-un alt apel');
  String get userIsBusy => _t('Der Benutzer ist beschäftigt', 'Utilizatorul este ocupat');
  String get maxFilesAllowed => _t('Maximal 10 Dateien erlaubt', 'Maximum 10 fișiere permise');
  String get errorSelecting => _t('Fehler beim Auswählen', 'Eroare la selectare');
  String get uploadFailed => _t('Upload fehlgeschlagen', 'Încărcarea a eșuat');
  String get uploadError => _t('Upload Fehler', 'Eroare la încărcare');
  String get largeFileDownload => _t('Große Datei - Download via URL nicht implementiert', 'Fișier mare - descărcare via URL neimplementat');
  String get downloadFailed2 => _t('Download fehlgeschlagen', 'Descărcarea a eșuat');
  String get downloadError => _t('Download Fehler', 'Eroare la descărcare');
  String conversationStartedWith(String name) => _t('Konversation mit $name gestartet', 'Conversație cu $name începută');
  String get errorStartingConversation => _t('Fehler beim Starten der Konversation', 'Eroare la pornirea conversației');
  String get startNewConversation => _t('Neue Konversation starten', 'Începe conversație nouă');
  String get noMembersFoundChat => _t('Keine Mitglieder gefunden', 'Niciun membru găsit');
  String get statusMessageLabel => _t('Statusnachricht', 'Mesaj de status');
  String get statusMessageManage => _t('Statusnachricht verwalten', 'Administrare mesaj de status');
  String get statusMessageHint => _t('z.B. Notfallintervention - Bin derzeit nicht erreichbar', 'ex. Intervenție de urgență - Nu sunt disponibil momentan');
  String get removeLabel => _t('Entfernen', 'Elimină');
  String get manageMessages => _t('Nachrichten verwalten', 'Administrare mesaje');

  // Scheduled Messages
  String get automaticMessages => _t('Automatische Nachrichten', 'Mesaje automate');
  String get newMessage => _t('Neue Nachricht', 'Mesaj nou');
  String get noAutomaticMessages => _t('Keine automatischen Nachrichten', 'Niciun mesaj automat');
  String get createReminders => _t(
    'Erstellen Sie Erinnerungen für Mahlzeiten, Medikamente, etc.',
    'Creați mementouri pentru mese, medicamente etc.',
  );
  String get deleteMessageTitle => _t('Nachricht löschen?', 'Ștergeți mesajul?');
  String messageWillBeDeleted(String msg) => _t('„$msg" wird gelöscht.', '„$msg" va fi șters.');
  String get newAutomaticMessage => _t('Neue automatische Nachricht', 'Mesaj automat nou');
  String get editMessage => _t('Nachricht bearbeiten', 'Editare mesaj');
  String get categoryBreakfast => _t('Frühstück', 'Mic dejun');
  String get categoryLunch => _t('Mittagessen', 'Prânz');
  String get categoryDinner => _t('Abendessen', 'Cină');
  String get categoryMedicine => _t('Medikament', 'Medicament');
  String get categoryOther => _t('Sonstiges', 'Altele');
  String get weekdays => _t('Wochentage', 'Zilele săptămânii');
  String get daily => _t('Täglich', 'Zilnic');
  String get messageHintMorning => _t('z.B. Guten Morgen! Haben Sie Ihr Frühstück eingenommen?', 'ex. Bună dimineața! Ați luat micul dejun?');
  String get replyHint => _t('Antwort eingeben...', 'Introduceți răspunsul...');
  String get noMessagesAvailable => _t('Keine automatischen Nachrichten vorhanden', 'Nu există mesaje automate');
  String get createMessagesFirst => _t('Erstellen Sie zuerst Nachrichten über das Hauptmenü', 'Creați întâi mesaje din meniul principal');
  String get urgentMessage => _t('Als dringende Nachricht markieren (Full-Screen Alert)', 'Marchează ca mesaj urgent (alertă pe ecran complet)');
  String get conversationClosedIndicator => _t('Diese Konversation wurde geschlossen', 'Această conversație a fost închisă');

  // ============================================================
  // CHAT HEADER
  // ============================================================
  String get automaticMessagesSettings => _t('Automatische Nachrichten', 'Mesaje automate');
  String get unmuteNotifications => _t('Stummschaltung aufheben', 'Activează notificările');
  String get muteNotifications => _t('Stummschalten', 'Dezactivează notificările');
  String get callUser => _t('Benutzer anrufen', 'Apelează utilizatorul');
  String get closeConversationTooltip => _t('Konversation schließen', 'Închide conversația');
  String get onlineStatus => 'Online';
  String get offlineStatus => 'Offline';

  // ============================================================
  // CHAT MESSAGE BUBBLE
  // ============================================================
  String get urgentBadge => 'DRINGEND';
  String get translatedLabel => _t('Übersetzt', 'Tradus');
  String get copiedLabel => _t('Kopiert!', 'Copiat!');
  String get userLabel => _t('Benutzer', 'Utilizator');

  // ============================================================
  // CHAT INPUT AREA
  // ============================================================
  String get attachFilesMax => _t('Dateien anhängen (max. 10, 100MB)', 'Atașați fișiere (max. 10, 100MB)');

  // ============================================================
  // CONVERSATION LIST ITEM
  // ============================================================
  String get noMessagesConv => _t('Keine Nachrichten', 'Niciun mesaj');
  String get inCallLabel => _t('Im Anruf...', 'În apel...');
  String lastActiveSecondsAgo(int seconds) => _t('zuletzt aktiv vor $seconds Sekunden', 'ultima activitate acum $seconds secunde');
  String lastActiveMinutesAgo(int minutes) => _t(
    'zuletzt aktiv vor $minutes ${minutes == 1 ? "Minute" : "Minuten"}',
    'ultima activitate acum $minutes ${minutes == 1 ? "minut" : "minute"}',
  );
  String lastActiveHoursAgo(int hours) => _t(
    'zuletzt aktiv vor $hours ${hours == 1 ? "Stunde" : "Stunden"}',
    'ultima activitate acum $hours ${hours == 1 ? "oră" : "ore"}',
  );
  String lastActiveDaysAgo(int days) => _t(
    'zuletzt aktiv vor $days ${days == 1 ? "Tag" : "Tagen"}',
    'ultima activitate acum $days ${days == 1 ? "zi" : "zile"}',
  );
  String lastActiveWeeksAgo(int weeks) => _t(
    'zuletzt aktiv vor $weeks ${weeks == 1 ? "Woche" : "Wochen"}',
    'ultima activitate acum $weeks ${weeks == 1 ? "săptămână" : "săptămâni"}',
  );
  String lastActiveMonthsAgo(int months) => _t(
    'zuletzt aktiv vor $months ${months == 1 ? "Monat" : "Monaten"}',
    'ultima activitate acum $months ${months == 1 ? "lună" : "luni"}',
  );
  String lastActiveYearsAgo(int years) => _t(
    'zuletzt aktiv vor $years ${years == 1 ? "Jahr" : "Jahren"}',
    'ultima activitate acum $years ${years == 1 ? "an" : "ani"}',
  );

  // ============================================================
  // DEBUG CONSOLE
  // ============================================================
  String get debugConsole => 'Debug Console';
  String entriesCount(int count) => _t('$count Einträge', '$count intrări');
  String get autoScrollOn => _t('Auto-scroll AN', 'Auto-scroll PORNIT');
  String get autoScrollOff => _t('Auto-scroll AUS', 'Auto-scroll OPRIT');
  String get copyLogs => _t('Logs kopieren', 'Copiază jurnalele');
  String get deleteLogs => _t('Logs löschen', 'Șterge jurnalele');
  String get logsCopied => _t('Logs kopiert!', 'Jurnale copiate!');
  String get noLogs => _t('Keine Logs', 'Niciun jurnal');

  // ============================================================
  // FILE VIEWER DIALOG
  // ============================================================
  String get saveFile => _t('Datei speichern', 'Salvează fișierul');
  String get downloadTooltip => _t('Herunterladen', 'Descarcă');
  String get printTooltip => _t('Drucken', 'Tipărire');
  String get printError => _t('Fehler beim Drucken', 'Eroare la tipărire');
  String savedLabel(String name) => _t('Gespeichert: $name', 'Salvat: $name');
  String get webviewNotSupported => _t('WebView nicht unterstützt auf dieser Plattform', 'WebView nu este suportat pe această platformă');

  // ============================================================
  // VISITENKARTE (BUSINESS CARD)
  // ============================================================
  String get foundingMember => _t('Gründungsmitglied', 'Membru fondator');
  String get tapForBack => _t('Tippen für Rückseite', 'Atingeți pentru verso');
  String get tapForFront => _t('Tippen für Vorderseite', 'Atingeți pentru față');
  String get backSideComingSoon => _t('Rückseite kommt bald...', 'Verso-ul vine în curând...');

  // ============================================================
  // NOTAR DIALOGS
  // ============================================================
  String get editNotarData => _t('Notardaten bearbeiten', 'Editare date notar');
  String get additionalName => _t('Zusatzname', 'Nume suplimentar');
  String get addressLabel => _t('Adresse', 'Adresă');
  String get contactLabel => _t('Kontakt', 'Contact');
  String get websiteLabel => _t('Website', 'Website');
  String get faxLabel => _t('Fax', 'Fax');
  String get requiredField => _t('Pflichtfeld', 'Câmp obligatoriu');
  String get newInvoice => _t('Neue Rechnung', 'Factură nouă');
  String get invoiceNumber => _t('Rechnungsnummer *', 'Număr factură *');
  String get amountEuro => _t('Betrag (€) *', 'Sumă (€) *');
  String get paidCheckbox => _t('Bezahlt', 'Plătit');
  String get newVisit => _t('Neuer Besuch', 'Vizită nouă');
  String get purposeOccasion => _t('Zweck / Anlass *', 'Scop / Motiv *');
  String get participantsLabel => _t('Teilnehmer', 'Participanți');
  String get notSetTime => _t('Nicht gesetzt', 'Nesetat');
  String get plannedStatus => _t('Geplant', 'Planificat');
  String get completedStatus => _t('Abgeschlossen', 'Finalizat');
  String get cancelledStatusNotar => _t('Abgesagt', 'Anulat');
  String get newDocument => _t('Neues Dokument', 'Document nou');
  String get titleRequired2 => _t('Titel *', 'Titlu *');
  String get documentTypeLabel => _t('Dokumenttyp', 'Tip document');
  String get documentUrkunde => _t('Urkunde', 'Act notarial');
  String get documentVollmacht => _t('Vollmacht', 'Procură');
  String get documentSatzung => _t('Satzung', 'Statut');
  String get documentProtokoll => _t('Protokoll', 'Proces-verbal');
  String get documentAntrag => _t('Antrag', 'Cerere');
  String get documentSonstiges => _t('Sonstiges', 'Altele');
  String get deedNumber => _t('Urkundennummer', 'Număr act notarial');
  String get editTask => _t('Aufgabe bearbeiten', 'Editare sarcină');
  String get deleteTask => _t('Aufgabe löschen?', 'Ștergeți sarcina?');
  String taskDeleteConfirm(String desc) => _t('„$desc" wirklich löschen?', 'Ștergeți „$desc"?');
  String get markAsOpen => _t('Als offen markieren', 'Marchează ca deschis');
  String get markAsCompleted => _t('Als erledigt markieren', 'Marchează ca finalizat');
  String get newTask => _t('Neue Aufgabe', 'Sarcină nouă');
  String get descriptionRequired => _t('Beschreibung *', 'Descriere *');
  String get statusOpenNotar => _t('Offen', 'Deschis');
  String get statusCompletedNotar => _t('Erledigt', 'Finalizat');
  String get newPayment => _t('Neue Zahlung', 'Plată nouă');
  String get paymentType => _t('Zahlungsart', 'Tip plată');
  String get paymentTransfer => _t('Überweisung', 'Transfer');
  String get paymentCash => _t('Bar', 'Numerar');
  String get paymentDirectDebit => _t('Lastschrift', 'Debitare directă');
  String get paymentCard => _t('Karte', 'Card');
  String get purposeLabel => _t('Verwendungszweck', 'Scop plată');

  // ============================================================
  // NOTAR CARDS
  // ============================================================
  String get notarData => _t('Notardaten', 'Date notar');
  String get noDataAvailable => _t('Keine Daten', 'Fără date');
  String get invoicesTitle => _t('Rechnungen', 'Facturi');
  String invoicesSummary(int count, String total, int open) => _t(
    '$count Rechnungen • $total € • $open offen',
    '$count facturi • $total € • $open deschise',
  );
  String get addInvoice => _t('Rechnung hinzufügen', 'Adaugă factură');
  String get noInvoices => _t('Keine Rechnungen', 'Nicio factură');
  String get visitsTitle => _t('Besuche', 'Vizite');
  String visitsSummary(int count, int planned) => _t(
    '$count Besuche${planned > 0 ? ' • $planned geplant' : ''}',
    '$count vizite${planned > 0 ? ' • $planned planificate' : ''}',
  );
  String get addVisit => _t('Besuch hinzufügen', 'Adaugă vizită');
  String get noVisits => _t('Keine Besuche', 'Nicio vizită');
  String get documentsTitle => _t('Dokumente', 'Documente');
  String get addDocument => _t('Dokument hinzufügen', 'Adaugă document');
  String get noDocumentsNotar => _t('Keine Dokumente', 'Niciun document');
  String get tasksTitle => _t('Aufgaben', 'Sarcini');
  String tasksSummary(int count, int open) => _t(
    '$count Aufgaben${open > 0 ? ' • $open offen' : ''}',
    '$count sarcini${open > 0 ? ' • $open deschise' : ''}',
  );
  String get addTask => _t('Aufgabe hinzufügen', 'Adaugă sarcină');
  String get noTasks => _t('Keine Aufgaben', 'Nicio sarcină');
  String get paymentsTitle => _t('Zahlungen', 'Plăți');
  String paymentsSummary(int count, String total) => _t(
    '$count Zahlungen • $total €',
    '$count plăți • $total €',
  );
  String get addPayment => _t('Zahlung hinzufügen', 'Adaugă plată');
  String get noPayments => _t('Keine Zahlungen', 'Nicio plată');
  String get paymentLabel => _t('Zahlung', 'Plată');

  // ============================================================
  // TICKET DETAILS DIALOG
  // ============================================================
  String get detailsTab => _t('Details', 'Detalii');
  String get commentsTab => _t('Kommentare', 'Comentarii');
  String get documentsTabTicket => _t('Dokumente', 'Documente');
  String get timeTrackingTab => _t('Zeiterfassung', 'Înregistrare timp');
  String get historyTab => _t('Verlauf', 'Istoric');
  String get noCommentsYet => _t('Noch keine Kommentare', 'Niciun comentariu încă');
  String get writeFirstComment => _t('Schreiben Sie den ersten Kommentar', 'Scrieți primul comentariu');
  String get writeCommentHint => _t('Kommentar schreiben...', 'Scrieți un comentariu...');
  String get attachFile => _t('Datei anhängen', 'Atașați fișier');
  String get internalComment => _t('Interner Kommentar', 'Comentariu intern');
  String get onlyVisibleForAdmins => _t('Nur für Admins sichtbar', 'Vizibil doar pentru administratori');
  String get commentAdded => _t('Kommentar hinzugefügt', 'Comentariu adăugat');
  String get errorAddingComment => _t('Fehler beim Hinzufügen des Kommentars', 'Eroare la adăugarea comentariului');
  String get selectFiles => _t('Dateien auswählen', 'Selectați fișiere');
  String get max20FilesAllowed => _t('Maximal 20 Dateien gleichzeitig erlaubt', 'Maximum 20 fișiere simultan permise');
  String totalSizeExceeds(String size) => _t('Gesamtgröße $size MB überschreitet das Limit von 100 MB', 'Dimensiunea totală de $size MB depășește limita de 100 MB');
  String filesUploading(int uploaded, int total) => _t('Dateien werden hochgeladen... $uploaded/$total', 'Fișiere se încarcă... $uploaded/$total');
  String uploadResult(int uploaded, int failed) => _t(
    '$uploaded erfolgreich${failed > 0 ? ', $failed fehlgeschlagen' : ''}',
    '$uploaded cu succes${failed > 0 ? ', $failed eșuate' : ''}',
  );
  String filesUploadedSuccess(int count) => _t(
    '$count ${count == 1 ? 'Datei' : 'Dateien'} erfolgreich hochgeladen',
    '$count ${count == 1 ? 'fișier' : 'fișiere'} încărcat(e) cu succes',
  );
  String uploadedFailed(int uploaded, int failed) => _t('$uploaded hochgeladen, $failed fehlgeschlagen', '$uploaded încărcate, $failed eșuate');
  String get fileUploading => _t('Datei wird hochgeladen...', 'Fișierul se încarcă...');
  String fileUploaded(String name) => _t('Datei "$name" hochgeladen', 'Fișier "$name" încărcat');
  String get errorUploadingFile => _t('Fehler beim Hochladen der Datei', 'Eroare la încărcarea fișierului');
  String cameraNotAvailable(String msg) => _t('Kamera nicht verfügbar: $msg', 'Camera nu este disponibilă: $msg');
  String get originalMessage => _t('Ursprüngliche Nachricht:', 'Mesaj original:');
  String get showTranslation => _t('Übersetzung anzeigen', 'Afișează traducerea');
  String get showOriginal => _t('Original anzeigen', 'Afișează originalul');
  String get translationLabel => _t('Übersetzung', 'Traducere');
  String get originalLabel => _t('Original', 'Original');
  String get originalText => _t('Originaltext', 'Text original');
  String get autoTranslated => _t('Automatisch übersetzt', 'Tradus automat');
  String get createdDateLabel => _t('Erstellt', 'Creat');
  String get updatedDateLabel => _t('Aktualisiert', 'Actualizat');
  String get processorLabel2 => _t('Bearbeiter', 'Procesor');
  String get completedDateLabel => _t('Abgeschlossen', 'Finalizat');
  String get scheduledFor => _t('Geplant für:', 'Planificat pentru:');
  String get selectDate => _t('Datum wählen', 'Selectați data');
  String ticketScheduledFor(String date) => _t('Ticket geplant für $date', 'Tichet planificat pentru $date');
  String timeChangedTo(String time) => _t('Uhrzeit geändert auf $time', 'Ora schimbată la $time');
  String get assignTicket => _t('Übernehmen', 'Preia');
  String get waitingForUser => _t('Warten auf Benutzer', 'Așteptare utilizator');
  String get waitingForStaff => _t('Warten auf Mitarbeiter', 'Așteptare personal');
  String get waitingForAuthority2 => _t('Warten auf Behörde', 'Așteptare autoritate');
  String get waitingForDocuments => _t('Warten auf Unterlagen', 'Așteptare documente');
  String get reopenTicket => _t('Wiedereröffnen', 'Redeschide');
  String get noDocumentsTicket => _t('Keine Dokumente vorhanden', 'Niciun document disponibil');
  String get allowedFormats => _t('Erlaubte Formate: PDF, JPEG, JPG, TXT, ZIP', 'Formate permise: PDF, JPEG, JPG, TXT, ZIP');

  // Time Tracking (Ticket)
  String get deleteTimeEntry => _t('Zeiterfassung löschen', 'Șterge înregistrarea de timp');
  String timeEntryDeleteConfirm(String category, String duration) => _t(
    '$category: $duration wirklich löschen?',
    '$category: $duration ștergeți?',
  );
  String get manualTimeEntry => _t('Manuelle Zeiterfassung', 'Înregistrare manuală de timp');
  String get durationLabel => _t('Dauer', 'Durată');
  String get hoursLabel => _t('Stunden', 'Ore');
  String get minutesLabel => _t('Minuten', 'Minute');
  String get noteOptional => _t('Notiz (optional)', 'Notă (opțional)');
  String get minOneMinute => _t('Mindestens 1 Minute erforderlich', 'Cel puțin 1 minut necesar');
  String timeEntrySaved(String duration) => _t('Zeiterfassung gespeichert: $duration', 'Înregistrare de timp salvată: $duration');
  String get errorSavingTimeEntry => _t('Fehler beim Speichern der Zeiterfassung', 'Eroare la salvarea înregistrării de timp');
  String timerStarted(String category) => _t('Timer gestartet: $category', 'Cronometru pornit: $category');
  String get timerCouldNotStart => _t(
    'Timer konnte nicht gestartet werden. Möglicherweise läuft bereits ein Timer.',
    'Cronometrul nu a putut fi pornit. Posibil rulează deja un cronometru.',
  );
  String timerStopped(String duration) => _t('Timer gestoppt: $duration', 'Cronometru oprit: $duration');
  String get justNowShort => _t('Gerade eben', 'Chiar acum');
  String minAgo(int min) => _t('vor $min Min', 'acum $min min');
  String hoursAgoShort(int h) => _t('vor $h Std', 'acum $h ore');
  String daysAgoShort(int d) => _t('vor $d Tag${d > 1 ? 'en' : ''}', 'acum $d ${d > 1 ? 'zile' : 'zi'}');
  String get currentlyLabel => _t('Aktuell: ', 'Curent: ');
  String get timerLabel => _t('Timer', 'Cronometru');
  String startTimerCategory(String category) => _t('Timer starten ($category)', 'Pornește cronometru ($category)');
  String get stopLabel => _t('Stopp', 'Stop');
  String get addManually => _t('Manuell hinzufügen', 'Adaugă manual');
  String get noTimeEntriesYet => _t('Noch keine Zeiteinträge', 'Niciun înregistrare de timp încă');
  String get manualBadge => _t('Manuell', 'Manual');
  String get runningBadge => _t('Läuft', 'În curs');
  String get commentCopied => _t('Kommentar kopiert', 'Comentariu copiat');
  String get photoCouldNotBeTaken => _t('Foto konnte nicht aufgenommen werden', 'Fotografia nu a putut fi capturată');
  String cropFailed(String cause) => _t('Zuschnitt fehlgeschlagen: $cause', 'Decuparea a eșuat: $cause');
  String get selectCropArea => _t('Bereich zum Zuschneiden auswählen', 'Selectați zona de decupare');
  String get uploadThisPhoto => _t('Möchten Sie dieses Foto hochladen?', 'Doriți să încărcați această fotografie?');
  String get cropPhoto => _t('Foto zuschneiden', 'Decupare fotografie');
  String get skipLabelBtn => _t('Überspringen', 'Omite');
  String get cropLabel => _t('Zuschneiden', 'Decupează');
  String get discardLabel => _t('Verwerfen', 'Renunță');
  String get cropAgain => _t('Erneut zuschneiden', 'Decupează din nou');
  String get retakeLabel => _t('Wiederholen', 'Repetă');
  String get captureLabel => _t('Aufnehmen', 'Captură');
  String get historyLoading => _t('Verlauf wird geladen...', 'Istoricul se încarcă...');
  String get featureComingSoon => _t('Funktion wird bald verfügbar sein', 'Funcția va fi disponibilă în curând');
  String get errorOpeningFile => _t('Fehler beim Öffnen der Datei', 'Eroare la deschiderea fișierului');
  String get errorDownloadingFile => _t('Fehler beim Herunterladen der Datei', 'Eroare la descărcarea fișierului');
  String get fileDownloading => _t('Datei wird heruntergeladen...', 'Fișierul se descarcă...');
  String get originalTextTapTranslation => _t('Originaltext · Tippen für Übersetzung', 'Text original · Atingeți pentru traducere');
  String get translatedTapOriginal => _t('Übersetzt · Tippen für Original', 'Tradus · Atingeți pentru original');
  String get internBadge => _t('Intern', 'Intern');
  String get categoryLabelBold => _t('Kategorie', 'Categorie');
  String categoryWithName(String name) => _t('Kategorie: $name', 'Categorie: $name');

  // ============================================================
  // VEREINVERWALTUNG SCREEN
  // ============================================================
  String get vereinverwaltungTitle => _t('Vereinverwaltung', 'Administrarea asociației');
  String get authoritiesAndRegisters => _t('Behörden & Register', 'Autorități și registre');
  String get authoritiesSubtitle => _t('Handelsregister, Vereinsregister, Netzwerk', 'Registrul comerțului, Registrul asociațiilor, Rețea');
  String get partnersAndProviders => _t('Partner & Dienstleister', 'Parteneri și furnizori');
  String get partnersSubtitle => _t('Deutsche Post, Hetzner, INWX, IT-Beschaffung', 'Deutsche Post, Hetzner, INWX, Achiziții IT');
  String get notarTitle => _t('Notar', 'Notar');
  String get notarSubtitle => _t('Notarielle Dokumente, Termine, Rechnungen', 'Documente notariale, programări, facturi');
  String get banksTitle => _t('Banken', 'Bănci');
  String get banksSubtitle => _t('VR Bank, GLS Bank', 'VR Bank, GLS Bank');
  String get boardTitle => _t('Vorstand', 'Conducere');
  String get boardSubtitle => _t('Vorsitzender, Schatzmeister, Kassierer', 'Președinte, trezorier, casier');
  String get disciplinaryMeasures => _t('Ordnungsmaßnahmen', 'Măsuri disciplinare');
  String get disciplinarySubtitle => _t('Verwarnungen, Ordnungsgeld, Ausschluss (§6 Abs. 6)', 'Avertismente, amendă, excludere (§6 alin. 6)');
  String get backToOverview => _t('Zurück zur Übersicht', 'Înapoi la prezentare');
  String get backToPartner => _t('Zurück zu Partner', 'Înapoi la parteneri');
  String get backToITDesc => _t('Zurück zu IT-Beschaffung', 'Înapoi la achiziții IT');
  String get deutschePostTitle => _t('Deutsche Post', 'Deutsche Post');
  String get deutschePostSubtitle => _t('Sendungsverfolgung, Porto, Abholung', 'Urmărire colete, porto, ridicare');
  String get hetznerSubtitle => _t('Server, Cloud, Rechnungen', 'Server, cloud, facturi');
  String get inwxSubtitle => _t('Domain-Verwaltung, DNS, SSL', 'Administrare domeniu, DNS, SSL');
  String get itProcurementPlatform => _t('IT-Beschaffungsplattform', 'Platformă achiziții IT');
  String get itProcurementSubtitle => _t('Stifter-helfen.de - Software-Spenden', 'Stifter-helfen.de - donații software');
  String get vrBankSubtitle => _t('Kontostand, Überweisungen, Lastschriften', 'Sold, transferuri, debite directe');
  String get glsBankSubtitle => _t('Nachhaltige Bankgeschäfte', 'Operațiuni bancare sustenabile');
  String get noNotarData => _t('Keine Notar-Daten vorhanden', 'Nu există date notar');
  String get noBoardMembers => _t('Keine Vorstandsmitglieder gefunden', 'Niciun membru al conducerii găsit');
  String openTasksLabel(int count) => _t('$count offene Aufgaben', '$count sarcini deschise');
  String get openStifterHelfen => _t('Stifter-helfen.de öffnen', 'Deschide Stifter-helfen.de');
  String get hetznerServices => _t('Hetzner Services', 'Servicii Hetzner');
  String get inwxDomainServices => _t('INWX Domain-Services', 'Servicii domeniu INWX');
  String get softwareDonations => _t('Software-Spenden für gemeinnützige Organisationen', 'Donații software pentru organizații nonprofit');

  // ============================================================
  // HANDELSREGISTER SCREEN
  // ============================================================
  String get handelsregisterTitle => _t('Handelsregister', 'Registrul comerțului');
  String get searchLabel => _t('Suche', 'Căutare');
  String get registerArt => _t('Register-Art', 'Tip registru');
  String get registerNummer => _t('Registernummer', 'Număr de registru');
  String get registerGericht => _t('Registergericht', 'Tribunal de registru');
  String get schlagwoerter => _t('Schlagwörter', 'Cuvinte cheie');
  String get searchInProgress => _t('Suche läuft...', 'Căutare în curs...');
  String get searchButton => _t('Suchen', 'Caută');
  String get resultsTitle => _t('Ergebnisse', 'Rezultate');
  String hitsCount(int count) => _t('$count Treffer', '$count rezultate găsite');
  String get queryingRegister => _t('Handelsregister wird abgefragt...', 'Se interoghează registrul comerțului...');
  String get enterSearchCriteria => _t(
    'Geben Sie Suchkriterien ein\nund klicken Sie "Suchen"',
    'Introduceți criterii de căutare\nși faceți clic pe "Caută"',
  );
  String get noResultsFound => _t('Keine Ergebnisse gefunden', 'Niciun rezultat găsit');
  String get unexpectedResponse => _t('Unerwartete Antwort vom Server', 'Răspuns neașteptat de la server');
  String get queryFailed => _t('Abfrage fehlgeschlagen', 'Interogarea a eșuat');
  String get enterRegisterOrKeywords => _t('Bitte Registernummer oder Schlagwörter eingeben', 'Vă rugăm introduceți număr de registru sau cuvinte cheie');
  String get gerichtLabel => _t('Gericht', 'Tribunal');
  String get registerNr => _t('Register-Nr.', 'Nr. registru');
  String get bundeslandLabel => _t('Bundesland', 'Land federal');
  String get sitzLabel => _t('Sitz', 'Sediu');
  String get documentsLabel => _t('Dokumente', 'Documente');
  String get currentPrint => _t('Aktueller Abdruck', 'Extras actual');
  String get chronologicalPrint => _t('Chronologischer Abdruck', 'Extras cronologic');
  String get structuredContent => _t('Strukturierte Inhalte', 'Conținut structurat');
  String get documentBasket => _t('Dokumentenkorb', 'Coș documente');
  String get companyHolder => _t('Unternehmensträger', 'Titular întreprindere');
  String get publications => _t('Veröffentlichungen', 'Publicații');

  // ============================================================
  // VEREINREGISTER SCREEN
  // ============================================================
  String get vereinregisterTitle => _t('Vereinregister', 'Registrul asociațiilor');
  String get noVereinregisterData => _t('Keine Vereinregister-Daten vorhanden', 'Nu există date din registrul asociațiilor');
  String get vereinSettingsTitle => _t('Vereineinstellungen', 'Setări asociație');
  String get vereinsname => _t('Vereinsname *', 'Nume asociație *');
  String get addressRequired => _t('Adresse *', 'Adresă *');
  String get foundingDate => _t('Gründungsdatum', 'Data fondării');
  String get registerNumber => _t('Registernummer', 'Număr de registru');
  String get registerCourt => _t('Registergericht', 'Tribunal de registru');
  String get landlinePhone => _t('Telefon (Festnetz)', 'Telefon (fix)');
  String get mobilePhone => _t('Mobil', 'Mobil');
  String get vereinSettingsSaved => _t('Vereineinstellungen gespeichert', 'Setări asociație salvate');
  String get vereinsdatenTitle => _t('Vereinsdaten', 'Date asociație');
  String get addVereinsdaten => _t('Vereinsdaten hinzufügen', 'Adăugați date asociație');
  String get enterVereinsdaten => _t('Name, Adresse, Kontaktdaten des Vereins eintragen', 'Completați numele, adresa, datele de contact ale asociației');
  String get openWebsite => _t('Website öffnen', 'Deschide website-ul');
  String get foundingLabel => _t('Gründung', 'Fondare');

  // ============================================================
  // DEUTSCHE POST SCREEN
  // ============================================================
  String get sendungsverfolgung => _t('Sendungsverfolgung', 'Urmărire colet');
  String get sendungsverfolgungSubtitle => _t('DHL Pakete & Briefe verfolgen', 'Urmărire pachete și scrisori DHL');
  String get filialfinderTitle => _t('Filialfinder', 'Căutare filiale');
  String get filialfinderSubtitle => _t('Filialen, Packstationen & Briefkästen', 'Filiale, stații de pachete și cutii poștale');
  String get postcardTitle => _t('POSTCARD', 'POSTCARD');
  String get postcardSubtitle => _t('Geschäftskundenkarten verwalten', 'Administrare carduri clienți business');
  String get comingSoon => _t('Kommt bald', 'În curând');
  String get diensteUndPreise => _t('Dienste & Preise (2026)', 'Servicii și prețuri (2026)');
  String get postcardLabel => _t('Postkarte', 'Carte poștală');
  String get standardBrief => _t('Standardbrief', 'Scrisoare standard');
  String get kompaktBrief => _t('Kompaktbrief', 'Scrisoare compactă');
  String get grossBrief => _t('Großbrief', 'Scrisoare mare');
  String get maxiBrief => _t('Maxibrief', 'Scrisoare maxi');
  String get dhlParcel => _t('DHL Paket', 'Pachet DHL');
  String get intBrief => _t('Int. Brief', 'Scrisoare int.');
  String get postcardBusinessCard => _t('POSTCARD', 'POSTCARD');
  String get onlineFranking => _t('Online Frankierung', 'Francare online');
  String get postcardKarten => _t('POSTCARD Karten', 'Carduri POSTCARD');
  String get checkingStatus => _t('Prüfe...', 'Se verifică...');

  // ============================================================
  // WEBVIEW SCREEN
  // ============================================================
  String get backNav => _t('Zurück', 'Înapoi');
  String get forwardNav => _t('Vorwärts', 'Înainte');
  String get refreshNav => _t('Aktualisieren', 'Actualizează');
  String get homePage => _t('Startseite', 'Pagina principală');
  String get openInBrowser => _t('Im Browser öffnen', 'Deschide în browser');
  String get browserLoading => _t('Browser wird geladen...', 'Browserul se încarcă...');
  String get couldNotOpenBrowser => _t('Konnte Browser nicht öffnen', 'Nu s-a putut deschide browserul');

  // ============================================================
  // DASHBOARD - PAYMENT REMINDER BODY
  // ============================================================
  String paymentReminderBody(int zahlungstag, String methodLabel) => _t(
    'Heute ist der $zahlungstag. - bitte $methodLabel durchführen.',
    'Astăzi este $zahlungstag - vă rugăm efectuați $methodLabel.',
  );
  String atTime(String time) => _t(' um $time Uhr', ' la ora $time');

  // ============================================================
  // USER DETAILS DIALOG - STUFE NAMES (8 stages)
  // ============================================================
  String get stageFinancialSituation => _t('Finanzielle Situation', 'Situația financiară');
  String get stageMembershipStart => _t('Mitgliedschaftsbeginn', 'Începutul calității de membru');

  String stageNameExtended(int stufe) {
    switch (stufe) {
      case 1: return personalData;
      case 2: return membershipType;
      case 3: return stageFinancialSituation;
      case 4: return paymentMethod;
      case 5: return stageMembershipStart;
      case 6: return statute;
      case 7: return privacy;
      case 8: return withdrawalLabelFull;
      default: return _t('Stufe $stufe', 'Etapa $stufe');
    }
  }

  // ============================================================
  // USER DETAILS DIALOG - DOCUMENT TYPES
  // ============================================================
  String get docTypeApplicationForm => _t('Beitrittsantrag', 'Cerere de aderare');
  String get docTypeAdmissionConfirmation => _t('Aufnahmebestätigung', 'Confirmare de admitere');
  String get docTypeCancellation => _t('Kündigung', 'Reziliere');
  String get docTypeOther => _t('Sonstiges', 'Altele');
  String get docTypeHealthInsurance => _t('Krankenkasse', 'Asigurare de sănătate');
  String get docTypeTaxOffice => _t('Finanzamt', 'Oficiul fiscal');
  String get docTypeSocialInsurance => _t('Sozialversicherung', 'Asigurări sociale');
  String get docTypeEmploymentOffice => _t('Arbeitsamt', 'Oficiul de muncă');
  String get docTypeAdmissionShort => _t('Aufnahme', 'Admitere');
  String get docTypeSocialInsuranceShort => _t('Sozialvers.', 'Asig. soc.');

  // ============================================================
  // USER DETAILS DIALOG - FINANCIAL SITUATIONS
  // ============================================================
  String get citizenBenefit => _t('Bürgergeld', 'Ajutor social (Bürgergeld)');
  String get socialWelfareOffice => _t('Sozialamt', 'Oficiul de asistență socială');
  String get noSocialBenefits => _t('Keine Sozialleistungen', 'Fără prestații sociale');

  // ============================================================
  // USER DETAILS DIALOG - ASSISTANCE TYPES (DISCOUNT TAB)
  // ============================================================
  String get assistUnemploymentBenefit => _t('Arbeitslosengeld', 'Ajutor de șomaj');
  String get assistCitizenBenefit => _t('Bürgergeld', 'Ajutor social (Bürgergeld)');
  String get assistSocialWelfare => _t('Sozialhilfe', 'Asistență socială');
  String get assistBasicSecurity => _t('Grundsicherung', 'Securitate de bază');
  String get assistHousingBenefit => _t('Wohngeld', 'Ajutor pentru locuință');
  String get assistBafog => _t('BAföG', 'BAföG');
  String get assistTrainingAllowance => _t('Ausbildungsbeihilfe', 'Alocație de formare');
  String get assistChildSupplement => _t('Kinderzuschlag', 'Supliment pentru copii');
  String get assistPension => _t('Rente', 'Pensie');
  String get assistOther => _t('Sonstiges', 'Altele');

  // ============================================================
  // USER DETAILS DIALOG - DISCIPLINARY MEASURE FALLBACK
  // ============================================================
  String get disciplinaryMeasure => _t('Ordnungsmaßnahme', 'Măsură disciplinară');

  // ============================================================
  // USER DETAILS DIALOG - NOTE CATEGORY LABELS
  // ============================================================
  String get categoryGeneral => _t('Allgemein', 'General');
  String get categoryBehavior => _t('Verhalten', 'Comportament');
  String get categoryPayment => _t('Zahlung', 'Plată');
  String get categoryCommunication => _t('Kommunikation', 'Comunicare');
  String get categoryOtherNotes => _t('Sonstiges', 'Altele');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['de', 'ro'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
