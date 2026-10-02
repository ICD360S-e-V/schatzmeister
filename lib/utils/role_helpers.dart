import 'package:flutter/material.dart';

import '../services/language_service.dart';

/// ============================================================
/// Rollen in einem eingetragenen Verein (e.V.) nach deutschem Recht
/// Basierend auf BGB §§ 21-79 und gängiger Vereinspraxis
/// ============================================================
///
/// VORSTAND (Pflichtorgan §26 BGB):
///   - vorsitzer          = 1. Vorsitzender
///   - stellvertreter     = 2. Vorsitzender / Stellvertreter
///   - schatzmeister      = Schatzmeister (Kassenwart)
///   - schriftfuehrer     = Schriftführer
///   - beisitzer          = Beisitzer (erweiterter Vorstand)
///
/// FINANZKONTROLLE:
///   - kassierer          = Kassierer
///   - kassenprufer       = Kassenprüfer (Rechnungsprüfer)
///
/// EHRENAMT:
///   - ehrenamtlich       = Ehrenamtlicher Mitarbeiter
///
/// MITGLIEDERTYPEN:
///   - mitglied           = Ordentliches Mitglied
///   - mitgliedergrunder  = Gründungsmitglied
///   - ehrenmitglied      = Ehrenmitglied
///   - foerdermitglied    = Fördermitglied
/// ============================================================

/// Returns the display text for a user role
String getRoleText(String role) {
  switch (role) {
    case 'vorsitzer':
      return tr('Vorsitzender', 'Președinte');
    case 'stellvertreter':
      return tr('Stellvertreter', 'Vicepreședinte');
    case 'schatzmeister':
      return tr('Schatzmeister', 'Trezorier');
    case 'schriftfuehrer':
      return tr('Schriftführer', 'Secretar');
    case 'beisitzer':
      return tr('Beisitzer', 'Membru în conducere');
    case 'kassierer':
      return tr('Kassierer', 'Casier');
    case 'kassenprufer':
      return tr('Kassenprüfer', 'Cenzor');
    case 'ehrenamtlich':
      return tr('Ehrenamtlich', 'Voluntar');
    case 'mitglied':
      return tr('Mitglied', 'Membru');
    case 'mitgliedergrunder':
      return tr('Gründungsmitglied', 'Membru fondator');
    case 'ehrenmitglied':
      return tr('Ehrenmitglied', 'Membru de onoare');
    case 'foerdermitglied':
      return tr('Fördermitglied', 'Membru susținător');
    default:
      return role;
  }
}

/// Returns the color associated with a user role
Color getRoleColor(String role) {
  switch (role) {
    // Vorstand
    case 'vorsitzer':
      return Colors.purple;
    case 'stellvertreter':
      return Colors.purple.shade300;
    case 'schatzmeister':
      return Colors.indigo;
    case 'schriftfuehrer':
      return Colors.deepPurple;
    case 'beisitzer':
      return Colors.purple.shade200;
    // Finanzkontrolle
    case 'kassierer':
      return Colors.teal;
    case 'kassenprufer':
      return Colors.teal.shade300;
    // Ehrenamt
    case 'ehrenamtlich':
      return Colors.orange;
    // Mitgliedertypen
    case 'mitgliedergrunder':
      return Colors.amber.shade800;
    case 'ehrenmitglied':
      return Colors.amber;
    case 'foerdermitglied':
      return Colors.lime.shade700;
    default:
      return Colors.blue; // mitglied
  }
}

