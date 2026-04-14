<?php
/**
 * Patcher: Add urgent parameter to WebSocketNotifier
 * Date: 2026-02-11
 */

$filePath = '/var/www/icd360sev.icd360s.de/api/helpers/WebSocketNotifier.php';

if (!file_exists($filePath)) {
    die("Error: WebSocketNotifier.php not found\n");
}

$content = file_get_contents($filePath);

// Backup
file_put_contents($filePath . '.backup_' . date('Y-m-d_His'), $content);
echo "✅ Backup created\n";

// PATCH 1: Add $urgent parameter to function signature
$search1 = "string \$sourceLang = 'de'  // NEW: Source language for translation";
$replace1 = "string \$sourceLang = 'de',  // Source language for translation\n        int \$isUrgent = 0  // 🆕 URGENT flag for full-screen notifications";

if (strpos($content, '$isUrgent = 0') === false) {
    $content = str_replace($search1, $replace1, $content);
    echo "✅ PATCH 1: Added \$urgent parameter to signature\n";
} else {
    echo "⚠️  PATCH 1: Already applied\n";
}

// PATCH 2: Add urgent to broadcast array
$search2 = "'source_language' => \$sourceLang,  // NEW: Include in broadcast";
$replace2 = "'source_language' => \$sourceLang,\n            'urgent' => (bool)\$isUrgent,  // 🆕 URGENT flag for full-screen alert";

if (strpos($content, "'urgent' => (bool)") === false) {
    $content = str_replace($search2, $replace2, $content);
    echo "✅ PATCH 2: Added urgent to broadcast array\n";
} else {
    echo "⚠️  PATCH 2: Already applied\n";
}

// Write
file_put_contents($filePath, $content);

echo "\n🎉 WebSocketNotifier.php patched successfully!\n";
