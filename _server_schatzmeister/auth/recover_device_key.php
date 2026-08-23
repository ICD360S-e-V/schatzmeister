<?php
/**
 * Stellt den device_key aus dem Hardware-Fingerprint wieder her — für den
 * Schatzmeister. Spart nach Neuinstallation das erneute Eintippen eines
 * Aktivierungscodes.
 *
 * POST: { device_id }
 * → { device_key, mitgliedernummer, role }
 *
 * Unterschied zum gemeinsamen /api/auth/recover_device_key.php:
 *   1. trifft nur Konten mit Rolle 'schatzmeister';
 *   2. liefert KEINEN Namen und KEINE E-Mail zurück (dort ist beides drin).
 */
define("API_ACCESS", true);
require_once __DIR__ . "/../../config.php";
require_once __DIR__ . "/../lib/sm_auth.php";

validateApiKey();
blockBrowserAccess();
smCorsPreflight("POST");

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    jsonResponse(false, [], "Method not allowed");
}

$input    = json_decode(file_get_contents("php://input"), true) ?: [];
$deviceId = trim($input['device_id'] ?? '');

if ($deviceId === '' || strlen($deviceId) < 8) {
    http_response_code(400);
    jsonResponse(false, [], "Missing or invalid device_id");
}

try {
    $pdo = getDBConnection();

    $stmt = $pdo->prepare("
        SELECT dk.device_key, dk.user_id, u.mitgliedernummer, u.role
        FROM device_keys dk
        JOIN users u ON u.id = dk.user_id
        WHERE dk.device_id = ?
          AND dk.is_active = 1
          AND dk.revoked_at IS NULL
          AND u.role = 'schatzmeister'
          AND u.status = 'active'
        ORDER BY dk.last_used_at DESC
        LIMIT 1
    ");
    $stmt->execute([$deviceId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        http_response_code(404);
        jsonResponse(false, [], "No active device found for this fingerprint");
    }

    $pdo->prepare("UPDATE device_keys SET last_used_at = NOW() WHERE device_key = ?")
        ->execute([$row['device_key']]);

    jsonResponse(true, [
        'device_key'       => $row['device_key'],
        'user_id'          => (int)$row['user_id'],
        'mitgliedernummer' => $row['mitgliedernummer'],
        'role'             => $row['role'],
    ], "Device recovered");

} catch (PDOException $e) {
    error_log('[sm/recover_device_key] ' . $e->getMessage());
    http_response_code(500);
    jsonResponse(false, [], "Database error");
}