/// Returns the display text for a user status
String getStatusText(String status) {
  switch (status) {
    case 'nicht_verifiziert':
      return tr('Nicht verifiziert', 'Neverificat');
    case 'neu':
      return tr('Neu (Antrag)', 'Nou (cerere)');
    case 'active':
      return tr('Aktiv', 'Activ');
    case 'passiv':
      return tr('Passiv', 'Pasiv');
    case 'ruhend':
      return tr('Ruhend', 'În pauză');
    case 'gesperrt':
      return tr('Gesperrt', 'Suspendat');
    case 'gekuendigt_selbst':
      return tr('Gekündigt (selbst)', 'Reziliat (de membru)');
    case 'gekuendigt_verein':
      return tr('Gekündigt (Verein)', 'Reziliat (de asociație)');
    case 'ausgeschlossen':
      return tr('Ausgeschlossen', 'Exclus');
    case 'verstorben':
      return tr('Verstorben', 'Decedat');
    // Legacy statuses (backward compatibility)
    case 'suspended':
      return tr('Gesperrt', 'Suspendat');
    case 'deleted':
      return tr('Gelöscht', 'Șters');
    case 'gekuendigt':
      return tr('Gekündigt', 'Reziliat');
    default:
      return status;
  }
}

/// Returns the color associated with a user status
Color getStatusColor(String status) {
  switch (status) {
    case 'nicht_verifiziert':
      return Colors.red.shade300;
    case 'active':
      return Colors.green;
    case 'neu':
      return Colors.amber;
    case 'passiv':
      return Colors.blueGrey;
    case 'ruhend':
      return Colors.indigo;
    case 'gesperrt':
    case 'suspended':
      return Colors.orange;
    case 'gekuendigt_selbst':
      return Colors.brown.shade400;
    case 'gekuendigt_verein':
    case 'gekuendigt':
      return Colors.brown;
    case 'ausgeschlossen':
      return Colors.red.shade800;
    case 'verstorben':
      return Colors.grey.shade700;
    case 'deleted':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

/// All available statuses for dropdowns (ordered by lifecycle)
/// Getter statt const: Bezeichnungen folgen der gewählten Sprache.
List<Map<String, String>> get allStatuses => [
  {'value': 'nicht_verifiziert', 'label': tr('Nicht verifiziert', 'Neverificat'), 'description': tr('Konto erstellt, Identität noch nicht bestätigt (30 Tage Frist)', 'Cont creat, identitate încă neconfirmată (termen de 30 de zile)')},
  {'value': 'neu', 'label': tr('Neu (Antrag)', 'Nou (cerere)'), 'description': tr('Aufnahmeantrag eingegangen', 'Cerere de admitere primită')},
  {'value': 'active', 'label': tr('Aktiv', 'Activ'), 'description': tr('Ordentliches Mitglied', 'Membru ordinar')},
  {'value': 'passiv', 'label': tr('Passiv', 'Pasiv'), 'description': tr('Zahlt Beitrag, nimmt nicht aktiv teil', 'Plătește contribuția, nu participă activ')},
  {'value': 'ruhend', 'label': tr('Ruhend', 'În pauză'), 'description': tr('Mitgliedschaft vorübergehend ruhend', 'Calitatea de membru este temporar în pauză')},
  {'value': 'gesperrt', 'label': tr('Gesperrt', 'Suspendat'), 'description': tr('Mitgliedschaftsrechte vorübergehend entzogen', 'Drepturile de membru retrase temporar')},
  {'value': 'gekuendigt_selbst', 'label': tr('Gekündigt (selbst)', 'Reziliat (de membru)'), 'description': tr('Austritt durch Mitglied', 'Retragere la cererea membrului')},
  {'value': 'gekuendigt_verein', 'label': tr('Gekündigt (Verein)', 'Reziliat (de asociație)'), 'description': tr('Kündigung durch den Verein', 'Reziliere de către asociație')},
  {'value': 'ausgeschlossen', 'label': tr('Ausgeschlossen', 'Exclus'), 'description': tr('Vereinsausschluss nach Satzung', 'Excludere din asociație conform statutului (Satzung)')},
  {'value': 'verstorben', 'label': tr('Verstorben', 'Decedat'), 'description': tr('Mitglied verstorben', 'Membru decedat')},
];

/// Returns the role prefix for Benutzernummer
String getRolePrefix(String role) {
  switch (role) {
    case 'vorsitzer':
      return 'V';
    case 'stellvertreter':
      return 'SV';
    case 'schatzmeister':
      return 'S';
    case 'schriftfuehrer':
      return 'SF';
    case 'beisitzer':
      return 'B';
    case 'kassierer':
      return 'K';
    case 'kassenprufer':
      return 'KP';
    case 'ehrenamtlich':
      return 'E';
    case 'mitgliedergrunder':
      return 'MG';
    case 'ehrenmitglied':
      return 'EM';
    case 'foerdermitglied':
      return 'FM';
    default:
      return 'M'; // mitglied
  }
}

/// Checks if a role is an admin role (Vorstand + Finanzkontrolle)
bool isAdminRole(String role) {
  return [
    'vorsitzer',
    'stellvertreter',
    'schatzmeister',
    'schriftfuehrer',
    'beisitzer',
    'kassierer',
    'kassenprufer',
    'mitgliedergrunder',
  ].contains(role);
}

/// Checks if a role is a Vorstand (board) role
bool isVorstandRole(String role) {
  return [
    'vorsitzer',
    'stellvertreter',
    'schatzmeister',
    'schriftfuehrer',
    'beisitzer',
  ].contains(role);
}

/// All available roles for dropdowns
/// Getter statt const: Bezeichnungen folgen der gewählten Sprache.
List<Map<String, String>> get allRoles => [
  {'value': 'mitglied', 'label': tr('Mitglied', 'Membru')},
  {'value': 'vorsitzer', 'label': tr('Vorsitzender', 'Președinte')},
  {'value': 'stellvertreter', 'label': tr('Stellvertreter', 'Vicepreședinte')},
  {'value': 'schatzmeister', 'label': tr('Schatzmeister', 'Trezorier')},
  {'value': 'schriftfuehrer', 'label': tr('Schriftführer', 'Secretar')},
  {'value': 'beisitzer', 'label': tr('Beisitzer', 'Membru în conducere')},
  {'value': 'kassierer', 'label': tr('Kassierer', 'Casier')},
  {'value': 'kassenprufer', 'label': tr('Kassenprüfer', 'Cenzor')},
  {'value': 'ehrenamtlich', 'label': tr('Ehrenamtlich', 'Voluntar')},
  {'value': 'mitgliedergrunder', 'label': tr('Gründungsmitglied', 'Membru fondator')},
  {'value': 'ehrenmitglied', 'label': tr('Ehrenmitglied', 'Membru de onoare')},
  {'value': 'foerdermitglied', 'label': tr('Fördermitglied', 'Membru susținător')},
];

/// ✅ SECURITY FIX (2026-02-10): Input sanitization to prevent SQL injection
/// Sanitizes Mitgliedernummer by allowing only alphanumeric characters
/// Valid formats: V00001, S00001, K00001, MG00001, SV00001, etc.
String sanitizeMitgliedernummer(String input) {
  // Remove all non-alphanumeric characters
  final sanitized = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  // Validate format
  if (sanitized.isEmpty) return '';

  // Check if it matches valid patterns:
  // - V/S/K/MG/SV/SF/B/KP/E/EM/FM/M + 5 digits (role prefixes)
  // - 10000-99999 (5-digit numbers for legacy accounts)
  final validPattern = RegExp(r'^(V|SV|S|SF|K|KP|MG|B|E|EM|FM|M)\d{5}$|^\d{5}$');

  if (validPattern.hasMatch(sanitized)) {
    return sanitized;
  }

  // Return original if doesn't match (UI validation will catch it)
  return sanitized;
}

/// Validates Mitgliedernummer format
bool isValidMitgliedernummer(String mitgliedernummer) {
  final sanitized = sanitizeMitgliedernummer(mitgliedernummer);

  // Must match: role prefix + 5 digits, or legacy 5-digit number
  final validPattern = RegExp(r'^(V|SV|S|SF|K|KP|MG|B|E|EM|FM|M)\d{5}$|^[1-9]\d{4}$');

  return validPattern.hasMatch(sanitized);
}

/// Sanitizes email input (basic validation)
String sanitizeEmail(String email) {
  return email.trim().toLowerCase();
}

/// Validates email format
bool isValidEmail(String email) {
  final sanitized = sanitizeEmail(email);
  final emailPattern = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  return emailPattern.hasMatch(sanitized);
}
