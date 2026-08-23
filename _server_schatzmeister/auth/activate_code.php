<?php
/**
 * Öffentlicher Endpunkt (Bootstrap, kein Device-Key): löst einen 16-stelligen
 * Aktivierungscode ein und meldet dieses Gerät für den Schatzmeister an.
 *
 * POST: { mitgliedernummer, code, device_id, device_info?: {...} }
 * → { token, refresh_token, device_key, user: { id, mitgliedernummer, role } }
 *
 * Eigenständig: eigene Code-Tabelle, eigene Rate-Limit-Tabelle, Rolle muss
 * 'schatzmeister' sein. Berührt weder /api/admin/ noch den Vorsitzer-Flow.
 *
 * Datenschutz: die Antwort enthält KEINEN Klarnamen und KEINE Adresse —
 * die App identifiziert den Benutzer über die Mitgliedernummer.
 */
define("API_ACCESS", true);
require_once __DIR__ . "/../../config.php";
require_once __DIR__ . "/../lib/sm_auth.php";

blockBrowserAccess();
smCorsPreflight("POST");

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    jsonResponse(false, [], "Method not allowed");
}

$input = json_decode(file_get_contents("php://input"), true) ?: [];
$mitgliedernummer = trim($input['mitgliedernummer'] ?? '');
$rawCode          = trim($input['code'] ?? '');
$deviceId         = trim($input['device_id'] ?? '');
$deviceInfo       = is_array($input['device_info'] ?? null) ? $input['device_info'] : [];
$ipAddress        = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? '';

if ($mitgliedernummer === '' || $rawCode === '' || $deviceId === '') {
    http_response_code(400);
    jsonResponse(false, [], "Mitgliedernummer, Code und device_id erforderlich");
}

// Code normalisieren: Trennzeichen raus, Großschreibung
$normalized = strtoupper(preg_replace('/[^A-Z0-9]/i', '', $rawCode));
if (strlen($normalized) !== 16) {
    http_response_code(400);
    jsonResponse(false, [], "Code muss genau 16 Zeichen enthalten");
}

