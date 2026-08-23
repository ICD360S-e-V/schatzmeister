<?php
/**
 * API Endpoint: Create Routine (Admin only)
 * URL: /api/admin/routine_create.php
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

$memberId = $input['user_id'] ?? null;
$title = trim($input['title'] ?? '');
$description = trim($input['description'] ?? '');
$frequency = $input['frequency'] ?? 'weekly';
$dayOfWeek = $input['day_of_week'] ?? null;
$dayOfMonth = $input['day_of_month'] ?? null;
$monthOfYear = $input['month_of_year'] ?? null;
$onceDate = $input['once_date'] ?? null;
$category = trim($input['category'] ?? '');
$preferredTime = $input['preferred_time'] ?? '09:00:00';

if (!$memberId || !$title) {
    http_response_code(400);
    jsonResponse(false, [], 'user_id und title sind erforderlich');
}

$validFreqs = ['once', 'daily', 'weekly', 'monthly', 'yearly'];
if (!in_array($frequency, $validFreqs)) {
    http_response_code(400);
    jsonResponse(false, [], 'Ungültige Frequenz. Erlaubt: once, daily, weekly, monthly, yearly');
}

if ($frequency === 'once' && !$onceDate) {
    http_response_code(400);
    jsonResponse(false, [], 'Für einmalige Routinen ist once_date erforderlich');
}
if ($frequency === 'weekly' && ($dayOfWeek === null || $dayOfWeek < 1 || $dayOfWeek > 5)) {
    http_response_code(400);
    jsonResponse(false, [], 'Für wöchentliche Routinen ist day_of_week (1-5, Mo-Fr) erforderlich');
}
if ($frequency === 'monthly' && ($dayOfMonth === null || $dayOfMonth < 1 || $dayOfMonth > 28)) {
    http_response_code(400);
    jsonResponse(false, [], 'Für monatliche Routinen ist day_of_month (1-28) erforderlich');
}
if ($frequency === 'yearly') {
    if ($monthOfYear === null || $monthOfYear < 1 || $monthOfYear > 12) {
        http_response_code(400);
        jsonResponse(false, [], 'Für jährliche Routinen ist month_of_year (1-12) erforderlich');
    }
    if ($dayOfMonth === null || $dayOfMonth < 1 || $dayOfMonth > 28) {
        http_response_code(400);
        jsonResponse(false, [], 'Für jährliche Routinen ist day_of_month (1-28) erforderlich');
    }
}

// Validate time format
if (!preg_match('/^\d{2}:\d{2}(:\d{2})?$/', $preferredTime)) {
    $preferredTime = '09:00:00';
}

try {
    $pdo = getDBConnection();

    $stmt = $pdo->prepare('SELECT id, mitgliedernummer, name FROM users WHERE id = ?');
    $stmt->execute([$memberId]);
    $member = $stmt->fetch();
    if (!$member) {
        http_response_code(404);
        jsonResponse(false, [], 'Mitglied nicht gefunden');
    }

    $stmt = $pdo->prepare('SELECT mitgliedernummer FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    $admin = $stmt->fetch();

    $stmt = $pdo->prepare('
        INSERT INTO routines (user_id, title, description, frequency, day_of_week, day_of_month, month_of_year, once_date, category, preferred_time, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ');
    $stmt->execute([
        $memberId, routineVerschluesseln($title),
        routineVerschluesseln($description ?: null), $frequency,
        $dayOfWeek, $dayOfMonth, $monthOfYear, $onceDate,
        routineVerschluesseln($category ?: null), $preferredTime,
        $admin['mitgliedernummer'] ?? ''
    ]);
    $routineId = $pdo->lastInsertId();

    $stmt = $pdo->prepare('
        SELECT r.*, u.name as member_name, u.mitgliedernummer as member_nummer
        FROM routines r
        JOIN users u ON r.user_id = u.id
        WHERE r.id = ?
    ');
    $stmt->execute([$routineId]);
    $routine = $stmt->fetch(PDO::FETCH_ASSOC);
    $routine = routineZeileEntschluesseln($routine, ['title', 'description', 'category', 'notes', 'routine_title', 'routine_category']);

    http_response_code(201);
    jsonResponse(true, ['routine' => $routine], 'Routine erfolgreich erstellt');
} catch (Exception $e) {
    http_response_code(500);
    jsonResponse(false, [], 'Datenbankfehler: ' . $e->getMessage());
}
