<?php
/**
 * Spenden — Schatzmeister-Sicht.
 *
 * Datenschutz: `spender_name` wird NIE ausgeliefert. Der Schatzmeister sieht
 * Betrag, Datum, Zweck, Quittungsstatus und — bei Mitgliedern — die
 * Mitgliedernummer. Für externe Spender gibt es ein stabiles Pseudonym
 * ("EXT-<id>"), damit Vorgänge trotzdem eindeutig referenzierbar bleiben.
 *
 * Beim Anlegen mit `spender_mitgliedernummer` löst der SERVER den Klarnamen
 * selbst auf und speichert ihn — die App bekommt ihn nie zu sehen, der
 * Datensatz ist für die Zuwendungsbescheinigung des Vorsitzenden trotzdem
 * vollständig.
 *
 * GET    ?jahr=YYYY
 * POST   { datum, betrag, spender_mitgliedernummer | spender_extern, zweck?, notiz? }
 * PUT    { id, quittung_ausgestellt }
 * DELETE { id }
 */
define("API_ACCESS", true);
require_once __DIR__ . "/../../config.php";
require_once __DIR__ . "/../lib/sm_auth.php";

validateApiKey();
blockBrowserAccess();
smCorsPreflight("GET, POST, PUT, DELETE");

$pdo  = getDBConnection();
$user = smRequireSchatzmeister($pdo);

$method = $_SERVER["REQUEST_METHOD"];

if ($method === "GET") {
    $jahr = isset($_GET["jahr"]) ? intval($_GET["jahr"]) : intval(date("Y"));

    // Explizite Spaltenliste: spender_name ist bewusst NICHT dabei.
    $stmt = $pdo->prepare("SELECT id, datum, betrag, spender_mitgliedernummer,
                                  zweck, quittung_ausgestellt, notiz, created_at
                           FROM spenden
                           WHERE YEAR(datum) = ?
                           ORDER BY datum DESC, id DESC");
    $stmt->execute([$jahr]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $total = 0.0;
    $mitQuittung = 0;
    $spenden = [];

    foreach ($rows as $r) {
        $total += floatval($r["betrag"]);
        if ($r["quittung_ausgestellt"]) { $mitQuittung++; }

        $istMitglied = !empty($r["spender_mitgliedernummer"]);

        $spenden[] = [
            "id"                       => (int)$r["id"],
            "datum"                    => $r["datum"],
            "betrag"                   => floatval($r["betrag"]),
            "ist_mitglied"             => $istMitglied,
            "spender_mitgliedernummer" => $r["spender_mitgliedernummer"],
            // Stabiles Pseudonym für externe Spender — nie der Klarname.
            "spender_ref"              => $istMitglied
                                            ? $r["spender_mitgliedernummer"]
                                            : "EXT-" . $r["id"],
            "zweck"                    => $r["zweck"],
            "quittung_ausgestellt"     => (bool)$r["quittung_ausgestellt"],
            "notiz"                    => $r["notiz"],
            "created_at"               => $r["created_at"],
        ];
    }

    jsonResponse(true, [
        "spenden"      => smRedact($spenden),
        "total_betrag" => $total,
        "anzahl"       => count($spenden),
        "mit_quittung" => $mitQuittung,
        "jahr"         => $jahr,
    ]);

} elseif ($method === "POST") {
    $input = json_decode(file_get_contents("php://input"), true) ?: [];

    if (empty($input["datum"]) || !isset($input["betrag"])) {
        http_response_code(400);
        jsonResponse(false, [], "Datum und Betrag sind erforderlich");
    }

    $mgnr   = trim($input["spender_mitgliedernummer"] ?? '');
    $extern = trim($input["spender_extern"] ?? '');

    if ($mgnr === '' && $extern === '') {
        http_response_code(400);
        jsonResponse(false, [], "Entweder spender_mitgliedernummer oder spender_extern angeben");
    }

    $spenderName = '';
    if ($mgnr !== '') {
        // Server-seitige Auflösung: der Klarname wird gespeichert, aber nie
        // an den Schatzmeister zurückgegeben.
        $s = $pdo->prepare("SELECT vorname, name, nachname FROM users WHERE mitgliedernummer = ?");
        $s->execute([$mgnr]);
        $m = $s->fetch(PDO::FETCH_ASSOC);
        if (!$m) {
            http_response_code(404);
            jsonResponse(false, [], "Mitgliedernummer nicht gefunden");
        }
        $spenderName = trim(($m["vorname"] ?? $m["name"] ?? '') . ' ' . ($m["nachname"] ?? ''));
        if ($spenderName === '') { $spenderName = $mgnr; }
    } else {
        // Externer Spender: der Schatzmeister tippt die Bezeichnung selbst ein.
        // Er gibt sie ein, liest sie aber über GET nicht wieder aus.
        $spenderName = mb_substr($extern, 0, 255);
    }

    $stmt = $pdo->prepare("INSERT INTO spenden
        (datum, betrag, spender_name, spender_mitgliedernummer, zweck,
         quittung_ausgestellt, notiz, erstellt_von)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([
        $input["datum"],
        $input["betrag"],
        $spenderName,
        $mgnr !== '' ? $mgnr : null,
        $input["zweck"] ?? null,
        !empty($input["quittung_ausgestellt"]) ? 1 : 0,
        $input["notiz"] ?? null,
        $user["mitgliedernummer"],
    ]);

    jsonResponse(true, ["id" => (int)$pdo->lastInsertId()], "Spende erstellt");

} elseif ($method === "PUT") {
    $input = json_decode(file_get_contents("php://input"), true) ?: [];
    if (empty($input["id"])) {
        http_response_code(400);
        jsonResponse(false, [], "ID erforderlich");
    }
    $pdo->prepare("UPDATE spenden SET quittung_ausgestellt = ? WHERE id = ?")
        ->execute([!empty($input["quittung_ausgestellt"]) ? 1 : 0, intval($input["id"])]);
    jsonResponse(true, [], "Spende aktualisiert");

} elseif ($method === "DELETE") {
    $input = json_decode(file_get_contents("php://input"), true) ?: [];
    if (empty($input["id"])) {
        http_response_code(400);
        jsonResponse(false, [], "ID erforderlich");
    }
    $pdo->prepare("DELETE FROM spenden WHERE id = ?")->execute([intval($input["id"])]);
    jsonResponse(true, [], "Spende gelöscht");

} else {
    http_response_code(405);
    jsonResponse(false, [], "Method not allowed");
}
