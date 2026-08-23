<?php
/**
 * API Endpoint: Routine Executions (Admin only)
 * URL: /api/admin/routine_executions.php
 *
 * GET: List executions for a date range
 *   ?start_date=2026-03-03&end_date=2026-03-07 (week range)
 *   ?user_id=5 (optional filter)
 *   &auto_generate=1 (default 1, auto-creates missing executions)
 *
 * POST: Update execution status
 *   { "execution_id": 1, "status": "done", "notes": "Alles geprüft" }
 *   OR create: { "routine_id": 1, "scheduled_date": "2026-03-03", "status": "done" }
 */

define('API_ACCESS', true);
require_once '../config.php';
require_once __DIR__ . '/lib/sm_auth.php';
require_once __DIR__ . '/../helpers/routine_krypto.php';

validateApiKey();
blockBrowserAccess();

$authUserId = requireAuth();
// requireAdminRole() prueft auf 'vorsitzer' und sperrte damit genau die Rolle
// aus, fuer die dieses Namespace gedacht ist — Notizen und Routineaufgaben
// gaben dem Schatzmeister 403. Eigene Pruefung statt der Admin-Huelle:
smRequireSchatzmeister(getDBConnection());

// Get admin mitgliedernummer
try {
    $pdo = getDBConnection();
    $stmt = $pdo->prepare('SELECT mitgliedernummer FROM users WHERE id = ?');
    $stmt->execute([$authUserId]);
    $adminInfo = $stmt->fetch();
    $adminMnr = $adminInfo['mitgliedernummer'] ?? '';
} catch (Exception $e) {
    http_response_code(500);
    jsonResponse(false, [], 'Auth error');
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    handleGet($pdo, $adminMnr);
} elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
    handlePost($pdo, $adminMnr);
} else {
    http_response_code(405);
    jsonResponse(false, [], 'Method not allowed');
}

