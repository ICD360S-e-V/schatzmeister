import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../l10n/app_localizations.dart';
import '../services/language_service.dart';
import '../services/termin_service.dart';
import '../services/api_service.dart';

/// CustomPainter for diagonal stripes (past time slots)
class _DiagonalStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw diagonal lines from top-left to bottom-right
    const gap = 6.0;
    for (double i = -size.height; i < size.width + size.height; i += gap + 1.0) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Was an einem Tag der Woche anliegt — einmal berechnet, im Wochenraster
/// (Spalte) und in der Tagesliste (Karte) gleich dargestellt.
class _TagDaten {
  const _TagDaten({
    required this.tag,
    required this.heute,
    required this.wochenende,
    required this.termine,
    required this.urlaub,
    required this.feiertag,
  });

  final DateTime tag;
  final bool heute;
  final bool wochenende;
  final List<Termin> termine;
  final bool urlaub;
  final String? feiertag;
}

class TerminverwaltungScreen extends StatefulWidget {
  final String currentMitgliedernummer;

  const TerminverwaltungScreen({
    super.key,
    required this.currentMitgliedernummer,
  });

  @override
  State<TerminverwaltungScreen> createState() => _TerminverwaltungScreenState();
}

class _TerminverwaltungScreenState extends State<TerminverwaltungScreen> {
  final _terminService = TerminService();
  final _apiService = ApiService();

  List<Termin> _termine = [];
  List<Map<String, dynamic>> _urlaub = [];
  List<Map<String, dynamic>> _feiertage = [];
  bool _isLoadingTermine = false;
  DateTime _currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  String _selectedBundesland = 'ALL';
  Timer? _refreshTimer;

