<?php
/**
 * Mitgliedsbeiträge — Schatzmeister-Sicht.
 *
 * Identisch in der Rechenlogik zur Vorsitzer-Ansicht, aber PSEUDONYMISIERT:
 * ausgeliefert wird ausschließlich die Mitgliedernummer. Klarname, Adresse,
 * E-Mail und Telefon verlassen diesen Endpunkt nicht. Sortiert wird nach
 * Mitgliedernummer (die Vorsitzer-Variante sortiert nach Name — hier gibt es
 * keinen Namen, nach dem sortiert werden könnte).
 *
 * GET  ?modus=uebersicht                  → kumuliert ab Startmonat
 * GET  ?modus=monat&monat=..&jahr=..      → ein Monat
 * POST { mitgliedernummer, monat, jahr, status?, betrag?, ... }
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

$beitragProMonat = 25.00;
$startMonat      = 8;
$startJahr       = 2025;

$method = $_SERVER["REQUEST_METHOD"];

if ($method === "GET") {
    $modus = $_GET["modus"] ?? "uebersicht";

    // Nur pseudonyme Spalten holen — kein SELECT *, kein Name.
    $membersSql = "SELECT mitgliedernummer, role, status FROM users
                   WHERE status IN ('active','neu') ORDER BY mitgliedernummer ASC";

    if ($modus === "monat") {
        $monat = isset($_GET["monat"]) ? intval($_GET["monat"]) : intval(date("m"));
        $jahr  = isset($_GET["jahr"])  ? intval($_GET["jahr"])  : intval(date("Y"));

        $members = $pdo->query($membersSql)->fetchAll(PDO::FETCH_ASSOC);

        $payStmt = $pdo->prepare("SELECT id, mitgliedernummer, betrag, status,
                                         zahlungsdatum, zahlungsmethode, notiz
                                  FROM beitragszahlungen WHERE monat = ? AND jahr = ?");
        $payStmt->execute([$monat, $jahr]);

        $payments = [];
        foreach ($payStmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            $payments[$row["mitgliedernummer"]] = $row;
        }

        $liste = [];
        $bezahlt = 0;
        $offen   = 0;

        foreach ($members as $m) {
            $mn      = $m["mitgliedernummer"];
            $payment = $payments[$mn] ?? null;
            $status  = $payment ? $payment["status"] : "offen";

            $liste[] = [
                "mitgliedernummer" => $mn,
                "role"             => $m["role"],
                "member_status"    => $m["status"],
                "payment_id"       => $payment ? (int)$payment["id"] : null,
                "betrag"           => $payment ? floatval($payment["betrag"]) : $beitragProMonat,
                "status"           => $status,
                "zahlungsdatum"    => $payment ? $payment["zahlungsdatum"] : null,
                "zahlungsmethode"  => $payment ? $payment["zahlungsmethode"] : null,
                "notiz"            => $payment ? $payment["notiz"] : null,
            ];

            if ($status === "bezahlt" || $status === "befreit") { $bezahlt++; } else { $offen++; }
        }

        jsonResponse(true, [
            "liste"             => smRedact($liste),
            "monat"             => $monat,
            "jahr"              => $jahr,
            "beitrag_pro_monat" => $beitragProMonat,
            "stats" => ["gesamt" => count($members), "bezahlt" => $bezahlt, "offen" => $offen],
        ]);
    }

    // ── Übersicht: kumuliert vom Startmonat bis zum laufenden Monat ──
    $nowMonat = intval(date("m"));
    $nowJahr  = intval(date("Y"));

    $monate = [];
    $y = $startJahr;
    $m = $startMonat;
    while ($y < $nowJahr || ($y === $nowJahr && $m <= $nowMonat)) {
        $monate[] = ["monat" => $m, "jahr" => $y];
        if (++$m > 12) { $m = 1; $y++; }
    }
    $anzahlMonate = count($monate);

    $members = $pdo->query($membersSql)->fetchAll(PDO::FETCH_ASSOC);

    $payStmt = $pdo->prepare("SELECT mitgliedernummer, monat, jahr, betrag, status
                              FROM beitragszahlungen
                              WHERE (jahr > ? OR (jahr = ? AND monat >= ?))");
    $payStmt->execute([$startJahr, $startJahr, $startMonat]);

    $allPayments = [];
    foreach ($payStmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        $allPayments[$row["mitgliedernummer"] . "_" . $row["jahr"] . "_" . $row["monat"]] = $row;
    }

    $liste = [];
    $totalSchulden = 0;
    $totalBezahlt  = 0;
    $mitSchulden   = 0;

    foreach ($members as $mem) {
        $mn = $mem["mitgliedernummer"];
        $bezahltMonate = 0; $offenMonate = 0; $bezahltBetrag = 0; $schulden = 0;
        $monateDetails = [];

        foreach ($monate as $mi) {
            $payment = $allPayments[$mn . "_" . $mi["jahr"] . "_" . $mi["monat"]] ?? null;
            $status  = $payment ? $payment["status"] : "offen";
            $label   = sprintf("%02d/%d", $mi["monat"], $mi["jahr"]);

            if ($status === "bezahlt" || $status === "befreit") {
                $bezahltMonate++;
                $betrag = $payment ? floatval($payment["betrag"]) : $beitragProMonat;
                $bezahltBetrag += $betrag;
                $monateDetails[] = ["monat" => $label, "status" => $status, "betrag" => $betrag];
            } else {
                $offenMonate++;
                $schulden += $beitragProMonat;
                $monateDetails[] = ["monat" => $label, "status" => $status, "betrag" => $beitragProMonat];
            }
        }

        $liste[] = [
            "mitgliedernummer" => $mn,
            "role"             => $mem["role"],
            "member_status"    => $mem["status"],
            "anzahl_monate"    => $anzahlMonate,
            "bezahlt_monate"   => $bezahltMonate,
            "offen_monate"     => $offenMonate,
            "bezahlt_betrag"   => $bezahltBetrag,
            "schulden"         => $schulden,
            "gesamt_soll"      => $anzahlMonate * $beitragProMonat,
            "monate_details"   => $monateDetails,
        ];

        $totalSchulden += $schulden;
        $totalBezahlt  += $bezahltBetrag;
        if ($schulden > 0) { $mitSchulden++; }
    }

    usort($liste, fn($a, $b) => $b["schulden"] <=> $a["schulden"]);

    jsonResponse(true, [
        "liste"             => smRedact($liste),
        "beitrag_pro_monat" => $beitragProMonat,
        "start_monat"       => $startMonat,
        "start_jahr"        => $startJahr,
        "anzahl_monate"     => $anzahlMonate,
        "stats" => [
            "gesamt_mitglieder"       => count($members),
            "mitglieder_mit_schulden" => $mitSchulden,
            "total_schulden"          => $totalSchulden,
            "total_bezahlt"           => $totalBezahlt,
            "total_soll"              => $anzahlMonate * count($members) * $beitragProMonat,
        ],
    ]);

} elseif ($method === "POST") {
    $input = json_decode(file_get_contents("php://input"), true) ?: [];

    if (empty($input["mitgliedernummer"]) || !isset($input["monat"], $input["jahr"])) {
        http_response_code(400);
        jsonResponse(false, [], "Mitgliedernummer, Monat und Jahr erforderlich");
    }

    $stmt = $pdo->prepare("INSERT INTO beitragszahlungen
        (mitgliedernummer, monat, jahr, betrag, status, zahlungsdatum, zahlungsmethode, notiz, erstellt_von)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE betrag=VALUES(betrag), status=VALUES(status),
            zahlungsdatum=VALUES(zahlungsdatum), zahlungsmethode=VALUES(zahlungsmethode),
            notiz=VALUES(notiz)");
    $stmt->execute([
        $input["mitgliedernummer"],
        intval($input["monat"]),
        intval($input["jahr"]),
        $input["betrag"] ?? $beitragProMonat,
        $input["status"] ?? "bezahlt",
        $input["zahlungsdatum"] ?? date("Y-m-d"),
        $input["zahlungsmethode"] ?? null,
        $input["notiz"] ?? null,
        $user["mitgliedernummer"],
    ]);

    jsonResponse(true, [], "Zahlung aktualisiert");

} elseif ($method === "DELETE") {
    $input = json_decode(file_get_contents("php://input"), true) ?: [];
    if (empty($input["id"])) {
        http_response_code(400);
        jsonResponse(false, [], "ID erforderlich");
    }
    $pdo->prepare("DELETE FROM beitragszahlungen WHERE id = ?")->execute([intval($input["id"])]);
    jsonResponse(true, [], "Zahlung gelöscht");

} else {
    http_response_code(405);
    jsonResponse(false, [], "Method not allowed");
}
