import 'package:flutter/material.dart';

import '../services/language_service.dart';

class VrBankScreen extends StatelessWidget {
  final VoidCallback onBack;

  const VrBankScreen({super.key, required this.onBack});

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
              Icon(Icons.account_balance, size: 32, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Text(
                'VR Bank',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  tr('Vereinskonto', 'Cont de asociație'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Content - 2x2 grid
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
      color: Colors.blue,
      child: Column(
        children: [
          _infoRow(Icons.business, tr('Kontoinhaber', 'Titular cont'), 'ICD360S e.V.'),
          _infoRow(Icons.tag, 'IBAN', 'DE89 3704 0044 0532 0130 00'),
          _infoRow(Icons.code, 'BIC / SWIFT', 'COBADEFFXXX'),
          _infoRow(Icons.numbers, tr('Kontonummer', 'Număr de cont'), '0532013000'),
          _infoRow(Icons.pin, tr('Bankleitzahl (BLZ)', 'Cod bancar (BLZ)'), '370 400 44'),
          const Divider(height: 24),
          _infoRow(Icons.category, tr('Kontotyp', 'Tip de cont'),
              tr('Vereinskonto (Geschäftsgirokonto)', 'Cont de asociație (cont curent de afaceri)')),
          _infoRow(Icons.style, tr('Kontomodell', 'Model de cont'), 'VR-Giro Vereine'),
          _infoRow(Icons.location_on, tr('Filiale', 'Sucursală'), 'VR Bank Memmingen eG'),
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
      color: Colors.indigo,
      child: Column(
        children: [
          // Girocard
          _buildCardItem(
            icon: Icons.credit_card,
            name: tr('Girocard (Debitkarte)', 'Girocard (card de debit)'),
            netzwerk: 'V PAY',
            color: Colors.blue,
            details: [
              _cardDetail(tr('Karteninhaber', 'Titular card'), 'ICD360S e.V.'),
              _cardDetail(tr('Kartennummer', 'Număr card'), '**** **** **** 1234'),
              _cardDetail(tr('Gültig bis', 'Valabil până la'), '12/2028'),
              _cardDetail('Status', tr('Aktiv', 'Activ')),
              _cardDetail(tr('Kontaktlos', 'Contactless'), tr('Ja (NFC)', 'Da (NFC)')),
              _cardDetail(tr('Tageslimit', 'Limită zilnică'), '1.000,00 EUR'),
            ],
            features: [
              tr('Bargeldabhebung an 14.700 Geldautomaten', 'Retragere de numerar la 14.700 de bancomate'),
              tr('Bezahlung im Handel (kontaktlos / PIN)', 'Plată în magazine (contactless / PIN)'),
              tr('Kontoauszüge am Automaten drucken', 'Tipărirea extraselor de cont la automat'),
            ],
          ),
          const SizedBox(height: 16),
          // Mastercard Business
          _buildCardItem(
            icon: Icons.credit_score,
            name: 'Mastercard Business',
            netzwerk: tr('Kreditkarte', 'Card de credit'),
            color: Colors.orange,
            details: [
              _cardDetail(tr('Karteninhaber', 'Titular card'), 'ICD360S e.V.'),
              _cardDetail(tr('Kartennummer', 'Număr card'), '**** **** **** 5678'),
              _cardDetail(tr('Gültig bis', 'Valabil până la'), '06/2027'),
              _cardDetail('Status', tr('Aktiv', 'Activ')),
              _cardDetail(tr('Kreditrahmen', 'Limită de credit'), '5.000,00 EUR'),
            ],
            features: [
              tr('Online-Zahlungen weltweit', 'Plăți online în toată lumea'),
              tr('Auslandseinsatz (Reisekosten)', 'Utilizare în străinătate (cheltuieli de călătorie)'),
              tr('Abrechnung über Geschäftskonto', 'Decontare prin contul de afaceri'),
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
      color: Colors.teal,
      child: Column(
        children: [
          _buildFeatureItem(
            icon: Icons.send,
            title: tr('Überweisungen', 'Transferuri bancare'),
            subtitle: tr('SEPA-Einzelüberweisung, Sammelüberweisung', 'Transfer SEPA individual, transfer colectiv'),
            color: Colors.teal,
          ),
          _buildFeatureItem(
            icon: Icons.bolt,
            title: tr('Echtzeitüberweisung', 'Transfer instant'),
            subtitle: tr('Instant Payment — Geld in Sekunden beim Empfänger',
                'Instant Payment — banii ajung la destinatar în câteva secunde'),
            color: Colors.amber.shade700,
          ),
          _buildFeatureItem(
            icon: Icons.repeat,
            title: tr('Daueraufträge', 'Ordine permanente'),
            subtitle: tr('Regelmäßige Zahlungen (Miete, Versicherung, etc.)', 'Plăți regulate (chirie, asigurare etc.)'),
            color: Colors.blue,
          ),
          _buildFeatureItem(
            icon: Icons.receipt_long,
            title: tr('SEPA-Lastschriften', 'Debite directe SEPA'),
            subtitle: tr('Mitgliedsbeiträge automatisch einziehen (Basis-Lastschrift)',
                'Încasarea automată a cotizațiilor (debit direct de bază)'),
            color: Colors.purple,
          ),
          _buildFeatureItem(
            icon: Icons.upload_file,
            title: tr('SEPA-Dateiverarbeitung', 'Procesare fișiere SEPA'),
            subtitle: tr('Lohn-/Gehaltszahlungen per EBICS oder FinTS', 'Plata salariilor prin EBICS sau FinTS'),
            color: Colors.indigo,
          ),
          _buildFeatureItem(
            icon: Icons.visibility,
            title: tr('4-Augen-Prinzip', 'Principiul celor 4 ochi'),
            subtitle: tr('Auftragsfreigabe durch zweite Person (Firmenkunden)',
                'Aprobarea ordinelor de către o a doua persoană (clienți business)'),
            color: Colors.red.shade400,
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
      color: Colors.green,
      child: Column(
        children: [
          // Konditionen
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
          _konditionRow(tr('Kontoführung/Monat', 'Administrare cont/lună'), '4,90 EUR'),
          _konditionRow(tr('Girocard (erste)', 'Girocard (primul card)'), tr('Kostenlos', 'Gratuit')),
          _konditionRow(tr('Girocard (weitere)', 'Girocard (carduri suplimentare)'), tr('6,00 EUR/Jahr', '6,00 EUR/an')),
          _konditionRow('Mastercard Business', tr('30,00 EUR/Jahr', '30,00 EUR/an')),
          _konditionRow(tr('Buchungsposten', 'Comision per operațiune'), '0,10 - 0,20 EUR'),
          _konditionRow(tr('Kontoauszug (Online)', 'Extras de cont (online)'), tr('Kostenlos', 'Gratuit')),
          _konditionRow(tr('Kontoauszug (Papier)', 'Extras de cont (hârtie)'), tr('1,50 EUR/Stück', '1,50 EUR/bucată')),
          const Divider(height: 24),
          // Online-Banking
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
            title: 'VR Banking App',
            subtitle: tr('Kontoverwaltung mobil — Überweisungen, Umsätze, Push-TAN',
                'Administrare cont pe mobil — transferuri, tranzacții, Push-TAN'),
            color: Colors.blue,
          ),
          _buildFeatureItem(
            icon: Icons.computer,
            title: tr('Online-Banking (Browser)', 'Online banking (browser)'),
            subtitle: tr('Alle Funktionen im Webbrowser verfügbar', 'Toate funcțiile disponibile în browser'),
            color: Colors.green,
          ),
          _buildFeatureItem(
            icon: Icons.security,
            title: tr('TAN-Verfahren', 'Metode TAN'),
            subtitle: 'VR SecureGo plus (Push-TAN), SmartTAN',
            color: Colors.orange,
          ),
          _buildFeatureItem(
            icon: Icons.shield,
            title: tr('Überweisungslimit', 'Limită transferuri'),
            subtitle: tr('Tägliches Online-Limit individuell einstellbar', 'Limită online zilnică, reglabilă individual'),
            color: Colors.red.shade400,
          ),
          const Divider(height: 24),
          // Service-Netz
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tr('Service-Netz', 'Rețea de servicii'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          _infoRow(Icons.atm, tr('Geldautomaten', 'Bancomate'), tr('ca. 14.700 in Deutschland', 'cca. 14.700 în Germania')),
          _infoRow(Icons.print, tr('Kontoauszugsdrucker', 'Imprimante extrase de cont'),
              tr('ca. 14.000 bundesweit', 'cca. 14.000 în toată Germania')),
          _infoRow(Icons.support_agent, tr('Kundenservice', 'Serviciu clienți'),
              tr('Telefon, Filiale, Online', 'Telefon, sucursală, online')),
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(netzwerk, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
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
