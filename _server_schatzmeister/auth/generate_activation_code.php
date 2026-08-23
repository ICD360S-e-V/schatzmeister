<?php
/**
 * Erzeugt einen einmaligen 16-stelligen Aktivierungscode für DEN SCHATZMEISTER.
 *
 * Aufrufbar nur vom Vorsitzenden — der Schatzmeister kann sich nicht selbst
 * freischalten. Die Rollenprüfung steht hier inline (kein requireAdminRole()),
 * damit dieses Namespace unabhängig von /api/admin/ bleibt.
 *
 * POST: { target_user_id: int, ttl_hours?: int = 24 }
 * → { code: "XXXX-XXXX-XXXX-XXXX", code_preview, expires_at, id }
 *
 * Der Klartext-Code steht NUR in dieser Antwort — er ist danach nicht mehr
 * rekonstruierbar (gespeichert wird nur der Hash).
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

$callerId = requireAuth();
$pdo = getDBConnection();

// Nur der Vorsitzende darf Codes ausstellen.
$stmt = $pdo->prepare("SELECT id, role FROM users WHERE id = ?");
$stmt->execute([$callerId]);
$caller = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$caller || $caller['role'] !== 'vorsitzer') {
    http_response_code(403);
    jsonResponse(false, [], "Nur der Vorsitzende darf Schatzmeister-Codes erstellen");
}

$input        = json_decode(file_get_contents("php://input"), true) ?: [];
$targetUserId = (int)($input['target_user_id'] ?? 0);
$ttlHours     = max(1, min(168, (int)($input['ttl_hours'] ?? 24)));

if ($targetUserId <= 0) {
    http_response_code(400);
    jsonResponse(false, [], "target_user_id erforderlich");
}

// Ziel muss ein aktiver Schatzmeister sein.
$stmt = $pdo->prepare("SELECT id, mitgliedernummer, role, status FROM users WHERE id = ?");
$stmt->execute([$targetUserId]);
$target = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$target) {
    http_response_code(404);
    jsonResponse(false, [], "Zielbenutzer nicht gefunden");
}
if ($target['role'] !== 'schatzmeister') {
    http_response_code(400);
    jsonResponse(false, [], "Dieser Endpunkt stellt Codes ausschließlich für Schatzmeister aus");
}
if (($target['status'] ?? '') !== 'active') {
    http_response_code(400);
    jsonResponse(false, [], "Zielkonto ist nicht aktiv");
}

/**
 * 16 Zeichen aus einem verwechslungsfreien Alphabet (kein 0/O, kein 1/I/l).
 * 32 Zeichen = 5 Bit pro Stelle → 80 Bit Entropie.
 */
function smGenerateActivationCode(): string {
    $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    $max = strlen($alphabet) - 1;
    $out = '';
    for ($i = 0; $i < 16; $i++) {
        $out .= $alphabet[random_int(0, $max)];
    }
    return $out;
}

try {
    $code = smGenerateActivationCode();

    // Offene Codes desselben Benutzers entwerten: immer nur einer gültig.
    $pdo->prepare("UPDATE schatzmeister_activation_codes
                   SET revoked_at = NOW(), revoked_by = ?
                   WHERE user_id = ? AND used_at IS NULL AND revoked_at IS NULL")
        ->execute([$caller['id'], $target['id']]);

    $stmt = $pdo->prepare("INSERT INTO schatzmeister_activation_codes
        (user_id, code_hash, code_preview, generated_by, expires_at)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))");
    $stmt->execute([
        $target['id'],
        password_hash($code, PASSWORD_DEFAULT),
        substr($code, 0, 4),
        $caller['id'],
        $ttlHours,
    ]);

    $newId = (int)$pdo->lastInsertId();
    $expStmt = $pdo->prepare("SELECT expires_at FROM schatzmeister_activation_codes WHERE id = ?");
    $expStmt->execute([$newId]);
    $expiresAt = $expStmt->fetchColumn();

    // Formatiert in 4er-Blöcken — so wie die App die vier Eingabefelder zeigt.
    $formatted = implode('-', str_split($code, 4));

    jsonResponse(true, [
        'data' => [
            'id'           => $newId,
            'code'         => $formatted,
            'code_preview' => substr($code, 0, 4),
            'expires_at'   => $expiresAt,
            'ttl_hours'    => $ttlHours,
            'target'       => ['mitgliedernummer' => $target['mitgliedernummer']],
        ]
    ], "Aktivierungscode erstellt");

} catch (PDOException $e) {
    error_log('[sm/generate_activation_code] ' . $e->getMessage());
    http_response_code(500);
    jsonResponse(false, [], "Server-Fehler");
}
