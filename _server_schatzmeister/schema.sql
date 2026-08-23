-- Aktivierungscodes für das Schatzmeister-Portal.
-- Bewusst eine EIGENE Tabelle, getrennt von vorsitzer_activation_codes:
-- andere Rolle, anderer Lebenszyklus, keine gemeinsame Angriffsfläche.
CREATE TABLE IF NOT EXISTS schatzmeister_activation_codes (
    id                 INT(11) NOT NULL AUTO_INCREMENT,
    user_id            INT(11) NOT NULL,
    code_hash          VARCHAR(255) NOT NULL,
    code_preview       VARCHAR(5) NOT NULL,
    generated_by       INT(11) NOT NULL,
    generated_at       TIMESTAMP NULL DEFAULT current_timestamp(),
    expires_at         TIMESTAMP NOT NULL,
    used_at            TIMESTAMP NULL DEFAULT NULL,
    used_by_device_id  VARCHAR(255) NULL DEFAULT NULL,
    used_from_ip       VARCHAR(45) NULL DEFAULT NULL,
    revoked_at         TIMESTAMP NULL DEFAULT NULL,
    revoked_by         INT(11) NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_user (user_id),
    KEY idx_expires (expires_at),
    KEY idx_generated_by (generated_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Fehlversuche für Rate-Limiting. Eigene Tabelle, damit ein Brute-Force
-- gegen das Schatzmeister-Portal nicht den Vorsitzer-Login mit aussperrt.
CREATE TABLE IF NOT EXISTS schatzmeister_code_attempts (
    id                INT(11) NOT NULL AUTO_INCREMENT,
    ip_address        VARCHAR(45) NULL DEFAULT NULL,
    mitgliedernummer  VARCHAR(20) NULL DEFAULT NULL,
    success           TINYINT(1) NOT NULL DEFAULT 0,
    attempted_at      TIMESTAMP NULL DEFAULT current_timestamp(),
    PRIMARY KEY (id),
    KEY idx_attempt_lookup (attempted_at, success)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
