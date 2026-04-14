# Security Audit Report - ICD360S e.V. Vorsitzer Portal
**Date:** 2026-02-10
**Version Audited:** 1.0.24+25
**Auditor:** Claude Code AI Security Analysis
**Platforms:** Cross-Platform (Windows, macOS, Linux, Android, iOS)

---

## Executive Summary

This security audit identified **4 CRITICAL**, **3 HIGH**, and **5 MEDIUM** risk vulnerabilities in the ICD360S Vorsitzer Portal application. The most severe issues involve **disabled SSL certificate validation** (allowing man-in-the-middle attacks) and **insecure storage of JWT authentication tokens** in plain text.

**Risk Level: 🔴 CRITICAL - Immediate Action Required**

---

## Critical Vulnerabilities (🔴 CRITICAL - Fix Immediately!)

### 1. SSL Certificate Validation Completely Disabled
**File:** `lib/services/api_service.dart` (lines 26-28)
**File:** `lib/services/device_key_service.dart` (lines 33-35)
**Severity:** 🔴 **CRITICAL**
**CVSS Score:** 9.8 (Critical)

**Vulnerability:**
```dart
final httpClient = HttpClient()
  ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
_client = IOClient(httpClient);
```

**Impact:**
- **Allows ALL SSL certificates** including self-signed and invalid ones
- **Man-in-the-middle (MITM) attacks** are trivially easy
- Attackers can intercept ALL traffic including passwords, JWT tokens, and sensitive data
- Completely defeats HTTPS security

**Attack Scenario:**
1. Attacker sets up Wi-Fi hotspot or compromises network
2. Intercepts HTTPS traffic with fake certificate
3. App accepts fake certificate due to disabled validation
4. Attacker reads/modifies all API requests including login credentials

**Recommended Fix:**
```dart
// REMOVE badCertificateCallback completely!
final httpClient = HttpClient();
_client = IOClient(httpClient);

// OR implement proper SSL pinning:
final httpClient = HttpClient()
  ..badCertificateCallback = (X509Certificate cert, String host, int port) {
    // Only accept your specific certificate
    const expectedSHA256 = 'YOUR_CERT_SHA256_FINGERPRINT';
    return sha256.convert(cert.der).toString() == expectedSHA256;
  };
```

