<?php
/**
 * Bankbewegungen — Schatzmeister-Sicht.
 *
 * Datenschutz: `empfaenger_absender` (Name des Zahlungsempfängers bzw.
 * -absenders) wird NIE ausgeliefert. Der Schatzmeister sieht Datum, Betrag,
 * Typ, Kategorie und Referenz — genug für Kassenbuch und Jahresabschluss,
 * ohne die Gegenpartei namentlich zu kennen.
 *
 * GET    ?jahr=YYYY&monat=MM&typ=einnahme|ausgabe
 * POST   { datum, betrag, typ, kategorie?, beschreibung?, referenz? }
 * DELETE { id }
 */
define("API_ACCESS", true);
require_once __DIR__ . "/../../config.php";
require_once __DIR__ . "/../lib/sm_auth.php";

validateApiKey();
blockBrowserAccess();
smCorsPreflight("GET, POST, DELETE");

$pdo  = getDBConnection();
$user = smRequireSchatzmeister($pdo);

$method = $_SERVER["REQUEST_METHOD"];

if ($method === "GET") {
    $jahr  = isset($_GET["jahr"])  ? intval($_GET["jahr"])  : intval(date("Y"));
    $monat = isset($_GET["monat"]) ? intval($_GET["monat"]) : null;
    $typ   = $_GET["typ"] ?? null;

    // Explizite Spaltenliste — empfaenger_absender fehlt bewusst.
    $sql    = "SELECT id, datum, betrag, typ, kategorie, beschreibung, referenz, created_at
               FROM bank_transaktionen WHERE YEAR(datum) = ?";
    $params = [$jahr];

    if ($monat) {
        $sql .= " AND MONTH(datum) = ?";
        $params[] = $monat;
    }
    if ($typ && in_array($typ, ["einnahme", "ausgabe"], true)) {
        $sql .= " AND typ = ?";
        $params[] = $typ;
    }
    $sql .= " ORDER BY datum DESC, id DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $einnahmen = 0.0;
    $ausgaben  = 0.0;
    foreach ($rows as $t) {
        if ($t["typ"] === "einnahme") { $einnahmen += floatval($t["betrag"]); }
        else                          { $ausgaben  += floatval($t["betrag"]); }
    }

    jsonResponse(true, [
        "transaktionen" => smRedact($rows),
        "einnahmen"     => $einnahmen,
        "ausgaben"      => $ausgaben,
        "saldo"         => $einnahmen - $ausgaben,
        "anzahl"        => count($rows),
        "jahr"          => $jahr,
        "monat"         => $monat,
    ]);

} elseif ($method === "POST") {
    $input = json_decode(file_get_contents("php://input"), true) ?: [];

    if (empty($input["datum"]) || !isset($input["betrag"]) || empty($input["typ"])) {
        http_response_code(400);
        jsonResponse(false, [], "Datum, Betrag und Typ sind erforderlich");
    }
    if (!in_array($input["typ"], ["einnahme", "ausgabe"], true)) {
        http_response_code(400);
        jsonResponse(false, [], "Typ muss 'einnahme' oder 'ausgabe' sein");
    }

    $stmt = $pdo->prepare("INSERT INTO bank_transaktionen
        (datum, betrag, typ, kategorie, beschreibung, empfaenger_absender, referenz, erstellt_von)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([
        $input["datum"],
        $input["betrag"],
        $input["typ"],
        $input["kategorie"] ?? null,
        $input["beschreibung"] ?? null,
        // Vom Schatzmeister angelegte Buchungen tragen keine Gegenpartei —
        // er soll sie ja gerade nicht kennen. Der Vorsitzende ergänzt sie
        // bei Bedarf über seine eigene Ansicht.
        null,
        $input["referenz"] ?? null,
        $user["mitgliedernummer"],
    ]);

    jsonResponse(true, ["id" => (int)$pdo->lastInsertId()], "Transaktion erstellt");

} elseif ($method === "DELETE") {
    $input = json_decode(file_get_contents("php://input"), true) ?: [];
    if (empty($input["id"])) {
        http_response_code(400);
        jsonResponse(false, [], "ID erforderlich");
    }
    $pdo->prepare("DELETE FROM bank_transaktionen WHERE id = ?")->execute([intval($input["id"])]);
    jsonResponse(true, [], "Transaktion gelöscht");

} else {
    http_response_code(405);
    jsonResponse(false, [], "Method not allowed");
}
