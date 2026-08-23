<?php
/**
 * Übersetzungs-Helfer für das Schatzmeister-Namespace.
 *
 * Wortgleich übernommen aus /api/tickets/list.php (dort stehen die Funktionen
 * inline). Kopiert statt eingebunden, damit dieses Namespace nicht an einem
 * fremden Endpunkt hängt — dieselbe Trennung wie bei sm_auth.php.
 *
 * Gemeinsam genutzt bleibt nur, was ohnehin Infrastruktur ist: config.php und
 * helpers/TranslationHelper.php. Der Cache (`translation_cache`) ist derselbe,
 * es entstehen also keine doppelten Übersetzungsläufe.
 */

if (!defined("API_ACCESS")) {
    http_response_code(403);
    exit("Direct access not permitted");
}

define("TRANSLATION_API_URL", "http://127.0.0.1:5000/translate");
define("DEFAULT_LANGUAGE", "de");
// Alle 28 Werte des ENUM `users.preferred_language`. Der NLLB-Dienst
// kennt seit 2026-08-04 jeden davon (LANG_MAP in /opt/nllb-translate/app.py);
// was hier fehlt, faellt stillschweigend auf DEFAULT_LANGUAGE zurueck.
$SUPPORTED_LANGUAGES = [
    "de", "en", "ro", "ru", "uk", "tr", "ar", "fr", "es", "it", "pl", "nl",
    "pt", "cs", "sk", "hu", "bg", "hr", "sr", "sl", "el", "da", "sv", "nb",
    "fi", "et", "lt", "lv",
];

function detectLanguage(string $text, ?string $absenderSprache = null): ?string {
    // Die Schrift zuerst — sie ist eindeutig, Diakritika sind es nicht.
    if (preg_match("/[\x{0600}-\x{06FF}]/u", $text)) return 'ar';
    if (preg_match("/[\x{0370}-\x{03FF}]/u", $text)) return 'el';
    if (preg_match("/[\x{0400}-\x{04FF}]/u", $text)) {
        // Kyrillisch teilen sich ru, uk, bg und sr. Steht der Absender auf einer
        // davon, ist das die verlaesslichste Angabe — sonst waere jede
        // bulgarische und serbische Nachricht als Russisch uebersetzt worden.
        if (in_array($absenderSprache, ['ru', 'uk', 'bg', 'sr'], true)) return $absenderSprache;
        if (preg_match("/[іїєґ]/ui", $text)) return 'uk';
        return 'ru';
    }
    // Lateinschrift teilen sich 20 der 28 Sprachen. Nur diese drei Marker
    // gehoeren genau einer davon. Bewusst NICHT dabei: ae/oe/ue (auch
    // Finnisch, Schwedisch, Estnisch, Ungarisch, Tuerkisch) und c-Cedille /
    // s-Cedille (auch Rumaenisch, Kroatisch, Tuerkisch).
    if (preg_match("/[ăâîȘșȚț]/u", $text)) return 'ro';
    if (preg_match("/[ğıĞİ]/u", $text)) return 'tr';
    if (preg_match("/ß/u", $text)) return 'de';
    // Kein eindeutiges Zeichen: die eingestellte Sprache des Absenders ist die
    // bessere Schaetzung als eine Zeichenklasse, die auf sechs Sprachen passt.
    return $absenderSprache;
}

function getCachedTranslation(PDO $pdo, string $text, string $sourceLang, string $targetLang): ?string {
    $hash = hash("sha256", $text . "|" . $sourceLang . "|" . $targetLang);
    $stmt = $pdo->prepare("SELECT translated_text FROM translation_cache WHERE message_hash = ?");
    $stmt->execute([$hash]);
    $result = $stmt->fetch();
    return $result ? $result["translated_text"] : null;
}

function saveTranslationCache(PDO $pdo, string $text, string $sourceLang, string $targetLang, string $translatedText): void {
    $hash = hash("sha256", $text . "|" . $sourceLang . "|" . $targetLang);
    try {
        $stmt = $pdo->prepare("INSERT INTO translation_cache (message_hash, source_lang, target_lang, original_text, translated_text) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE translated_text = VALUES(translated_text)");
        $stmt->execute([$hash, $sourceLang, $targetLang, $text, $translatedText]);
    } catch (PDOException $e) {}
}

function translateText(PDO $pdo, string $text, string $sourceLang, string $targetLang): ?string {
    // TICKETS_TRANSLATION_PAUSE: skip until timestamp in /tmp/tickets_translation_pause_until.txt is in the past
    static $__pauseChecked = false; static $__paused = false;
    if (!$__pauseChecked) { $__pauseChecked = true; $pf = "/tmp/tickets_translation_pause_until.txt"; if (file_exists($pf)) { $until = trim(@file_get_contents($pf)); $ts = strtotime($until); if ($ts !== false && $ts > time()) $__paused = true; } }
    if ($__paused) return null;

    if ($sourceLang === $targetLang) return null;
    $cached = getCachedTranslation($pdo, $text, $sourceLang, $targetLang);
    if ($cached !== null) return $cached;
    // TICKETS_NIGHT_ONLY: skip MADLAD call outside 00:00-07:59 (avoid blocking chat)
    $h = (int)date('H');
    if ($h >= 8) return null;


    $payload = json_encode(["text" => $text, "source_lang" => $sourceLang, "target_lang" => $targetLang]);
    $ch = curl_init(TRANSLATION_API_URL);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_POST => true, CURLOPT_POSTFIELDS => $payload, CURLOPT_HTTPHEADER => ["Content-Type: application/json"], CURLOPT_TIMEOUT => 120, CURLOPT_CONNECTTIMEOUT => 5]);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode === 200 && $response) {
        $data = json_decode($response, true);
        if (isset($data["translated_text"])) {
            saveTranslationCache($pdo, $text, $sourceLang, $targetLang, $data["translated_text"]);
            return $data["translated_text"];
        }
    }
    return null;
}

function translateField(PDO $pdo, string $text, string $userLang, array $supportedLangs, ?string $creatorLang = null): array {
    if (empty(trim($text))) return ["text" => $text, "original" => null, "is_translated" => false];
    $sourceLang = detectLanguage($text, $creatorLang) ?? DEFAULT_LANGUAGE;
    if (!in_array($sourceLang, $supportedLangs)) $sourceLang = DEFAULT_LANGUAGE;
    if ($sourceLang !== $userLang) {
        $translated = translateText($pdo, $text, $sourceLang, $userLang);
        if ($translated !== null) return ["text" => $translated, "original" => $text, "is_translated" => true];
    }
    return ["text" => $text, "original" => null, "is_translated" => false];
}

