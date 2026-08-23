<?php
/**
 * API Endpoint: Delete Routine (Admin only)
 * URL: /api/admin/routine_delete.php
 * Method: POST
 * Body: { "routine_id": 1 }
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

    $stmt = $pdo->prepare('SELECT id, title FROM routines WHERE id = ?');
    $stmt->execute([$routineId]);
    $routine = $stmt->fetch();
    if (!$routine) {
        http_response_code(404);
        jsonResponse(false, [], 'Routine nicht gefunden');
    }

    // CASCADE will delete executions too
    $stmt = $pdo->prepare('DELETE FROM routines WHERE id = ?');
    $stmt->execute([$routineId]);

    jsonResponse(true, [], 'Routine "' . routineEntschluesseln($routine['title']) . '" gelöscht');
} catch (Exception $e) {
    http_response_code(500);
    jsonResponse(false, [], 'Datenbankfehler: ' . $e->getMessage());
}
