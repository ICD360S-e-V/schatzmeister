import 'package:flutter/material.dart';

import '../services/language_service.dart';

class GlsBankScreen extends StatelessWidget {
  final VoidCallback onBack;

  const GlsBankScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
                tooltip: tr('Zurück zu Banken', 'Înapoi la bănci'),
              ),
              const SizedBox(width: 8),
              Icon(Icons.eco, size: 32, color: Colors.green.shade700),
              const SizedBox(width: 12),
              const Text(
                'GLS Bank',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.eco, size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      tr('Nachhaltige Bank', 'Bancă sustenabilă'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Content - 2x2 grid + Nachhaltigkeit row
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Row 1: Kontoinformationen + Karten
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildKontoinformationenCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildKartenCard()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Row 2: Zahlungsverkehr + Konditionen
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildZahlungsverkehrCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildKonditionenCard()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Row 3: Nachhaltigkeit (full width)
                  _buildNachhaltigkeitCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CARD 1: KONTOINFORMATIONEN ====================

  Widget _buildKontoinformationenCard() {
    return _buildSectionCard(
      icon: Icons.account_balance_wallet,
      title: tr('Kontoinformationen', 'Informații cont'),
      color: Colors.green,
      child: Column(
        children: [
          _infoRow(Icons.business, tr('Kontoinhaber', 'Titular cont'), 'ICD360S e.V.'),
          _infoRow(Icons.tag, 'IBAN', 'DE12 4306 0967 1234 5678 00'),
          _infoRow(Icons.code, 'BIC / SWIFT', 'GENODEM1GLS'),
          _infoRow(Icons.numbers, tr('Kontonummer', 'Număr de cont'), '1234567800'),
          _infoRow(Icons.pin, tr('Bankleitzahl (BLZ)', 'Cod bancar (BLZ)'), '430 609 67'),
          const Divider(height: 24),
          _infoRow(Icons.category, tr('Kontotyp', 'Tip de cont'),
              tr('Konto für Gemeinnützige', 'Cont pentru organizații nonprofit (gemeinnützig)')),
          _infoRow(Icons.style, tr('Kontomodell', 'Model de cont'), 'GLS Vereinskonto'),
          _infoRow(Icons.location_on, tr('Hauptsitz', 'Sediu central'), 'GLS Bank, Bochum'),
          _infoRow(Icons.calendar_today, tr('Eröffnet am', 'Data deschiderii'), '—'),
          _infoRow(Icons.verified_user, tr('Kontostand', 'Sold cont'), '—'),
        ],
      ),
    );
  }

  // ==================== CARD 2: KARTEN ====================

  Widget _buildKartenCard() {
    return _buildSectionCard(
      icon: Icons.credit_card,
      title: tr('Karten', 'Carduri'),
      color: Colors.teal,
      child: Column(
        children: [
          // GLS BankCard
          _buildCardItem(
            icon: Icons.credit_card,
            name: 'GLS BankCard (Girocard)',
            netzwerk: 'Debit Mastercard',
            color: Colors.green,
            material: tr('Kartenkörper: 100% aus Holz', 'Corpul cardului: 100% lemn'),
            details: [
              _cardDetail(tr('Karteninhaber', 'Titular card'), 'ICD360S e.V.'),
              _cardDetail(tr('Kartennummer', 'Număr card'), '**** **** **** 9012'),
              _cardDetail(tr('Gültig bis', 'Valabil până la'), '09/2028'),
              _cardDetail('Status', tr('Aktiv', 'Activ')),
              _cardDetail(tr('Kontaktlos', 'Contactless'), tr('Ja (NFC)', 'Da (NFC)')),
            ],
            features: [
              tr('Kostenlos Bargeld an 15.000 Automaten (ServiceNetz)', 'Numerar gratuit la 15.000 de bancomate (ServiceNetz)'),
              tr('Kontaktlos bezahlen im Handel', 'Plată contactless în magazine'),
              tr('Weltweit einsetzbar (Debit Mastercard)', 'Utilizabil în toată lumea (Debit Mastercard)'),
            ],
          ),
          const SizedBox(height: 16),
          // GLS BusinessCard
          _buildCardItem(
            icon: Icons.credit_score,
            name: 'GLS BusinessCard',
            netzwerk: tr('Kreditkarte (Mastercard)', 'Card de credit (Mastercard)'),
            color: Colors.teal,
            material: tr('75% bio-basierte Rohstoffe', '75% materii prime biobazate'),
            details: [
              _cardDetail(tr('Karteninhaber', 'Titular card'), 'ICD360S e.V.'),
              _cardDetail(tr('Kartennummer', 'Număr card'), '**** **** **** 3456'),
              _cardDetail(tr('Gültig bis', 'Valabil până la'), '03/2027'),
              _cardDetail('Status', tr('Aktiv', 'Activ')),
              _cardDetail(tr('Kreditrahmen', 'Limită de credit'), '5.000,00 EUR'),
            ],
            features: [
              tr('Online-Zahlungen weltweit', 'Plăți online în toată lumea'),
              tr('Dienstreisen & Geschäftsausgaben', 'Deplasări de serviciu și cheltuieli de afaceri'),
              tr('Abrechnung über GLS Geschäftskonto', 'Decontare prin contul de afaceri GLS'),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== CARD 3: ZAHLUNGSVERKEHR ====================

  Widget _buildZahlungsverkehrCard() {
    return _buildSectionCard(
      icon: Icons.swap_horiz,
      title: tr('Zahlungsverkehr', 'Operațiuni de plată'),
      color: Colors.blue,
      child: Column(
        children: [
          _buildFeatureItem(
            icon: Icons.send,
            title: tr('Überweisungen', 'Transferuri bancare'),
            subtitle: tr('SEPA-Einzelüberweisung, Sammelüberweisung', 'Transfer SEPA individual, transfer colectiv'),
            color: Colors.blue,
          ),
          _buildFeatureItem(
            icon: Icons.bolt,
            title: tr('Echtzeitüberweisung', 'Transfer instant'),
            subtitle: tr('Instant Payment — sofortige Gutschrift', 'Instant Payment — creditare imediată'),
            color: Colors.amber.shade700,
          ),
          _buildFeatureItem(
            icon: Icons.repeat,
            title: tr('Daueraufträge', 'Ordine permanente'),
            subtitle: tr('Regelmäßige Zahlungen automatisch ausführen', 'Plăți regulate executate automat'),
            color: Colors.teal,
          ),
          _buildFeatureItem(
            icon: Icons.receipt_long,
            title: tr('SEPA-Lastschriften', 'Debite directe SEPA'),
            subtitle: tr('Mitgliedsbeiträge automatisch einziehen', 'Încasarea automată a cotizațiilor'),
            color: Colors.purple,
          ),
          _buildFeatureItem(
            icon: Icons.public,
            title: tr('Internationale Überweisungen', 'Transferuri internaționale'),
            subtitle: tr('Zahlungen außerhalb des SEPA-Raums', 'Plăți în afara spațiului SEPA'),
            color: Colors.indigo,
          ),
          _buildFeatureItem(
            icon: Icons.integration_instructions,
            title: tr('DATEV-Anbindung', 'Conectare DATEV'),
            subtitle: tr('Direkte Verbindung zum Steuerberater', 'Legătură directă cu consultantul fiscal'),
            color: Colors.green.shade700,
          ),
        ],
      ),
    );
  }

  // ==================== CARD 4: KONDITIONEN ====================

  Widget _buildKonditionenCard() {
    return _buildSectionCard(
      icon: Icons.euro,
      title: tr('Konditionen & Online-Banking', 'Condiții și online banking'),
      color: Colors.orange,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tr('Kontogebühren', 'Comisioane cont'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          _konditionRow(tr('GLS Beitrag (jährlich)', 'Contribuție GLS (anuală)'), '60,00 EUR'),
          _konditionRow(tr('GLS Mitgliedschaft', 'Calitate de membru GLS'), tr('5,00 EUR/Monat', '5,00 EUR/lună')),
          _konditionRow(tr('Kontoführung/Monat', 'Administrare cont/lună'), '8,80 EUR'),
          _konditionRow(tr('GLS BankCard (erste)', 'GLS BankCard (primul card)'), tr('Kostenlos', 'Gratuit')),
          _konditionRow(tr('GLS BankCard (weitere)', 'GLS BankCard (carduri suplimentare)'), tr('15,00 EUR/Jahr', '15,00 EUR/an')),
          _konditionRow('GLS BusinessCard', tr('30,00 EUR/Jahr', '30,00 EUR/an')),
          _konditionRow(tr('Buchungsposten', 'Comision per operațiune'), '0,08 EUR'),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tr('Online-Banking', 'Online banking'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          _buildFeatureItem(
            icon: Icons.phone_android,
            title: 'GLS Banking App',
            subtitle: tr('Kontoverwaltung mobil — Push-TAN, Umsätze', 'Administrare cont pe mobil — Push-TAN, tranzacții'),
            color: Colors.green,
          ),
          _buildFeatureItem(
            icon: Icons.computer,
            title: tr('Online-Banking (Browser)', 'Online banking (browser)'),
            subtitle: tr('Multi-Bank-fähig — alle Konten in einer Übersicht', 'Multi-bancă — toate conturile la un loc'),
            color: Colors.blue,
          ),
          _buildFeatureItem(
            icon: Icons.security,
            title: tr('TAN-Verfahren', 'Metode TAN'),
            subtitle: 'SecureGo plus, SmartTAN (chipTAN)',
            color: Colors.orange,
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tr('Einlagensicherung', 'Garantarea depozitelor'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          _infoRow(Icons.shield, tr('Gesetzlich', 'Garanție legală'), tr('bis 100.000 EUR (EU)', 'până la 100.000 EUR (UE)')),
          _infoRow(Icons.security, tr('Genossenschaftlich', 'Garanție cooperatistă'),
              tr('BVR Sicherungssystem (unbegrenzt)', 'Sistemul de garantare BVR (nelimitat)')),
        ],
      ),
    );
  }

  // ==================== CARD 5: NACHHALTIGKEIT ====================

  Widget _buildNachhaltigkeitCard() {
    return _buildSectionCard(
      icon: Icons.eco,
      title: tr('Nachhaltigkeit — Wohin fließt Ihr Geld?', 'Sustenabilitate — unde merg banii dumneavoastră?'),
      color: Colors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
                'Die GLS Bank finanziert ausschließlich sozial-ökologische Unternehmen und Projekte. '
                'Als Kontoinhaber können Sie mitentscheiden, in welchem Bereich Ihr Geld wirkt:',
                'Banca GLS finanțează exclusiv companii și proiecte social-ecologice. '
                'Ca titular de cont, puteți alege în ce domeniu sunt folosiți banii dumneavoastră:'),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _nachhaltigkeitItem(Icons.wind_power, tr('Erneuerbare Energien', 'Energii regenerabile'), tr('Windkraft, Solar, Biogas', 'Eoliană, solară, biogaz'), Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _nachhaltigkeitItem(Icons.home, tr('Wohnen', 'Locuințe'), tr('Soziales Wohnen, Baugruppen', 'Locuințe sociale, construcții în comun'), Colors.brown)),
              const SizedBox(width: 12),
              Expanded(child: _nachhaltigkeitItem(Icons.health_and_safety, tr('Soziales & Gesundheit', 'Social și sănătate'), tr('Pflege, Inklusion, Therapie', 'Îngrijire, incluziune, terapie'), Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _nachhaltigkeitItem(Icons.store, tr('Nachhaltige Wirtschaft', 'Economie sustenabilă'), tr('Bio, Naturkosmetik, Textilien', 'Bio, cosmetice naturale, textile'), Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _nachhaltigkeitItem(Icons.school, tr('Bildung & Kultur', 'Educație și cultură'), tr('Schulen, Kunst, Medien', 'Școli, artă, media'), Colors.purple)),
              const SizedBox(width: 12),
              Expanded(child: _nachhaltigkeitItem(Icons.restaurant, tr('Ernährung', 'Alimentație'), tr('Bio-Landwirtschaft, Hofläden', 'Agricultură bio, magazine de fermă'), Colors.orange)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.block, size: 18, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('Kein Geld fließt in: Kinderarbeit, Atomenergie, Rüstungsindustrie, Agrochemie',
                        'Niciun ban nu ajunge în: munca copiilor, energia nucleară, industria armamentului, agrochimie'),
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nachhaltigkeitItem(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem({
    required IconData icon,
    required String name,
    required String netzwerk,
    required Color color,
    required String material,
    required List<Widget> details,
    required List<String> features,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(netzwerk, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Material badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco, size: 12, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(material, style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Card details
          ...details,
          if (features.isNotEmpty) ...[
            const Divider(height: 20),
            Text(tr('Funktionen', 'Funcții'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _cardDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _konditionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