function handleGet($pdo, $adminMnr) {
    $startDate = $_GET['start_date'] ?? date('Y-m-d', strtotime('monday this week'));
    $endDate = $_GET['end_date'] ?? date('Y-m-d', strtotime('friday this week'));
    $filterUserId = $_GET['user_id'] ?? null;
    $autoGenerate = ($_GET['auto_generate'] ?? '1') === '1';

    try {
        // Get active routines (optionally filtered by user)
        $sql = 'SELECT r.*, u.name as member_name, u.mitgliedernummer as member_nummer
                FROM routines r
                JOIN users u ON r.user_id = u.id
                WHERE r.is_active = 1';
        $params = [];
        if ($filterUserId) {
            $sql .= ' AND r.user_id = ?';
            $params[] = $filterUserId;
        }
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $routines = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $routines = routineZeilenEntschluesseln($routines, ['title', 'description', 'category', 'notes', 'routine_title', 'routine_category']);

        // Auto-generate missing executions for the date range
        if ($autoGenerate) {
            $start = new DateTime($startDate);
            $end = new DateTime($endDate);

            foreach ($routines as $routine) {
                $dates = getScheduledDates($routine, $start, $end);
                foreach ($dates as $date) {
                    $dateStr = $date->format('Y-m-d');
                    // Check if execution already exists (using INSERT IGNORE with unique key)
                    $stmt = $pdo->prepare('
                        INSERT IGNORE INTO routine_executions (routine_id, scheduled_date, status)
                        VALUES (?, ?, "pending")
                    ');
                    $stmt->execute([$routine['id'], $dateStr]);
                }
            }
        }

        // Fetch all executions in range
        $sql = '
            SELECT re.*, r.title as routine_title, r.category as routine_category,
                   r.frequency, r.preferred_time, r.user_id, u.name as member_name, u.mitgliedernummer as member_nummer
            FROM routine_executions re
            JOIN routines r ON re.routine_id = r.id
            JOIN users u ON r.user_id = u.id
            WHERE re.scheduled_date BETWEEN ? AND ?
            AND r.is_active = 1
        ';
        $execParams = [$startDate, $endDate];
        if ($filterUserId) {
            $sql .= ' AND r.user_id = ?';
            $execParams[] = $filterUserId;
        }
        $sql .= ' ORDER BY re.scheduled_date ASC, u.name ASC, r.title ASC';

        $stmt = $pdo->prepare($sql);
        $stmt->execute($execParams);
        $executions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $executions = routineZeilenEntschluesseln($executions, ['title', 'description', 'category', 'notes', 'routine_title', 'routine_category']);

        // Stats for the week
        $totalExec = count($executions);
        $doneCount = 0;
        $pendingCount = 0;
        $skippedCount = 0;
        foreach ($executions as $ex) {
            if ($ex['status'] === 'done') $doneCount++;
            elseif ($ex['status'] === 'pending') $pendingCount++;
            else $skippedCount++;
        }

        jsonResponse(true, [
            'executions' => $executions,
            'stats' => [
                'total' => $totalExec,
                'done' => $doneCount,
                'pending' => $pendingCount,
                'skipped' => $skippedCount,
            ]
        ]);
    } catch (Exception $e) {
        http_response_code(500);
        jsonResponse(false, [], 'Datenbankfehler: ' . $e->getMessage());
    }
}

function handlePost($pdo, $adminMnr) {
    $input = json_decode(file_get_contents('php://input'), true);

    $executionId = $input['execution_id'] ?? null;
    $routineId = $input['routine_id'] ?? null;
    $scheduledDate = $input['scheduled_date'] ?? null;
    $status = $input['status'] ?? null;
    $notes = isset($input['notes']) ? trim($input['notes']) : null;

    $validStatuses = ['pending', 'done', 'skipped'];
    if (!$status || !in_array($status, $validStatuses)) {
        http_response_code(400);
        jsonResponse(false, [], 'Ungültiger Status. Erlaubt: pending, done, skipped');
    }

    try {
        if ($executionId) {
            // Update existing execution
            $completedAt = ($status === 'done' || $status === 'skipped') ? date('Y-m-d H:i:s') : null;
            $completedBy = ($status === 'done' || $status === 'skipped') ? $adminMnr : null;

            $stmt = $pdo->prepare('
                UPDATE routine_executions
                SET status = ?, notes = ?, completed_by = ?, completed_at = ?
                WHERE id = ?
            ');
            $stmt->execute([$status, $notes, $completedBy, $completedAt, $executionId]);

            if ($stmt->rowCount() === 0) {
                http_response_code(404);
                jsonResponse(false, [], 'Ausführung nicht gefunden');
            }
        } elseif ($routineId && $scheduledDate) {
            // Create or update execution for specific date
            $completedAt = ($status === 'done' || $status === 'skipped') ? date('Y-m-d H:i:s') : null;
            $completedBy = ($status === 'done' || $status === 'skipped') ? $adminMnr : null;

            $stmt = $pdo->prepare('
                INSERT INTO routine_executions (routine_id, scheduled_date, status, notes, completed_by, completed_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE status = VALUES(status), notes = VALUES(notes),
                    completed_by = VALUES(completed_by), completed_at = VALUES(completed_at)
            ');
            $stmt->execute([$routineId, $scheduledDate, $status, $notes, $completedBy, $completedAt]);
        } else {
            http_response_code(400);
            jsonResponse(false, [], 'execution_id oder routine_id + scheduled_date erforderlich');
        }

        jsonResponse(true, [], 'Ausführung aktualisiert');
    } catch (Exception $e) {
        http_response_code(500);
        jsonResponse(false, [], 'Datenbankfehler: ' . $e->getMessage());
    }
}

/**
 * Calculate which dates a routine should execute in the given range
 */
function getScheduledDates($routine, DateTime $start, DateTime $end) {
    $dates = [];

    // Handle "once" frequency - single date, no weekday restriction
    if ($routine['frequency'] === 'once') {
        if (!empty($routine['once_date'])) {
            $onceDate = new DateTime($routine['once_date']);
            if ($onceDate >= $start && $onceDate <= $end) {
                $dates[] = $onceDate;
            }
        }
        return $dates;
    }

    $current = clone $start;

    while ($current <= $end) {
        $dow = (int)$current->format('N'); // 1=Mon, 7=Sun

        // Skip weekends
        if ($dow > 5) {
            $current->modify('+1 day');
            continue;
        }

        $shouldSchedule = false;

        switch ($routine['frequency']) {
            case 'daily':
                $shouldSchedule = true; // Every weekday
                break;

            case 'weekly':
                $shouldSchedule = ($dow == (int)$routine['day_of_week']);
                break;

            case 'monthly':
                $dom = (int)$current->format('j');
                $shouldSchedule = ($dom == (int)$routine['day_of_month']);
                break;

            case 'yearly':
                $dom = (int)$current->format('j');
                $month = (int)$current->format('n');
                $shouldSchedule = ($dom == (int)$routine['day_of_month'] && $month == (int)$routine['month_of_year']);
                break;
        }

        if ($shouldSchedule) {
            $dates[] = clone $current;
        }

        $current->modify('+1 day');
    }

    return $dates;
}