try {
    $pdo = getDBConnection();

    // Rate limit: max. 5 Fehlversuche pro IP ODER Mitgliedernummer / 15 Min
    $rateStmt = $pdo->prepare("
        SELECT COUNT(*) FROM schatzmeister_code_attempts
        WHERE (ip_address = ? OR mitgliedernummer = ?)
          AND success = 0
          AND attempted_at > DATE_SUB(NOW(), INTERVAL 15 MINUTE)
    ");
    $rateStmt->execute([$ipAddress, $mitgliedernummer]);
    if ((int)$rateStmt->fetchColumn() >= 5) {
        http_response_code(429);
        jsonResponse(false, [], "Zu viele fehlgeschlagene Versuche. Bitte 15 Minuten warten.");
    }

    $recordAttempt = function (bool $ok) use ($pdo, $ipAddress, $mitgliedernummer) {
        $pdo->prepare("INSERT INTO schatzmeister_code_attempts
            (ip_address, mitgliedernummer, success) VALUES (?, ?, ?)")
            ->execute([$ipAddress, $mitgliedernummer, $ok ? 1 : 0]);
    };

    // Benutzer suchen — nur die Felder, die hier gebraucht werden.
    $stmt = $pdo->prepare("SELECT id, mitgliedernummer, role, status
                           FROM users WHERE mitgliedernummer = ?");
    $stmt->execute([$mitgliedernummer]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    // Gleiche Fehlermeldung für "kein Benutzer" und "falsche Rolle", damit das
    // Portal nicht verrät, welche Nummern existieren.
    if (!$user || $user['role'] !== 'schatzmeister') {
        $recordAttempt(false);
        http_response_code(403);
        jsonResponse(false, [], "Ungültige Anmeldedaten");
    }
    if (($user['status'] ?? '') !== 'active') {
        $recordAttempt(false);
        http_response_code(403);
        jsonResponse(false, [], "Konto ist nicht aktiv");
    }

    // Offenen, gültigen Code suchen
    $stmt = $pdo->prepare("SELECT id, code_hash FROM schatzmeister_activation_codes
                           WHERE user_id = ? AND used_at IS NULL
                             AND revoked_at IS NULL AND expires_at > NOW()
                           ORDER BY generated_at DESC");
    $stmt->execute([$user['id']]);

    $matchedId = null;
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        if (password_verify($normalized, $row['code_hash'])) {
            $matchedId = (int)$row['id'];
            break;
        }
    }
    if ($matchedId === null) {
        $recordAttempt(false);
        http_response_code(403);
        jsonResponse(false, [], "Ungültiger oder abgelaufener Code");
    }

    // Code atomar entwerten — schützt gegen paralleles Einlösen
    $stmt = $pdo->prepare("UPDATE schatzmeister_activation_codes
                           SET used_at = NOW(), used_by_device_id = ?, used_from_ip = ?
                           WHERE id = ? AND used_at IS NULL");
    $stmt->execute([$deviceId, $ipAddress, $matchedId]);
    if ($stmt->rowCount() === 0) {
        $recordAttempt(false);
        http_response_code(409);
        jsonResponse(false, [], "Code wurde bereits verwendet");
    }

    // Device-Key anlegen
    $deviceKey  = bin2hex(random_bytes(32));
    $deviceName = trim($deviceInfo['name'] ?? '') ?: 'Unbekanntes Gerät';
    $platform   = trim($deviceInfo['platform'] ?? '') ?: 'unknown';
    $deviceType = trim($deviceInfo['type'] ?? 'unknown');
    if (!in_array($deviceType, ['phone', 'tablet', 'desktop', 'unknown'], true)) {
        $deviceType = 'unknown';
    }
    $appVersion = trim($deviceInfo['app_version'] ?? '');

    // Alten Key für dieselbe device_id rotieren
    $pdo->prepare("UPDATE device_keys
                   SET is_active = 0, revoked_at = NOW(),
                       revoked_reason = 'superseded by schatzmeister activation'
                   WHERE device_id = ? AND is_active = 1")
        ->execute([$deviceId]);

    $pdo->prepare("INSERT INTO device_keys
        (device_key, device_id, device_name, platform, device_type, app_version,
         user_id, is_active, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, 1, NOW())")
        ->execute([$deviceKey, $deviceId, $deviceName, $platform, $deviceType,
                   $appVersion, $user['id']]);

    $recordAttempt(true);

    // Tokens ausstellen. generateAccessToken() erwartet (id, email, name) —
    // wir übergeben die Mitgliedernummer statt Klarname/E-Mail, damit im JWT
    // kein personenbezogener Klartext landet.
    $accessToken  = generateAccessToken($user['id'], $user['mitgliedernummer'], $user['mitgliedernummer']);
    $refreshToken = generateRefreshToken($user['id']);

    try {
        $pdo->prepare("INSERT INTO sessions (user_id, token_hash, device_key, created_at, expires_at)
                       VALUES (?, ?, ?, NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY))
                       ON DUPLICATE KEY UPDATE token_hash=VALUES(token_hash), expires_at=VALUES(expires_at)")
            ->execute([$user['id'], hash('sha256', $accessToken), $deviceId]);
    } catch (PDOException $e) {
        error_log('[sm/activate_code] sessions: ' . $e->getMessage());
    }

    jsonResponse(true, [
        'data' => [
            'token'         => $accessToken,
            'refresh_token' => $refreshToken,
            'device_key'    => $deviceKey,
            'user'          => [
                'id'               => (int)$user['id'],
                'mitgliedernummer' => $user['mitgliedernummer'],
                'role'             => $user['role'],
            ],
        ]
    ], "Gerät erfolgreich aktiviert");

} catch (PDOException $e) {
    error_log('[sm/activate_code] ' . $e->getMessage());
    http_response_code(500);
    jsonResponse(false, [], "Server-Fehler");
}
