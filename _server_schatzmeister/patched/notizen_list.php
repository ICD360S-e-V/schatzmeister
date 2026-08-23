<?php
/**
 * API Endpoint: List internal notes for a user
 * URL: https://icd360sev.icd360s.de/api/admin/notizen_list.php
 * Method: POST
 * Body: {"user_id": 123}
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
$targetUserId = $input['user_id'] ?? null;

if (!$targetUserId) {
    http_response_code(400);
    jsonResponse(false, [], 'Missing user_id');
}

try {
    $pdo = getDBConnection();

    $stmt = $pdo->prepare('
        SELECT n.*, u.name as erstellt_von_name, u.mitgliedernummer as erstellt_von_nummer
        FROM user_notizen n
        LEFT JOIN users u ON n.erstellt_von = u.id
        WHERE n.user_id = ?
        ORDER BY n.wichtig DESC, n.created_at DESC
    ');
    $stmt->execute([$targetUserId]);
    $notizen = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $formatted = [];
    foreach ($notizen as $notiz) {
        $formatted[] = [
            'id' => (int)$notiz['id'],
            'user_id' => (int)$notiz['user_id'],
            'erstellt_von' => (int)$notiz['erstellt_von'],
            'erstellt_von_name' => $notiz['erstellt_von_name'],
            'erstellt_von_nummer' => $notiz['erstellt_von_nummer'],
            'notiz' => $notiz['notiz'],
            'kategorie' => $notiz['kategorie'],
            'wichtig' => (bool)$notiz['wichtig'],
            'created_at' => $notiz['created_at'],
            'updated_at' => $notiz['updated_at'],
        ];
    }

    http_response_code(200);
    jsonResponse(true, ['notizen' => $formatted]);

} catch (PDOException $e) {
    http_response_code(500);
    jsonResponse(false, [], 'Database error: ' . $e->getMessage());
}
