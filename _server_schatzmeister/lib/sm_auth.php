<?php
/**
 * Gemeinsame Auth- und Datenschutz-Helfer für das Schatzmeister-API.
 *
 * Dieses Namespace ist bewusst UNABHÄNGIG von /api/admin/. Es benutzt weder
 * requireAdminRole() (das ist vorsitzer-only) noch irgendeinen Admin-Endpunkt.
 * Rolle und Datensparsamkeit werden hier zentral durchgesetzt — vorher war die
 * Rollenprüfung in 22 Dateien kopiert.
 *
 * Datenschutz: der Schatzmeister arbeitet pseudonymisiert. Von MITGLIEDERN
 * (und Spendern / Zahlungsempfängern) verlassen weder Name noch Anschrift
 * noch Geburtsdatum dieses API. Identifiziert wird ausschließlich über die
 * Mitgliedernummer.
 *
 * Nicht betroffen sind die Stammdaten DES VEREINS (Vereinsname, Anschrift,
 * Steuernummer, Finanzamt) — die braucht der Schatzmeister für Steuer-
 * erklärung und Zuwendungsbescheinigungen; siehe finanzen/einstellungen.php.
 */

if (!defined("API_ACCESS")) {
    http_response_code(403);
    exit("Direct access not permitted");
}

/**
 * Personenbezogene Feldnamen, die niemals an den Schatzmeister gehen.
 * Kern der Sperre: Name, Anschrift, Geburtsdatum.
 *
 * smRedact() wendet die Liste auf jede Zeile an — als Sicherheitsnetz für
 * den Fall, dass ein künftiger Query doch mal ein SELECT * benutzt. Die
 * Queries selbst listen ihre Spalten ohnehin einzeln auf.
 */
const SM_PII_FIELDS = [
    'name', 'vorname', 'vorname2', 'nachname', 'geburtsname',
    'spender_name', 'empfaenger_absender',
    'strasse', 'plz', 'ort', 'adresse',
    'email', 'telefon_mobil', 'telefon_fix', 'telefon_norm',
    'geburtsdatum', 'geburtsort',
    'parent_hint_vorname', 'parent_hint_nachname', 'parent_hint_telefon',
];

/**
 * Entfernt PII aus einer Zeile oder einer Liste von Zeilen.
 */
function smRedact($row) {
    if (!is_array($row)) return $row;
    // Liste von Zeilen?
    if (array_key_exists(0, $row) && is_array($row[0])) {
        return array_map('smRedact', $row);
    }
    foreach (SM_PII_FIELDS as $f) {
        unset($row[$f]);
    }
    return $row;
}

/**
 * Erzwingt: gültiges JWT + Rolle 'schatzmeister'.
 * Gibt die Benutzerzeile zurück (id, mitgliedernummer, role) — ohne Klarnamen.
 * Bricht mit 401/403 ab, wenn etwas nicht stimmt.
 */
function smRequireSchatzmeister(PDO $pdo): array {
    $headers = array_change_key_case(getallheaders(), CASE_LOWER);
    $authHeader = $headers['authorization'] ?? '';

    if (empty($authHeader) || !preg_match('/Bearer\s+(.+)/i', $authHeader, $m)) {
        http_response_code(401);
        jsonResponse(false, [], "Missing Authorization header");
    }

    $payload = validateJWT($m[1]);
    if (!$payload || empty($payload['userId'])) {
        http_response_code(401);
        jsonResponse(false, [], "Invalid or expired token");
    }

    $stmt = $pdo->prepare("SELECT id, mitgliedernummer, role, status FROM users WHERE id = ?");
    $stmt->execute([$payload['userId']]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user || $user['role'] !== 'schatzmeister') {
        http_response_code(403);
        jsonResponse(false, [], "Zugriff nur für Schatzmeister");
    }
    if (($user['status'] ?? '') !== 'active') {
        http_response_code(403);
        jsonResponse(false, [], "Konto ist nicht aktiv");
    }

    return $user;
}

/**
 * Standard-CORS/Preflight für alle Schatzmeister-Endpunkte.
 */
function smCorsPreflight(string $methods): void {
    header("Access-Control-Allow-Methods: $methods, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Device-Key");
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(200);
        exit;
    }
}
