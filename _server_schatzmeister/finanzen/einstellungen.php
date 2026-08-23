<?php
/**
 * Vereinsstammdaten — Schatzmeister-Sicht, NUR LESEND.
 *
 * Der Schatzmeister braucht Steuernummer, Finanzamt, Freistellungsbescheid
 * und Vereinszweck für Steuererklärung und Zuwendungsbescheinigungen.
 * Geändert werden dürfen diese Daten nur vom Vorsitzenden — deshalb kein POST.
 *
 * Hier gilt die Datensparsamkeit NICHT: das sind die Stammdaten DES VEREINS,
 * keine Mitgliedsdaten. Vereinsname und Anschrift stehen im Impressum, im
 * Registerauszug und auf jedem Steuerformular — der Schatzmeister braucht
 * beides. Gesperrt sind ausschließlich Daten von MITGLIEDERN: Name, Anschrift
 * und Geburtsdatum (siehe SM_PII_FIELDS in lib/sm_auth.php).
 *
 * GET → { vereinsname, adresse, steuernummer, finanzamt, freistellung_*, ... }
 */
define("API_ACCESS", true);
require_once __DIR__ . "/../../config.php";
require_once __DIR__ . "/../lib/sm_auth.php";

validateApiKey();
blockBrowserAccess();
smCorsPreflight("GET");

$pdo  = getDBConnection();
$user = smRequireSchatzmeister($pdo);

if ($_SERVER["REQUEST_METHOD"] !== "GET") {
    http_response_code(405);
    jsonResponse(false, [], "Vereinsstammdaten sind für den Schatzmeister schreibgeschützt");
}

try {
    // Explizite Whitelist statt SELECT *. Absichtlich KEIN smRedact() hier —
    // das würde `adresse` und `email` des VEREINS fälschlich entfernen.
    $stmt = $pdo->query("SELECT vereinsname, slogan, adresse, telefon_fix, fax,
                                mobil, email, webseite, gruendungsdatum,
                                registernummer, registergericht, steuernummer,
                                finanzamt, freistellung_datum,
                                freistellung_zeitraum, zweck
                         FROM vereineinstellungen LIMIT 1");
    $data = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$data) {
        jsonResponse(true, ['data' => new stdClass()], "Keine Vereinsstammdaten hinterlegt");
    }

    jsonResponse(true, ['data' => $data]);

} catch (PDOException $e) {
    error_log('[sm/einstellungen] ' . $e->getMessage());
    http_response_code(500);
    jsonResponse(false, [], "Database error");
}
