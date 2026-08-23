<?php
/**
 * API Endpoint: Update Routine (Admin only)
 * URL: /api/admin/routine_update.php
 * Method: POST
 */

define('API_ACCESS', true);
require_once '../config.php';
require_once __DIR__ . '/lib/sm_auth.php';
require_once __DIR__ . '/../helpers/routine_krypto.php';

validateApiKey();
blockBrowserAccess();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    jsonResponse(false, [], 'Method not allowed');
}

$userId = requireAuth();
// requireAdminRole() prueft auf 'vorsitzer' und sperrte damit genau die Rolle
// aus, fuer die dieses Namespace gedacht ist — Notizen und Routineaufgaben
// gaben dem Schatzmeister 403. Eigene Pruefung statt der Admin-Huelle:
smRequireSchatzmeister(getDBConnection());

$input = json_decode(file_get_contents('php://input'), true);
$routineId = $input['routine_id'] ?? null;

if (!$routineId) {
    http_response_code(400);
    jsonResponse(false, [], 'routine_id ist erforderlich');
}

try {
    $pdo = getDBConnection();

    $stmt = $pdo->prepare('SELECT * FROM routines WHERE id = ?');
    $stmt->execute([$routineId]);
    $routine = $stmt->fetch();
    if (!$routine) {
        http_response_code(404);
        jsonResponse(false, [], 'Routine nicht gefunden');
    }

    $fields = [];
    $params = [];

    if (isset($input['title'])) {
        $fields[] = 'title = ?';
        $params[] = routineVerschluesseln(trim($input['title']));
    }
    if (isset($input['description'])) {
        $fields[] = 'description = ?';
        $params[] = routineVerschluesseln(trim($input['description']) ?: null);
    }
    if (isset($input['frequency'])) {
        $validFreqs = ['once', 'daily', 'weekly', 'monthly', 'yearly'];
        if (!in_array($input['frequency'], $validFreqs)) {
            http_response_code(400);
            jsonResponse(false, [], 'Ungültige Frequenz');
        }
        $fields[] = 'frequency = ?';
        $params[] = $input['frequency'];
    }
    if (array_key_exists('day_of_week', $input)) {
        $fields[] = 'day_of_week = ?';
        $params[] = $input['day_of_week'];
    }
    if (array_key_exists('day_of_month', $input)) {
        $fields[] = 'day_of_month = ?';
        $params[] = $input['day_of_month'];
    }
    if (array_key_exists('month_of_year', $input)) {
        $fields[] = 'month_of_year = ?';
        $params[] = $input['month_of_year'];
    }
    if (array_key_exists('once_date', $input)) {
        $fields[] = 'once_date = ?';
        $params[] = $input['once_date'];
    }
    if (isset($input['category'])) {
        $fields[] = 'category = ?';
        $params[] = routineVerschluesseln(trim($input['category']) ?: null);
    }
    if (isset($input['preferred_time'])) {
        $fields[] = 'preferred_time = ?';
        $params[] = $input['preferred_time'];
    }
    if (isset($input['is_active'])) {
        $fields[] = 'is_active = ?';
        $params[] = $input['is_active'] ? 1 : 0;
    }
    if (isset($input['user_id'])) {
        $fields[] = 'user_id = ?';
        $params[] = $input['user_id'];
    }

    if (empty($fields)) {
        http_response_code(400);
        jsonResponse(false, [], 'Keine Änderungen angegeben');
    }

    $params[] = $routineId;
    $stmt = $pdo->prepare('UPDATE routines SET ' . implode(', ', $fields) . ' WHERE id = ?');
    $stmt->execute($params);

    // If schedule-affecting fields changed, delete future pending executions
    // so they get regenerated correctly by auto_generate
    $scheduleFields = ['frequency', 'day_of_week', 'day_of_month', 'month_of_year', 'once_date', 'user_id'];
    $scheduleChanged = false;
    foreach ($scheduleFields as $sf) {
        if (array_key_exists($sf, $input)) {
            $scheduleChanged = true;
            break;
        }
    }
    if ($scheduleChanged) {
        $stmt = $pdo->prepare('
            DELETE FROM routine_executions
            WHERE routine_id = ? AND status = "pending" AND scheduled_date >= CURDATE()
        ');
        $stmt->execute([$routineId]);
    }

    $stmt = $pdo->prepare('
        SELECT r.*, u.name as member_name, u.mitgliedernummer as member_nummer
        FROM routines r
        JOIN users u ON r.user_id = u.id
        WHERE r.id = ?
    ');
    $stmt->execute([$routineId]);
    $updated = $stmt->fetch(PDO::FETCH_ASSOC);
    $updated = routineZeileEntschluesseln($updated, ['title', 'description', 'category', 'notes', 'routine_title', 'routine_category']);

    jsonResponse(true, ['routine' => $updated], 'Routine aktualisiert');
} catch (Exception $e) {
    http_response_code(500);
    jsonResponse(false, [], 'Datenbankfehler: ' . $e->getMessage());
}
