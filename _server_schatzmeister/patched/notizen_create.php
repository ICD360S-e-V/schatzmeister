<?php
/**
 * API Endpoint: Create internal note for a user
 * URL: https://icd360sev.icd360s.de/api/admin/notizen_create.php
 * Method: POST
 * Body: {"user_id": 123, "notiz": "text...", "kategorie": "allgemein", "wichtig": false}
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

$adminId = requireAuth();
// requireAdminRole() prueft auf 'vorsitzer' und sperrte damit genau die Rolle
// aus, fuer die dieses Namespace gedacht ist — Notizen und Routineaufgaben
// gaben dem Schatzmeister 403. Eigene Pruefung statt der Admin-Huelle:
smRequireSchatzmeister(getDBConnection());

$input = json_decode(file_get_contents('php://input'), true);
$targetUserId = $input['user_id'] ?? null;
$notizText = trim($input['notiz'] ?? '');
$kategorie = $input['kategorie'] ?? 'allgemein';
$wichtig = !empty($input['wichtig']) ? 1 : 0;

if (!$targetUserId || empty($notizText)) {
    http_response_code(400);
    jsonResponse(false, [], 'Missing user_id or notiz');
}

$allowedKategorien = ['allgemein', 'verhalten', 'zahlung', 'kommunikation', 'sonstiges'];
if (!in_array($kategorie, $allowedKategorien)) {
    $kategorie = 'allgemein';
}

try {
    $pdo = getDBConnection();

    // Check target user exists
    $stmt = $pdo->prepare('SELECT id FROM users WHERE id = ?');
    $stmt->execute([$targetUserId]);
    if (!$stmt->fetch()) {
        http_response_code(404);
        jsonResponse(false, [], 'User not found');
    }

    $stmt = $pdo->prepare('
        INSERT INTO user_notizen (user_id, erstellt_von, notiz, kategorie, wichtig)
        VALUES (?, ?, ?, ?, ?)
    ');
    $stmt->execute([$targetUserId, $adminId, $notizText, $kategorie, $wichtig]);

    $newId = $pdo->lastInsertId();

    http_response_code(201);
    jsonResponse(true, ['id' => (int)$newId, 'message' => 'Notiz erstellt']);

} catch (PDOException $e) {
    http_response_code(500);
    jsonResponse(false, [], 'Database error: ' . $e->getMessage());
}