  static const Map<String, String> _bundeslaender = {
    'BW': 'Baden-Württemberg',
    'BY': 'Bayern',
    'BE': 'Berlin',
    'BB': 'Brandenburg',
    'HB': 'Bremen',
    'HH': 'Hamburg',
    'HE': 'Hessen',
    'MV': 'Mecklenburg-Vorpommern',
    'NI': 'Niedersachsen',
    'NW': 'Nordrhein-Westfalen',
    'RP': 'Rheinland-Pfalz',
    'SL': 'Saarland',
    'SN': 'Sachsen',
    'ST': 'Sachsen-Anhalt',
    'SH': 'Schleswig-Holstein',
    'TH': 'Thüringen',
  };

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('de_DE', null);
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadTermine();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    _terminService.setToken(_apiService.token);
    await _loadTermine();
  }

  Future<void> _loadTermine() async {
    setState(() => _isLoadingTermine = true);

    _terminService.setToken(_apiService.token);

    final weekEnd = _currentWeekStart.add(const Duration(days: 6));

    final List<Map<String, dynamic>> results;
    try {
      results = await Future.wait([
        _terminService.getMyTermine(filter: 'all', from: _currentWeekStart, to: weekEnd),
        _terminService.getUrlaub(from: _currentWeekStart, to: weekEnd),
        _terminService.getFeiertage(
          from: _currentWeekStart,
          to: weekEnd,
          bundesland: _selectedBundesland,
        ),
      ]);
    } catch (_) {
      // Server nicht erreichbar oder Antwort kein JSON (TerminService fängt
      // das nicht ab): wie bei success != true die Ladeanzeige beenden,
      // statt mit einer unbehandelten Ausnahme ewig weiterzudrehen.
      if (mounted) setState(() => _isLoadingTermine = false);
      return;
    }

    final termineResult = results[0];
    final urlaubResult = results[1];
    final feiertageResult = results[2];

    if (mounted && termineResult['success'] == true) {
      final termineList = termineResult['termine'] as List;
      final urlaubList = urlaubResult['success'] == true ? (urlaubResult['urlaub'] as List) : [];
      final feiertageList = feiertageResult['success'] == true ? (feiertageResult['feiertage'] as List) : [];

      setState(() {
        _termine = termineList.map((t) => Termin.fromJson(t)).toList();
        _urlaub = urlaubList.cast<Map<String, dynamic>>();
        _feiertage = feiertageList.cast<Map<String, dynamic>>();
        _isLoadingTermine = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingTermine = false);
    }
  }

  Map<String, String> _getBundeslaenderMap(AppLocalizations l) {
    return {
      'ALL': l.onlyNational,
      ..._bundeslaender,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dayOfYear = int.parse(DateFormat('D').format(_currentWeekStart));
    final weekNumber = ((dayOfYear - _currentWeekStart.weekday + 10) / 7).floor();
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));
    // Monatsname in der gewählten Sprache; rumänisch ohne Punkt nach dem Tag.
    final weekRange = '${DateFormat(tr('dd.', 'dd')).format(_currentWeekStart)} - ${DateFormat(tr('dd. MMMM yyyy', 'dd MMMM yyyy'), tr('de_DE', 'ro')).format(weekEnd)}';

    // Build holidays map from API data
    final holidays = <String, String>{};
    for (final f in _feiertage) {
      holidays[f['datum']] = f['name'];
    }

    final bundeslaenderMap = _getBundeslaenderMap(l);
    final wochenText = '${tr('KW', 'Săpt.')} $weekNumber • $weekRange';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appointmentManagement),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      // Entscheidend ist die Breite, die der Bildschirm wirklich bekommt (am
      // Schreibtisch nimmt die Seitenleiste einen Teil weg). Ab 900 dp
      // bleiben die sieben Tagesspalten wie bisher. Schmaler stehen die Tage
      // untereinander: auf dem Telefon wären die Spalten keine 50 dp breit,
      // auf dem Tablet brächen Titel wie „Vorstandssitzung“ mitten im Wort.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final telefon = constraints.maxWidth < 600;
          final rand = telefon ? 12.0 : 24.0;
          final raster = constraints.maxWidth >= 900;
          return Padding(
            padding: EdgeInsets.all(rand),
            child: Column(
              children: [
                // Header with navigation
                if (telefon)
                  _kopfTelefon(l, wochenText, bundeslaenderMap)
                else
                  _kopfBreit(l, wochenText, bundeslaenderMap),
                SizedBox(height: telefon ? 12 : 16),
                // Weekly Calendar Grid
                Expanded(
                  child: _isLoadingTermine
                      ? const Center(child: CircularProgressIndicator())
                      : raster
                          ? _wochenRaster(l, holidays)
                          : _tagesListe(l, holidays),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Tablet und Schreibtisch: Titel links, Woche und Bundesland rechts —
  /// wie bisher in einer Zeile, solange sie reicht (rumänisch braucht dafür
  /// rund 1000 dp, mehr als ein Fenster neben der Seitenleiste hat). Sonst
  /// rutscht der rechte Teil in die nächste Zeile und bricht dort bei Bedarf
  /// noch einmal um, statt überzulaufen.
  Widget _kopfBreit(AppLocalizations l, String wochenText, Map<String, String> bundeslaenderMap) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month, size: 32, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Flexible(child: _titel(l)),
            ],
          ),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [_wocheZurueck(l), _wochenAnzeige(wochenText), _wocheVor(l)],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [_bundeslandAuswahl(bundeslaenderMap), const SizedBox(width: 8), _aktualisierenKnopf(l)],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Telefon: Titel, Woche und Bundesland untereinander, je in voller Breite.
  Widget _kopfTelefon(AppLocalizations l, String wochenText, Map<String, String> bundeslaenderMap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month, size: 32, color: Colors.green.shade700),
            const SizedBox(width: 12),
            Expanded(child: _titel(l, maxLines: 2)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _wocheZurueck(l),
            Expanded(child: _wochenAnzeige(wochenText, zentriert: true)),
            _wocheVor(l),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _bundeslandAuswahl(bundeslaenderMap, fuellen: true)),
            const SizedBox(width: 8),
            _aktualisierenKnopf(l),
          ],
        ),
      ],
    );
  }

  Widget _titel(AppLocalizations l, {int maxLines = 1}) {
    return Text(
      l.appointmentManagement,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _wocheZurueck(AppLocalizations l) {
    return IconButton(
      icon: const Icon(Icons.chevron_left),
      onPressed: () {
        setState(() {
          _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
        });
        _loadTermine();
      },
      tooltip: l.previousWeek,
    );
  }

  /// [zentriert]: auf dem Telefon füllt die Anzeige die Zeile zwischen den
  /// Pfeilen und bricht bei Bedarf in eine zweite Zeile um.
  Widget _wochenAnzeige(String wochenText, {bool zentriert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        wochenText,
        textAlign: zentriert ? TextAlign.center : null,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
      ),
    );
  }

  Widget _wocheVor(AppLocalizations l) {
    return IconButton(
      icon: const Icon(Icons.chevron_right),
      onPressed: () {
        setState(() {
          _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
        });
        _loadTermine();
      },
      tooltip: l.nextWeekNav,
    );
  }

  /// Bundesland dropdown for regional holidays. [fuellen]: auf dem Telefon
  /// über die ganze Zeile, ein zu langer Name endet dann mit „…“.
  Widget _bundeslandAuswahl(Map<String, String> bundeslaenderMap, {bool fuellen = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBundesland,
          isExpanded: fuellen,
          icon: Icon(Icons.flag, size: 16, color: Colors.indigo.shade700),
          style: TextStyle(fontSize: 13, color: Colors.indigo.shade900),
          items: bundeslaenderMap.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedBundesland = val);
              _loadTermine();
            }
          },
        ),
      ),
    );
  }

  Widget _aktualisierenKnopf(AppLocalizations l) {
    return IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: _loadTermine,
      tooltip: l.refresh,
    );
  }

  List<String> _wochentage(AppLocalizations l) =>
      [l.monday, l.tuesday, l.wednesday, l.thursday, l.friday, l.saturday, l.sunday];

  /// Sieben Tagesspalten nebeneinander (Schreibtisch) — wie bisher.
  Widget _wochenRaster(AppLocalizations l, Map<String, String> holidays) {
    return Card(
      child: Column(
        children: [
          // Week days header
          Container(
            color: Colors.grey.shade100,
            child: Row(
              children: _wochentage(l)
                  .map((day) => Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Text(
                            day,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          // Week days grid
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(7, (dayIndex) {
                final tag = _tagDaten(dayIndex, holidays);

                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _tagFarbe(tag),
                      border: Border(
                        right: BorderSide(color: Colors.grey.shade300),
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Column(
                      children: [
                        _datumsFeld(tag),
                        Expanded(
                          child: tag.feiertag != null
                              ? _feiertagHinweis(l, tag.feiertag!)
                              : tag.urlaub
                                  ? _urlaubHinweis(l)
                                  : ListView(
                                      padding: const EdgeInsets.all(4),
                                      children: _zeitfenster(l, tag),
                                    ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// Telefon und Tablet: die Tage untereinander, jeder als Karte
  /// mit seinen Zeitfenstern in voller Breite. Die Liste merkt sich, wie
  /// weit gerollt ist (PageStorageKey): das Nachladen alle 30 Sekunden
  /// ersetzt sie kurz durch die Ladeanzeige und würde sonst jedes Mal an
  /// den Montag zurückspringen.
  Widget _tagesListe(AppLocalizations l, Map<String, String> holidays) {
    final namen = _wochentage(l);
    return ListView(
      key: const PageStorageKey('terminverwaltung_tage'),
      children: List.generate(7, (dayIndex) {
        final tag = _tagDaten(dayIndex, holidays);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _tagFarbe(tag),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tageskopf: Datum (hervorgehoben wie im Raster) und Wochentag
              Container(
                color: Colors.grey.shade100,
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _datumsFeld(tag),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        namen[dayIndex],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              if (tag.feiertag != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: _feiertagHinweis(l, tag.feiertag!),
                )
              else if (tag.urlaub)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _urlaubHinweis(l),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _zeitfenster(l, tag),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  /// Was an einem Tag der Woche anliegt — für Raster und Liste gleich.
  _TagDaten _tagDaten(int dayIndex, Map<String, String> holidays) {
    final currentDay = _currentWeekStart.add(Duration(days: dayIndex));
    final isToday = currentDay.year == DateTime.now().year &&
        currentDay.month == DateTime.now().month &&
        currentDay.day == DateTime.now().day;
    final isWeekend = dayIndex >= 5;

    final dayTermine = _termine.where((t) {
      return t.terminDate.year == currentDay.year &&
          t.terminDate.month == currentDay.month &&
          t.terminDate.day == currentDay.day;
    }).toList();

    final isUrlaub = _urlaub.any((u) {
      final start = DateTime.parse(u['start_date']);
      final end = DateTime.parse(u['end_date']);
      final dayOnly = DateTime(currentDay.year, currentDay.month, currentDay.day);
      // Check if day is within range (inclusive)
      return dayOnly.compareTo(start) >= 0 && dayOnly.compareTo(end) <= 0;
    });

    final dayStr = DateFormat('yyyy-MM-dd').format(currentDay);

    return _TagDaten(
      tag: currentDay,
      heute: isToday,
      wochenende: isWeekend,
      termine: dayTermine,
      urlaub: isUrlaub,
      feiertag: holidays[dayStr],
    );
  }

  Color _tagFarbe(_TagDaten tag) {
    final isFeiertag = tag.feiertag != null;
    return isFeiertag
        ? Colors.indigo.shade50
        : tag.urlaub
            ? Colors.red.shade50
            : (tag.wochenende ? Colors.grey.shade50 : Colors.white);
  }

  Widget _datumsFeld(_TagDaten tag) {
    final isToday = tag.heute;
    final isUrlaub = tag.urlaub;
    final isFeiertag = tag.feiertag != null;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isFeiertag
            ? Colors.indigo.shade100
            : isUrlaub
                ? Colors.red.shade100
                : (isToday ? Colors.blue.shade100 : null),
        border: isFeiertag
            ? Border.all(color: Colors.indigo.shade700, width: 2)
            : isUrlaub
                ? Border.all(color: Colors.red.shade700, width: 2)
                : (isToday ? Border.all(color: Colors.blue.shade700, width: 2) : null),
      ),
      child: Text(
        DateFormat('dd').format(tag.tag),
        style: TextStyle(
          fontSize: 16,
          fontWeight: (isToday || isUrlaub || isFeiertag) ? FontWeight.bold : FontWeight.normal,
          color: isFeiertag
              ? Colors.indigo.shade900
              : isUrlaub
                  ? Colors.red.shade900
                  : (isToday ? Colors.blue.shade900 : Colors.black),
        ),
      ),
    );
  }

  Widget _feiertagHinweis(AppLocalizations l, String feiertag) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag, color: Colors.indigo.shade700, size: 32),
          const SizedBox(height: 8),
          Text(
            l.holiday,
            style: TextStyle(
              color: Colors.indigo.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            feiertag,
            style: TextStyle(
              color: Colors.indigo.shade500,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _urlaubHinweis(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.beach_access, color: Colors.red.shade700, size: 32),
          const SizedBox(height: 8),
          Text(
            l.vacation,
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _zeitfenster(AppLocalizations l, _TagDaten tag) {
    final currentDay = tag.tag;
    final dayTermine = tag.termine;
    return [
      _buildTimeSlot(currentDay, 8, dayTermine),
      _buildTimeSlot(currentDay, 9, dayTermine),
      _buildTimeSlot(currentDay, 10, dayTermine),
      _buildTimeSlot(currentDay, 11, dayTermine),
      Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 12, color: Colors.amber.shade700),
            const SizedBox(width: 4),
            // Wird die Spalte zu schmal (oder die Schrift größer), bricht
            // „Pauza de prânz“ um, statt über den Rand zu laufen.
            Flexible(
              child: Text(
                l.lunchBreak,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      _buildTimeSlot(currentDay, 14, dayTermine),
      _buildTimeSlot(currentDay, 15, dayTermine),
      _buildTimeSlot(currentDay, 16, dayTermine),
      _buildTimeSlot(currentDay, 17, dayTermine),
    ];
  }

  /// Check if a time slot is in the past
  bool _isSlotPassed(DateTime date, int hour) {
    final now = DateTime.now();
    final slotDateTime = DateTime(date.year, date.month, date.day, hour);

    // If the slot date+time is before now, it's passed
    return slotDateTime.isBefore(now);
  }

  /// Build a cell for past time slots with diagonal stripes
  Widget _buildPastSlotCell(int hour) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: CustomPaint(
          painter: _DiagonalStripesPainter(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Text(
              '$hour:00',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.lineThrough,
                decorationColor: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlot(DateTime day, int hour, List<Termin> dayTermine) {
    final slotStart = DateTime(day.year, day.month, day.day, hour);
    final slotEnd = DateTime(day.year, day.month, day.day, hour + 1);

    // Find termin that covers this hour slot (starts before slot ends AND ends after slot starts)
    final termin = dayTermine.where((t) {
      return t.terminDate.isBefore(slotEnd) && t.terminEndTime.isAfter(slotStart);
    }).firstOrNull;

    final isPast = _isSlotPassed(day, hour);

    // If there's a termin covering this slot, show it
    if (termin != null) {
      final isStartSlot = termin.terminDate.hour == hour;
      final durationHours = '${DateFormat('HH:mm').format(termin.terminDate)} - ${DateFormat('HH:mm').format(termin.terminEndTime)}';

      return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPast
                ? Colors.grey.shade200
                : termin.categoryColor.withValues(alpha: isStartSlot ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isPast
                  ? Colors.grey.shade400
                  : termin.categoryColor.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isStartSlot) ...[
                // First slot: show full info
                Text(
                  durationHours,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isPast ? Colors.grey.shade500 : termin.categoryColor,
                    decoration: isPast ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  termin.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPast ? Colors.grey.shade500 : null,
                    decoration: isPast ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.grey.shade500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (termin.totalParticipants != null)
                  Text(
                    '${termin.confirmedCount}/${termin.totalParticipants}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                      decoration: isPast ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.grey.shade500,
                    ),
                  ),
              ] else ...[
                // Continuation slot: show minimal info
                Row(
                  children: [
                    Icon(
                      Icons.more_vert,
                      size: 12,
                      color: isPast ? Colors.grey.shade400 : termin.categoryColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$hour:00',
                      style: TextStyle(
                        fontSize: 11,
                        color: isPast ? Colors.grey.shade400 : termin.categoryColor.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        termin.title,
                        style: TextStyle(
                          fontSize: 10,
                          color: isPast ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
      );
    }

    // Empty slot - show past styling if passed
    if (isPast) {
      return _buildPastSlotCell(hour);
    }

    // Future empty slot
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$hour:00',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }
}
