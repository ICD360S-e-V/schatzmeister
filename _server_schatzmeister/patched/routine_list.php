<?php
/**
 * API Endpoint: List Routines (Admin only)
 * URL: /api/admin/routine_list.php
 * Method: GET
 * Params: ?user_id=5 (optional filter by member)
 *         ?category=Jobcenter (optional)
 *         ?active_only=1 (default 1)
 */

define('API_ACCESS', true);
require_once '../config.php';
require_once __DIR__ . '/lib/sm_auth.php';
require_once __DIR__ . '/../helpers/routine_krypto.php';

validateApiKey();
blockBrowserAccess();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    jsonResponse(false, [], 'Method not allowed');
}

$userId = requireAuth();
// requireAdminRole() prueft auf 'vorsitzer' und sperrte damit genau die Rolle
// aus, fuer die dieses Namespace gedacht ist — Notizen und Routineaufgaben
// gaben dem Schatzmeister 403. Eigene Pruefung statt der Admin-Huelle:
smRequireSchatzmeister(getDBConnection());

$filterUserId = $_GET['user_id'] ?? null;
$filterCategory = $_GET['category'] ?? null;
$activeOnly = ($_GET['active_only'] ?? '1') === '1';

try {
    $pdo = getDBConnection();

    $sql = '
        SELECT r.*, u.name as member_name, u.mitgliedernummer as member_nummer
        FROM routines r
        JOIN users u ON r.user_id = u.id
        WHERE 1=1
    ';
    $params = [];

    if ($activeOnly) {
        $sql .= ' AND r.is_active = 1';
    }
    if ($filterUserId) {
        $sql .= ' AND r.user_id = ?';
        $params[] = $filterUserId;
    }
    if ($filterCategory) {
        $sql .= ' AND r.category = ?';
        $params[] = $filterCategory;
    }

    $sql .= ' ORDER BY u.name ASC, r.title ASC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $routines = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $routines = routineZeilenEntschluesseln($routines, ['title', 'description', 'category', 'notes', 'routine_title', 'routine_category']);

    // Get distinct categories for filter
    $stmt = $pdo->prepare('SELECT DISTINCT category FROM routines WHERE category IS NOT NULL AND category != "" ORDER BY category');
    $stmt->execute();
    $categories = $stmt->fetchAll(PDO::FETCH_COLUMN);
    // ⚠️ Erst entschluesseln, DANN eindeutig machen. Jede Zeile hat ihren
    // eigenen Zufalls-IV, also ergibt dieselbe Kategorie jedes Mal eine
    // andere Chiffre — das SQL-seitige DISTINCT griff hier nie und die
    // Filterliste zeigte Dubletten. Galt schon fuer v2.
    $categories = array_values(array_unique(array_filter(
        array_map('routineEntschluesseln', $categories))));
    sort($categories);

    // Get stats
    $stmt = $pdo->prepare('SELECT COUNT(*) as total FROM routines WHERE is_active = 1');
    $stmt->execute();
    $totalActive = $stmt->fetch()['total'];

    $stmt = $pdo->prepare('SELECT COUNT(DISTINCT user_id) as cnt FROM routines WHERE is_active = 1');
    $stmt->execute();
    $totalMembers = $stmt->fetch()['cnt'];

    jsonResponse(true, [
        'routines' => $routines,
        'categories' => $categories,
        'stats' => [
            'total_active' => (int)$totalActive,
            'total_members' => (int)$totalMembers,
        ]
    ]);
} catch (Exception $e) {
    http_response_code(500);
    jsonResponse(false, [], 'Datenbankfehler: ' . $e->getMessage());
}