**References:**
- [OWASP: Intercepting Flutter HTTPS Traffic](https://mas.owasp.org/MASTG/techniques/android/MASTG-TECH-0109/)
- [Flutter Security Best Practices](https://solguruz.com/blog/flutter-security-best-practices/)

---

### 2. JWT Tokens Stored in Plain Text (SharedPreferences)
**File:** `lib/services/api_service.dart` (lines 43-63)
**Severity:** 🔴 **CRITICAL**
**CVSS Score:** 8.5 (High)

**Vulnerability:**
```dart
Future<void> saveTokens(String token, String refreshToken) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('access_token', token);        // ❌ PLAIN TEXT!
  await prefs.setString('refresh_token', refreshToken); // ❌ PLAIN TEXT!
  _token = token;
  _refreshToken = refreshToken;
}
```

**Impact:**
- JWT tokens stored **unencrypted** on disk
- Anyone with file system access can steal tokens
- Tokens persist even after app uninstall (on some platforms)
- Enables **session hijacking** and **account takeover**

**Current Storage Location:**
- **Windows:** `%APPDATA%\com.icd360sev\shared_preferences\shared_preferences.xml` (plain XML)
- **macOS:** `~/Library/Preferences/com.icd360sev.icd360sev_vorsitzer.plist` (plain text)
- **Linux:** `~/.local/share/com.icd360sev/shared_preferences.xml` (plain text)

**Recommended Fix:**
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final _secureStorage = const FlutterSecureStorage();

  Future<void> saveTokens(String token, String refreshToken) async {
    // ✅ ENCRYPTED storage using Keychain (iOS/macOS) or KeyStore (Android/Windows)
    await _secureStorage.write(key: 'access_token', value: token);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    _token = token;
    _refreshToken = refreshToken;
  }

  Future<void> loadTokens() async {
    _token = await _secureStorage.read(key: 'access_token');
    _refreshToken = await _secureStorage.read(key: 'refresh_token');
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    _token = null;
    _refreshToken = null;
  }
}
```

**References:**
- [I Found Some Best Ways To Store JWT in Flutter](https://medium.com/@rk0936626/i-found-some-best-ways-to-store-jwt-json-web-token-in-flutter-a72b93e8eba2)
- [JSON Web Token (JWT) in Flutter: Secure Authentication](https://medium.com/@punithsuppar7795/json-web-token-jwt-in-flutter-secure-authentication-and-best-practices-6164ef3822a0)

---

### 3. Hardcoded API Key in Source Code
**File:** `lib/services/api_service.dart` (line 14)
**Severity:** 🔴 **CRITICAL**
**CVSS Score:** 7.5 (High)

**Vulnerability:**
```dart
static const String _legacyApiKey = 'ICD360SEV_SECRET_KEY_2026_SECURE_2e43f26903d486916dc697a1e8a0d9b2';
```

**Impact:**
- API key visible in source code and compiled binary
- Easy to extract via reverse engineering
- Enables **API abuse** and **unauthorized access**
- Compromises **legacy client authentication**

**Attack Methods:**
1. Decompile `.apk` or `.exe` → strings extraction
2. Memory dump of running process
3. Network traffic inspection (if used in headers)

**Recommended Fix:**
```dart
// ❌ REMOVE hardcoded key completely!

// Option 1: Use only Device Key (recommended)
Map<String, String> get _headers {
  final deviceKey = _deviceKeyService.deviceKey;
  if (deviceKey == null) {
    throw Exception('Device not registered');
  }
  return {
    'Content-Type': 'application/json',
    'X-Device-Key': deviceKey, // ✅ Dynamic per-device key
    if (_token != null) 'Authorization': 'Bearer $_token',
  };
}

// Option 2: Environment variables (for API keys that MUST exist)
// Use flutter run --dart-define=API_KEY=xxx
static const String _apiKey = String.fromEnvironment('API_KEY', defaultValue: '');
```

**References:**
- [Flutter Security: Secure API Keys](https://quokkalabs.com/blog/comprehensive-checklist-for-ensuring-security-in-flutter-apps/)
- [OWASP: Hardcoded Secrets](https://owasp.org/www-project-mobile-app-security/)

---

### 4. User Credentials Stored Persistently Without Explicit User Consent
**File:** `lib/screens/login_screen.dart` (lines 47-48)
**Severity:** 🔴 **CRITICAL** (GDPR/Privacy Violation)
**CVSS Score:** 7.2 (High)

**Vulnerability:**
```dart
final savedMitgliedernummer = await _secureStorage.read(key: 'mitgliedernummer');
final savedPassword = await _secureStorage.read(key: 'password');
```

**Impact:**
- **Passwords stored on disk** (even if encrypted)
- Violates GDPR Article 25 (Data Protection by Design)
- Violates **principle of least privilege**
- If device is stolen/compromised, attacker can extract password

**Best Practices Violation:**
- Passwords should **NEVER** be stored, even encrypted
- Use **refresh tokens** instead for persistent sessions
- OAuth2 standard: store only refresh tokens, never passwords

**Recommended Fix:**
```dart
// ❌ NEVER store passwords!
// ✅ Use refresh tokens instead

// On login success:
Future<void> _handleLoginSuccess(Map<String, dynamic> data) async {
  // Save tokens only (NOT password!)
  await _secureStorage.write(key: 'refresh_token', value: data['refresh_token']);

  // Save username ONLY (for display, not auth)
  await _secureStorage.write(key: 'mitgliedernummer', value: _mitgliedernummerController.text);

  // ❌ DELETE password from memory immediately
  _loginPasswordController.clear();
}

// On auto-login:
Future<void> _autoLogin() async {
  final refreshToken = await _secureStorage.read(key: 'refresh_token');
  if (refreshToken != null) {
    // Use refresh token to get new access token
    await _apiService.refreshAccessToken(refreshToken);
    // Navigate to dashboard
  }
}
```

**References:**
- [OWASP: Insecure Authentication](https://docs.talsec.app/appsec-articles/articles/owasp-top-10-for-flutter-m3-insecure-authentication-and-authorization-in-flutter)
- [Flutter App Security Best Practices](https://talent500.com/blog/flutter-app-security-best-practices/)

---

## High Risk Vulnerabilities (🟠 HIGH - Fix Within 7 Days)

### 5. No Input Validation for SQL Injection on Backend
**File:** Multiple API endpoints (client-side OK, backend unknown)
**Severity:** 🟠 **HIGH**
**CVSS Score:** 8.0 (High)

**Observation:**
- Client sends data to PHP backend (e.g., `/api/auth/login_vorsitzer.php`)
- No evidence of parameterized queries in PHP code (not audited)
- Vulnerable to SQL injection if backend uses string concatenation

**Recommended Backend Fix (PHP):**
```php
// ❌ VULNERABLE:
$query = "SELECT * FROM users WHERE mitgliedernummer = '$mitgliedernummer'";

// ✅ SECURE (Prepared Statements):
$stmt = $conn->prepare("SELECT * FROM users WHERE mitgliedernummer = ?");
$stmt->bind_param("s", $mitgliedernummer);
$stmt->execute();
```

**Client-Side Validation (Defense in Depth):**
```dart
// Add input sanitization in Flutter
String sanitizeMitgliedernummer(String input) {
  // Only allow: letters, numbers, and specific prefixes (V, S, K, MG)
  return input.replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
```

---

### 6. No Rate Limiting on Login Attempts (Client-Side)
**File:** `lib/screens/login_screen.dart`
**Severity:** 🟠 **HIGH**
**CVSS Score:** 7.5 (High)

**Vulnerability:**
- No local rate limiting on login attempts
- Enables **brute-force attacks** if server rate limiting is bypassed
- No CAPTCHA or progressive delay

**Recommended Fix:**
```dart
class _LoginScreenState extends State<LoginScreen> {
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;

  Future<void> _login() async {
    // Check rate limit
    if (_failedAttempts >= 5) {
      final now = DateTime.now();
      if (_lastFailedAttempt != null) {
        final diff = now.difference(_lastFailedAttempt!);
        if (diff.inMinutes < 5) {
          setState(() {
            _loginErrorMessage = 'Zu viele Versuche. Bitte warten Sie 5 Minuten.';
          });
          return;
        } else {
          // Reset after cooldown
          _failedAttempts = 0;
        }
      }
    }

    // Attempt login
    final result = await _apiService.login(...);

    if (!result['success']) {
      _failedAttempts++;
      _lastFailedAttempt = DateTime.now();

      // Progressive delay: 2^n seconds
      await Future.delayed(Duration(seconds: math.pow(2, _failedAttempts).toInt()));
    } else {
      _failedAttempts = 0;
    }
  }
}
```

---

### 7. Sensitive Data in Logs
**File:** Multiple files using `LoggerService`
**Severity:** 🟠 **HIGH**
**CVSS Score:** 6.5 (Medium)

**Vulnerability:**
- Logs may contain sensitive data (tokens, passwords, PII)
- Logs uploaded to server every 30 seconds (`logger_service.dart`)
- No log sanitization before upload

**Recommended Fix:**
```dart
class LoggerService {
  static final _sensitivePatterns = [
    RegExp(r'password["\s:=]+[^\s,}]+', caseSensitive: false),
    RegExp(r'token["\s:=]+[^\s,}]+', caseSensitive: false),
    RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}'), // Email
  ];

  String _sanitize(String message) {
    var sanitized = message;
    for (var pattern in _sensitivePatterns) {
      sanitized = sanitized.replaceAll(pattern, '[REDACTED]');
    }
    return sanitized;
  }

  void info(String message, {String? tag}) {
    final sanitized = _sanitize(message);
    // ... log sanitized message
  }
}
```

---

## Medium Risk Vulnerabilities (🟡 MEDIUM - Fix Within 30 Days)

### 8. No Certificate Pinning
**Severity:** 🟡 **MEDIUM**
**CVSS Score:** 6.0 (Medium)

**Issue:**
- Even after fixing SSL validation, no certificate pinning
- Vulnerable to compromised Certificate Authorities

**Recommended Fix:**
```dart
import 'package:http_certificate_pinning/http_certificate_pinning.dart';

final client = HttpCertificatePinning.createClient(
  pinnedCertificates: [
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // Your cert
  ],
);
```

---

### 9. No JWT Expiration Check on Client
**File:** `lib/services/api_service.dart`
**Severity:** 🟡 **MEDIUM**
**CVSS Score:** 5.5 (Medium)

**Issue:**
- Client doesn't verify JWT expiration before API calls
- May send expired tokens unnecessarily

**Recommended Fix:**
```dart
import 'package:jwt_decoder/jwt_decoder.dart';

bool isTokenExpired() {
  if (_token == null) return true;
  return JwtDecoder.isExpired(_token!);
}

Future<void> _ensureValidToken() async {
  if (isTokenExpired()) {
    await refreshAccessToken(_refreshToken!);
  }
}
```

---

### 10. Auto-Login Enabled by Default
**File:** `lib/screens/login_screen.dart` (line 50)
**Severity:** 🟡 **MEDIUM**
**CVSS Score:** 5.0 (Medium)

**Issue:**
```dart
final autoLogin = prefs.getBool('auto_login') ?? true; // ❌ Default TRUE
```

**Privacy Risk:**
- Auto-login enabled without explicit user consent
- Violates principle of **explicit consent**

**Recommended Fix:**
```dart
final autoLogin = prefs.getBool('auto_login') ?? false; // ✅ Default FALSE
```

---

### 11. No Protection Against Screen Recording (Desktop)
**Severity:** 🟡 **MEDIUM**
**CVSS Score:** 4.5 (Medium)

**Issue:**
- Desktop apps don't block screen recording
- Sensitive data (passwords, PII) can be captured

**Recommended Fix:**
- Windows: Use `SetWindowDisplayAffinity` API
- macOS: Use `windowLevel` and `NSWindow.SharingType`

---

### 12. WebSocket Messages Not Encrypted End-to-End
**File:** `lib/services/chat_service.dart`
**Severity:** 🟡 **MEDIUM**
**CVSS Score:** 6.0 (Medium)

**Issue:**
- WebSocket uses WSS (TLS), but messages not end-to-end encrypted
- Server can read all messages in plain text

**Recommended Fix:**
```dart
// Encrypt messages before sending
final encrypted = encryptAES256(message, sharedKey);
_channel.sink.add(jsonEncode({'type': 'message', 'data': encrypted}));

// Decrypt on receive
final decrypted = decryptAES256(data['data'], sharedKey);
```

---

## Positive Security Findings ✅

1. ✅ **FlutterSecureStorage used for credentials** (`login_screen.dart`)
2. ✅ **Device Key system** prevents API abuse from non-installed clients
3. ✅ **JWT-based authentication** (better than session cookies)
4. ✅ **HTTPS used for all API calls** (but validation disabled!)
5. ✅ **Password fields use obscureText** (UI security)
6. ✅ **No hardcoded credentials** in backend connection strings
7. ✅ **Cross-platform secure storage** with SharedPreferences fallback for macOS

---

## Security Testing Tools Recommended

### Static Analysis:
- **Dart Analyzer**: `flutter analyze` (built-in)
- **SonarQube** with Dart plugin
- **OWASP Dependency-Check**: Check for vulnerable packages

### Dynamic Analysis:
- **OWASP ZAP**: HTTP traffic interception
- **Burp Suite**: API security testing
- **Frida**: Runtime application instrumentation
- **MobSF (Mobile Security Framework)**: Comprehensive mobile app analysis

### Penetration Testing:
```bash
# Install OWASP ZAP
docker pull zaproxy/zap-stable

# Run security scan
docker run -t zaproxy/zap-stable zap-baseline.py \
  -t https://icd360sev.icd360s.de
```

---

## Compliance and Regulatory Issues

### GDPR Violations:
1. ❌ **Password storage** (Article 25: Data Protection by Design)
2. ❌ **Auto-login default ON** (Article 7: Explicit Consent)
3. ❌ **No data retention policy** for stored credentials

### OWASP Mobile Top 10 (2024):
1. ❌ **M3: Insecure Authentication** (password storage)
2. ❌ **M5: Insecure Communication** (SSL validation disabled)
3. ❌ **M2: Inadequate Supply Chain Security** (hardcoded API key)

---

## Remediation Priority

### Immediate (Within 24 Hours):
1. 🔴 Enable SSL certificate validation
2. 🔴 Move JWT tokens to FlutterSecureStorage
3. 🔴 Remove hardcoded API key

### Short-term (Within 7 Days):
4. 🟠 Remove password storage (use refresh tokens only)
5. 🟠 Add input sanitization
6. 🟠 Implement rate limiting

### Medium-term (Within 30 Days):
7. 🟡 Implement certificate pinning
8. 🟡 Add JWT expiration validation
9. 🟡 Auto-login default to FALSE
10. 🟡 Encrypt WebSocket messages end-to-end

---

## References and Resources

### Official Documentation:
- [Flutter Security](https://docs.flutter.dev/security)
- [flutter_secure_storage Package](https://pub.dev/packages/flutter_secure_storage)

### Security Best Practices:
- [Flutter Security Best Practices: Protect Data and Code](https://solguruz.com/blog/flutter-security-best-practices/)
- [Comprehensive Checklist for Ensuring Security in Flutter Apps](https://quokkalabs.com/blog/comprehensive-checklist-for-ensuring-security-in-flutter-apps/)
- [Flutter App Security Best Practices for Fintech](https://7span.com/blog/flutter-app-security-best-practices)

### OWASP Resources:
- [OWASP Mobile Application Security](https://mas.owasp.org/)
- [OWASP Top 10 For Flutter - M3: Insecure Authentication](https://docs.talsec.app/appsec-articles/articles/owasp-top-10-for-flutter-m3-insecure-authentication-and-authorization-in-flutter)
- [How to Secure Flutter Against OWASP Mobile Top 10](https://8ksec.io/securing-flutter-applications/)

### JWT Security:
- [I Found Some Best Ways To Store JWT in Flutter](https://medium.com/@rk0936626/i-found-some-best-ways-to-store-jwt-json-web-token-in-flutter-a72b93e8eba2)
- [JSON Web Token (JWT) in Flutter: Secure Authentication and Best Practices](https://medium.com/@punithsuppar7795/json-web-token-jwt-in-flutter-secure-authentication-and-best-practices-6164ef3822a0)
- [Securely Storing JWTs in Flutter Web Apps](https://carmine.dev/posts/flutterwebjwt/)

### Testing Tools:
- [Mobile Security Testing Guide (OWASP MSTG)](https://owasp.org/www-project-mobile-security-testing-guide/)
- [Security Testing in Flutter](https://medium.com/@jhaym3s/security-testing-in-flutter-a1dcad8b5322)
- [Mobile App Security Testing for Flutter & Dart](https://www.blackduck.com/blog/mobile-app-security-testing-flutter-dart.html)

---

## Conclusion

The ICD360S Vorsitzer Portal requires **immediate security remediation** before production deployment. The disabled SSL validation and plain-text token storage create severe vulnerabilities that could lead to complete account compromise.

**Estimated Remediation Time:** 3-5 days for critical issues, 2-3 weeks for all issues.

**Next Steps:**
1. Fix all CRITICAL vulnerabilities immediately
2. Conduct penetration testing after fixes
3. Implement automated security scanning in CI/CD
4. Schedule quarterly security audits

---

**Report End**
