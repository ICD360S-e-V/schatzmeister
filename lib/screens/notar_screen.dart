import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../widgets/notar_cards.dart';
import '../widgets/notar_dialogs.dart';

class NotarScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onBack;

  const NotarScreen({
    super.key,
    required this.apiService,
    required this.onBack,
  });

  @override
  State<NotarScreen> createState() => _NotarScreenState();
}

class _NotarScreenState extends State<NotarScreen> {
  Map<String, dynamic>? _notarData;
  bool _isLoadingNotar = true;
  List<Map<String, dynamic>> _notarRechnungen = [];
  List<Map<String, dynamic>> _notarBesuche = [];
  List<Map<String, dynamic>> _notarDokumente = [];
  List<Map<String, dynamic>> _notarZahlungen = [];
  List<Map<String, dynamic>> _notarAufgaben = [];
  bool _isLoadingNotarDetails = true;

  @override
  void initState() {
    super.initState();
    _loadNotarData();
  }

  Future<void> _loadNotarData() async {
    setState(() {
      _isLoadingNotar = true;
      _isLoadingNotarDetails = true;
    });
    try {
      final result = await widget.apiService.getVereinverwaltung(kategorie: 'notar');
      if (mounted && result['success'] == true) {
        final data = result['data'] as List?;
        if (data != null && data.isNotEmpty) {
          setState(() {
            _notarData = data[0];
            _isLoadingNotar = false;
          });
          _loadNotarDetails(data[0]['id']);
        } else {
          setState(() {
            _notarData = null;
            _isLoadingNotar = false;
            _isLoadingNotarDetails = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNotar = false;
          _isLoadingNotarDetails = false;
        });
      }
    }
  }

  Future<void> _loadNotarDetails(int notarId) async {
    setState(() => _isLoadingNotarDetails = true);
    try {
      final results = await Future.wait([
        widget.apiService.getNotarRechnungen(notarId: notarId),
        widget.apiService.getNotarBesuche(notarId: notarId),
        widget.apiService.getNotarDokumente(notarId: notarId),
        widget.apiService.getNotarZahlungen(notarId: notarId),
        widget.apiService.getNotarAufgaben(notarId: notarId),
      ]);
      if (mounted) {
        setState(() {
          _notarRechnungen = List<Map<String, dynamic>>.from(
              results[0]['success'] == true ? (results[0]['data'] ?? []) : []);
          _notarBesuche = List<Map<String, dynamic>>.from(
              results[1]['success'] == true ? (results[1]['data'] ?? []) : []);
          _notarDokumente = List<Map<String, dynamic>>.from(
              results[2]['success'] == true ? (results[2]['data'] ?? []) : []);
          _notarZahlungen = List<Map<String, dynamic>>.from(
              results[3]['success'] == true ? (results[3]['data'] ?? []) : []);
          _notarAufgaben = List<Map<String, dynamic>>.from(
              results[4]['success'] == true ? (results[4]['data'] ?? []) : []);
          _isLoadingNotarDetails = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNotarDetails = false);
    }
  }

  Future<void> _handleEditNotar() async {
    final data = _notarData;
    if (data == null) return;

    final success = await showEditNotarDialog(
      context: context,
      data: data,
      apiService: widget.apiService,
    );

    if (success && mounted) {
      _loadNotarData();
    }
  }

  Future<void> _handleAddRechnung() async {
    final notarId = _notarData?['id'];
    if (notarId == null) return;

    final success = await showAddRechnungDialog(
      context: context,
      notarId: notarId,
      apiService: widget.apiService,
    );

    if (success && mounted) {
      _loadNotarDetails(notarId);
    }
  }

  Future<void> _handleAddBesuch() async {
    final notarId = _notarData?['id'];
    if (notarId == null) return;

    final success = await showAddBesuchDialog(
      context: context,
      notarId: notarId,
      apiService: widget.apiService,
    );

    if (success && mounted) {
      _loadNotarDetails(notarId);
    }
  }

  Future<void> _handleAddDokument() async {
    final notarId = _notarData?['id'];
    if (notarId == null) return;

    final success = await showAddDokumentDialog(
      context: context,
      notarId: notarId,
      apiService: widget.apiService,
    );

    if (success && mounted) {
      _loadNotarDetails(notarId);
    }
  }

  Future<void> _handleAddZahlung() async {
    final notarId = _notarData?['id'];
    if (notarId == null) return;

    final success = await showAddZahlungDialog(
      context: context,
      notarId: notarId,
      apiService: widget.apiService,
    );

    if (success && mounted) {
      _loadNotarDetails(notarId);
    }
  }

  Future<void> _handleAddAufgabe() async {
    final notarId = _notarData?['id'];
    if (notarId == null) return;

    final success = await showAddAufgabeDialog(
      context: context,
      notarId: notarId,
      apiService: widget.apiService,
    );

    if (success && mounted) {
      _loadNotarDetails(notarId);
    }
  }

  Future<void> _handleAufgabeTap(Map<String, dynamic> aufgabe) async {
    final notarId = _notarData?['id'];
    if (notarId == null) return;

    final success = await showAufgabeDetailDialog(
      context: context,
      aufgabe: aufgabe,
      apiService: widget.apiService,
    );

    if (success && mounted) {
      _loadNotarDetails(notarId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Entschieden wird nach der Breite, die der Bildschirm wirklich bekommt
    // (auf dem Schreibtisch nimmt die Seitenleiste ihren Teil), nicht nach
    // MediaQuery.
    return LayoutBuilder(
      builder: (context, constraints) => _aufbau(breite: constraints.maxWidth),
    );
  }

  Widget _aufbau({required double breite}) {
    final schmal = breite < 600;
    final karten = [
      NotarDataCard(
        data: _notarData,
        onEdit: _handleEditNotar,
      ),
      NotarRechnungenCard(
        rechnungen: _notarRechnungen,
        isLoading: _isLoadingNotarDetails,
        onAdd: _handleAddRechnung,
      ),
      NotarBesucheCard(
        besuche: _notarBesuche,
        isLoading: _isLoadingNotarDetails,
        onAdd: _handleAddBesuch,
      ),
      NotarDokumenteCard(
        dokumente: _notarDokumente,
        isLoading: _isLoadingNotarDetails,
        onAdd: _handleAddDokument,
      ),
      NotarZahlungenCard(
        zahlungen: _notarZahlungen,
        isLoading: _isLoadingNotarDetails,
        onAdd: _handleAddZahlung,
      ),
      NotarAufgabenCard(
        aufgaben: _notarAufgaben,
        isLoading: _isLoadingNotarDetails,
        onAdd: _handleAddAufgabe,
        onTap: _handleAufgabeTap,
      ),
    ];
    return Padding(
      padding: EdgeInsets.all(schmal ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: tr('Zurück', 'Înapoi'),
              ),
              const SizedBox(width: 8),
              Icon(Icons.gavel, size: 32, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              const Text(
                'Notar',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: schmal ? 16 : 24),
          // Content - 2 rows with 3 cards each
          Expanded(
            child: _isLoadingNotar
                ? const Center(child: CircularProgressIndicator())
                : breite < 900
                    ? _kartenRollbar(karten, spalten: schmal ? 1 : 2)
                    : Column(
                        children: [
                          // Row 1: Notardaten, Rechnungen, Besuche
                          Expanded(
                            flex: 1,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: karten[0]),
                                const SizedBox(width: 16),
                                Expanded(child: karten[1]),
                                const SizedBox(width: 16),
                                Expanded(child: karten[2]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Row 2: Dokumente, Zahlungen
                          Expanded(
                            flex: 1,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: karten[3]),
                                const SizedBox(width: 16),
                                Expanded(child: karten[4]),
                                const SizedBox(width: 16),
                                Expanded(child: karten[5]),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  /// Unter 900 dp: die sechs Karten untereinander (Telefon) oder zu zweit
  /// (Tablet), jede gleich hoch, und die Seite rollt. Drei Karten
  /// nebeneinander ließen auf dem Telefon je ~100 dp — Namen, Rechnungen
  /// und Termine waren nicht mehr zu lesen. Die Karten brauchen eine feste
  /// Höhe: ihre Listen füllen den Rest der Karte aus.
  Widget _kartenRollbar(List<Widget> karten, {required int spalten}) {
    const hoehe = 320.0;
    return ListView(
      children: [
        for (var i = 0; i < karten.length; i += spalten)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: hoehe,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + spalten && j < karten.length; j++) ...[
                    if (j > i) const SizedBox(width: 16),
                    Expanded(child: karten[j]),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
