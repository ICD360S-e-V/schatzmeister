<?php
/**
 * Eigene Termine — Schatzmeister-Sicht.
 *
 * Entspricht /api/termine/my_termine.php, aber mit eigener Rollenprüfung und
 * ohne Klarnamen. Der gemeinsame Endpunkt liefert `created_by_name` sowie
 * `participant_vorname` / `participant_nachname` / `participant_name` mit —
 * hier werden alle vier durch Mitgliedernummern ersetzt.
 *
 * `t.*` wurde bewusst durch eine ausgeschriebene Spaltenliste ersetzt: sonst
 * landet jede künftig zur Tabelle `termine` hinzugefügte Spalte automatisch in
 * der Antwort, auch eine personenbezogene.
 *
 * GET ?filter=upcoming|past|all
 * GET ?from=YYYY-MM-DD&to=YYYY-MM-DD   (Wochenkalender)
 */
define("API_ACCESS", true);
require_once __DIR__ . "/../../config.php";
require_once __DIR__ . "/../lib/sm_auth.php";

validateApiKey();
blockBrowserAccess();
smCorsPreflight("GET");

if ($_SERVER["REQUEST_METHOD"] !== "GET") {
    http_response_code(405);
    jsonResponse(false, [], "Method not allowed");
}

$pdo  = getDBConnection();
$user = smRequireSchatzmeister($pdo);
$userId = (int)$user['id'];

$filter = $_GET["filter"] ?? "upcoming";
$from   = $_GET["from"] ?? null;
$to     = $_GET["to"] ?? null;

try {
    // vormund-Aggregation wie im gemeinsamen Endpunkt: Termine von Mündeln
    // zählen mit. Ausgegeben wird auch dort nur die Mitgliedernummer.
    $query = "
        SELECT
            t.id, t.title, t.category, t.description, t.termin_date,
            t.duration_minutes, t.location, t.ticket_id, t.braucht_mich,
            t.is_notfall, t.status, t.feedback_status, t.feedback_erhalten,
            t.nicht_wahrgenommen_grund, t.nicht_wahrgenommen_grund_text,
            t.feedback_text, t.feedback_eingegangen_am,
            t.created_at, t.updated_at,
            tp.response,
            tp.rescheduling_reason,
            tp.responded_at,
            tp.user_id AS participant_user_id,
            cu.mitgliedernummer AS created_by_mitgliedernummer,
            po.mitgliedernummer AS participant_mitgliedernummer,
            po.role AS participant_role
        FROM termine t
        INNER JOIN termin_participants tp ON t.id = tp.termin_id
        LEFT JOIN users cu ON t.created_by = cu.id
        LEFT JOIN users po ON tp.user_id = po.id
        WHERE (tp.user_id = ? OR tp.user_id IN (SELECT id FROM users WHERE vormund_user_id = ?))
          AND t.status != ?
    ";
    $params = [$userId, $userId, "cancelled"];

    if ($from !== null && $to !== null) {
        $query .= " AND DATE(t.termin_date) >= ? AND DATE(t.termin_date) <= ?";
        $params[] = $from;
        $params[] = $to;
    } elseif ($filter === "upcoming") {
        $query .= " AND t.termin_date >= NOW()";
    } elseif ($filter === "past") {
        $query .= " AND t.termin_date < NOW()";
    }

    $query .= " ORDER BY t.termin_date ASC";

    $stmt = $pdo->prepare($query);
    $stmt->execute($params);
    $termine = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $pendingStmt = $pdo->prepare("
        SELECT COUNT(*) AS pending_count
        FROM termin_participants tp
        INNER JOIN termine t ON tp.termin_id = t.id
        WHERE (tp.user_id = ? OR tp.user_id IN (SELECT id FROM users WHERE vormund_user_id = ?))
          AND tp.response = ? AND t.termin_date >= NOW() AND t.status = ?
    ");
    $pendingStmt->execute([$userId, $userId, "pending", "scheduled"]);
    $pendingCount = (int)$pendingStmt->fetch(PDO::FETCH_ASSOC)["pending_count"];

    jsonResponse(true, [
        "termine"       => smRedact($termine),
        "pending_count" => $pendingCount,
    ], "Success");

} catch (PDOException $e) {
    error_log('[sm/my_termine] ' . $e->getMessage());
    http_response_code(500);
    jsonResponse(false, [], "Database error");
}
