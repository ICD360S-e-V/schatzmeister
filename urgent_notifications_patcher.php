<?php
/**
 * Patcher: Add URGENT notifications support to send.php
 * Date: 2026-02-11
 */

$sendPhpPath = '/var/www/icd360sev.icd360s.de/api/chat/send.php';

if (!file_exists($sendPhpPath)) {
    die("Error: send.php not found at $sendPhpPath\n");
}

$content = file_get_contents($sendPhpPath);

// Backup original
file_put_contents($sendPhpPath . '.backup_' . date('Y-m-d_His'), $content);
echo "✅ Backup created: send.php.backup_" . date('Y-m-d_His') . "\n";

// PATCH 1: Add urgent parameter reading (after line 47)
$search1 = '$message = trim($input[\'message\']);';
$replace1 = '$message = trim($input[\'message\']);
$isUrgent = isset($input[\'urgent\']) && $input[\'urgent\'] === true ? 1 : 0;  // 🆕 URGENT support';

if (strpos($content, '$isUrgent') === false) {
    $content = str_replace($search1, $replace1, $content);
    echo "✅ PATCH 1: Added urgent parameter reading\n";
} else {
    echo "⚠️  PATCH 1: Already applied (skipped)\n";
}

// PATCH 2: Update INSERT statement to include is_urgent
$search2 = "INSERT INTO chat_messages (conversation_id, sender_id, message, message_status) VALUES (?, ?, ?, ?)";
$replace2 = "INSERT INTO chat_messages (conversation_id, sender_id, message, is_urgent, message_status) VALUES (?, ?, ?, ?, ?)";

if (strpos($content, 'is_urgent, message_status') === false) {
    $content = str_replace($search2, $replace2, $content);
    echo "✅ PATCH 2: Updated INSERT query\n";
} else {
    echo "⚠️  PATCH 2: Already applied (skipped)\n";
}

// PATCH 3: Update bind_param for new parameter
$search3 = "\$stmt->execute([\$conversationId, \$user['id'], \$message, 'sent']);";
$replace3 = "\$stmt->execute([\$conversationId, \$user['id'], \$message, \$isUrgent, 'sent']);";

if (strpos($content, '$message, $isUrgent') === false) {
    $content = str_replace($search3, $replace3, $content);
    echo "✅ PATCH 3: Updated execute() parameters\n";
} else {
    echo "⚠️  PATCH 3: Already applied (skipped)\n";
}

// PATCH 4: Add urgent flag to WebSocketNotifier call
// Find the WebSocketNotifier::notifyNewMessage call and modify it
$pattern = '/(WebSocketNotifier::notifyNewMessage\(\s*\$conversationId,\s*\$messageId,\s*\$user\["id"\],\s*\$user\["name"\],\s*\$user\["role"\],\s*\$isAdmin,\s*\$message,\s*\$createdAt,\s*\$sourceLang)\s*\);/s';

$replacement = '$1,' . "\n" . '            $isUrgent  // 🆕 URGENT flag for full-screen notifications' . "\n" . '        );';

if (strpos($content, '$isUrgent  // 🆕 URGENT flag') === false) {
    $content = preg_replace($pattern, $replacement, $content);
    echo "✅ PATCH 4: Added urgent parameter to WebSocketNotifier\n";
} else {
    echo "⚠️  PATCH 4: Already applied (skipped)\n";
}

// Write patched content
file_put_contents($sendPhpPath, $content);

echo "\n🎉 Patching complete! send.php now supports URGENT notifications.\n";
echo "Location: $sendPhpPath\n";
