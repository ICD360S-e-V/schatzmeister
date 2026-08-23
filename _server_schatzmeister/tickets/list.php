<?php
/**
 * Eigene Tickets — Schatzmeister-Sicht.
 *
 * Entspricht /api/tickets/list.php, mit zwei Unterschieden:
 *
 *   1. Rollenprüfung über smRequireSchatzmeister() statt nur requireAuth().
 *   2. `admin_name` (Klarname des zuständigen Admins) wird durch dessen
 *      Mitgliedernummer ersetzt.
 *
 * Ausserdem wird die Mitgliedernummer NICHT mehr aus dem Request-Body
 * gelesen, sondern aus dem Token genommen. Im gemeinsamen Endpunkt bestimmt
 * der Body, wessen Tickets geliefert werden — hier kann sich niemand durch
 * eine fremde Nummer im Body die Tickets eines anderen holen.
 *
 * Die automatische Übersetzung bleibt erhalten (lib/sm_translate.php,
 * gleicher `translation_cache` wie der gemeinsame Endpunkt).
 *
 * POST (kein Body nötig)
 */
define("API_ACCESS", true);
require_once __DIR__ . "/../../config.php";
require_once __DIR__ . "/../../helpers/TranslationHelper.php";
require_once __DIR__ . "/../lib/sm_auth.php";
require_once __DIR__ . "/../lib/sm_translate.php";

validateApiKey();
blockBrowserAccess();
smCorsPreflight("POST");

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    jsonResponse(false, [], "Method not allowed");
}

$pdo  = getDBConnection();
$user = smRequireSchatzmeister($pdo);

try {
    // Sprache des Schatzmeisters für die Übersetzung der Ticket-Texte.
    $langStmt = $pdo->prepare("SELECT preferred_language FROM users WHERE id = ?");
    $langStmt->execute([$user['id']]);
    $userLang = $langStmt->fetchColumn() ?: DEFAULT_LANGUAGE;
    if (!in_array($userLang, $SUPPORTED_LANGUAGES, true)) {
        $userLang = DEFAULT_LANGUAGE;
    }

    // admin_name → admin_mitgliedernummer. Nur eigene Tickets (user_id aus
    // dem Token, nicht aus dem Body).
    $stmt = $pdo->prepare("
        SELECT t.id, t.subject, t.message, t.status, t.priority,
               t.scheduled_date, t.created_at, t.updated_at, t.closed_at,
               a.mitgliedernummer AS admin_mitgliedernummer
        FROM tickets t
        LEFT JOIN users a ON t.admin_id = a.id
        WHERE t.user_id = ?
        ORDER BY t.created_at DESC
    ");
    $stmt->execute([$user['id']]);
    $tickets = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $formatted = array_map(function ($ticket) use ($pdo, $userLang, $SUPPORTED_LANGUAGES) {
        $subject = translateField($pdo, $ticket["subject"], $userLang, $SUPPORTED_LANGUAGES, $userLang);
        $message = translateField($pdo, $ticket["message"], $userLang, $SUPPORTED_LANGUAGES, $userLang);

        return [
            "id"                     => (int)$ticket["id"],
            "subject"                => $subject["text"],
            "original_subject"       => $subject["original"],
            "subject_is_translated"  => $subject["is_translated"],
            "message"                => $message["text"],
            "original_message"       => $message["original"],
            "message_is_translated"  => $message["is_translated"],
            "status"                 => $ticket["status"],
            "priority"               => $ticket["priority"],
            "admin_mitgliedernummer" => $ticket["admin_mitgliedernummer"],
            "scheduled_date"         => $ticket["scheduled_date"],
            "created_at"             => $ticket["created_at"],
            "updated_at"             => $ticket["updated_at"],
            "closed_at"              => $ticket["closed_at"],
        ];
    }, $tickets);

    jsonResponse(true, ["tickets" => smRedact($formatted)], "Success");

} catch (PDOException $e) {
    error_log('[sm/tickets_list] ' . $e->getMessage());
    http_response_code(500);
    jsonResponse(false, [], "Database error");
}
