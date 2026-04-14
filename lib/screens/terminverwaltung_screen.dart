import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../l10n/app_localizations.dart';
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

    final results = await Future.wait([
      _terminService.getMyTermine(filter: 'all', from: _currentWeekStart, to: weekEnd),
      _terminService.getUrlaub(from: _currentWeekStart, to: weekEnd),
      _terminService.getFeiertage(
        from: _currentWeekStart,
        to: weekEnd,
        bundesland: _selectedBundesland,
      ),
    ]);

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
    final weekRange = '${DateFormat('dd.').format(_currentWeekStart)} - ${DateFormat('dd. MMMM yyyy', 'de_DE').format(weekEnd)}';

    // Build holidays map from API data
    final holidays = <String, String>{};
    for (final f in _feiertage) {
      holidays[f['datum']] = f['name'];
    }

    final bundeslaenderMap = _getBundeslaenderMap(l);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appointmentManagement),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header with navigation
            Row(
              children: [
                Icon(Icons.calendar_month, size: 32, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Text(l.appointmentManagement, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
                    });
                    _loadTermine();
                  },
                  tooltip: l.previousWeek,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'KW $weekNumber • $weekRange',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
                    });
                    _loadTermine();
                  },
                  tooltip: l.nextWeekNav,
                ),
                const SizedBox(width: 16),
                // Bundesland dropdown for regional holidays
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBundesland,
                      icon: Icon(Icons.flag, size: 16, color: Colors.indigo.shade700),
                      style: TextStyle(fontSize: 13, color: Colors.indigo.shade900),
                      items: bundeslaenderMap.entries.map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedBundesland = val);
                          _loadTermine();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadTermine,
                  tooltip: l.refresh,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Weekly Calendar Grid
            Expanded(
              child: _isLoadingTermine
                  ? const Center(child: CircularProgressIndicator())
                  : Card(
                      child: Column(
                        children: [
                          // Week days header
                          Container(
                            color: Colors.grey.shade100,
                            child: Row(
                              children: [l.monday, l.tuesday, l.wednesday, l.thursday, l.friday, l.saturday, l.sunday]
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
                                final feiertag = holidays[dayStr];
                                final isFeiertag = feiertag != null;

                                return Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isFeiertag
                                          ? Colors.indigo.shade50
                                          : isUrlaub
                                              ? Colors.red.shade50
                                              : (isWeekend ? Colors.grey.shade50 : Colors.white),
                                      border: Border(
                                        right: BorderSide(color: Colors.grey.shade300),
                                        top: BorderSide(color: Colors.grey.shade300),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
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
                                            DateFormat('dd').format(currentDay),
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
                                        ),
                                        Expanded(
                                          child: isFeiertag
                                              ? Center(
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
                                                )
                                              : isUrlaub
                                              ? Center(
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
                                                  )
                                              : ListView(
                                                  padding: const EdgeInsets.all(4),
                                                  children: [
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
                                                          Text(
                                                            l.lunchBreak,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors.amber.shade700,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    _buildTimeSlot(currentDay, 14, dayTermine),
                                                    _buildTimeSlot(currentDay, 15, dayTermine),
                                                    _buildTimeSlot(currentDay, 16, dayTermine),
                                                    _buildTimeSlot(currentDay, 17, dayTermine),
                                                  ],
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
                    ),
            ),
          ],
        ),
      ),
    );
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
