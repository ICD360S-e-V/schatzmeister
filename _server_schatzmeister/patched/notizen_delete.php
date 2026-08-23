<?php
/**
 * API Endpoint: Delete an internal note
 * URL: https://icd360sev.icd360s.de/api/admin/notizen_delete.php
 * Method: POST
 * Body: {"id": 123}
 */

define('API_ACCESS', true);
require_once '../config.php';
require_once __DIR__ . '/lib/sm_auth.php';

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
$notizId = $input['id'] ?? null;

if (!$notizId) {
    http_response_code(400);
    jsonResponse(false, [], 'Missing id');
}

try {
    $pdo = getDBConnection();

    $stmt = $pdo->prepare('DELETE FROM user_notizen WHERE id = ?');
    $stmt->execute([$notizId]);

    if ($stmt->rowCount() === 0) {
        http_response_code(404);
        jsonResponse(false, [], 'Notiz not found');
    }

    http_response_code(200);
    jsonResponse(true, ['message' => 'Notiz gelöscht']);

} catch (PDOException $e) {
    http_response_code(500);
    jsonResponse(false, [], 'Database error: ' . $e->getMessage());
}
