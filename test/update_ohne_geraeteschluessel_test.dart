// Die Update-Prüfung schickt den Geräteschlüssel nicht an GitHub.
//
// Bis zum 17.10.2026 ging bei jeder Prüfung `X-Device-Key` an github.com —
// alle 5 Minuten aus der Fußleiste, alle 15 aus dem Dashboard. Mit diesem
// Schlüssel meldet sich die App bei UNSEREM Server an; GitHub ist ein Dritter,
// und die Versionsdatei dort ist öffentlich.
//
// ⚠️ Der „Server“ hier ist nur eine Attrappe im Test (HttpOverrides): sie merkt
// sich, wohin gefragt wurde und mit welchen Kopfzeilen, und antwortet mit einem
// Manifest. Nichts davon geht ins Netz, an der App ändert sie nichts.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/services/device_key_service.dart';
import 'package:icd360sev_schatzmeister/services/update_service.dart';

const _schluessel = 'test-geraeteschluessel-0123456789';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final attrappe = _Attrappe();

  setUpAll(() {
    // Vor dem ersten UpdateService(): der Dienst baut seinen HttpClient genau
    // einmal, im Konstruktor des Singletons.
    HttpOverrides.global = attrappe;
  });

  setUp(attrappe.anfragen.clear);

  // Reihenfolge zählt: der Geräteschlüssel bleibt nach dem Laden im Dienst.
  test('ohne Geräteschlüssel wird trotzdem gefragt (frisch installiert)', () async {
    FlutterSecureStorage.setMockInitialValues({});
    expect(DeviceKeyService().deviceKey, isNull, reason: 'Vorbedingung');

    final info = await UpdateService().checkForUpdate();

    expect(attrappe.anfragen, hasLength(1));
    expect(attrappe.anfragen.single.uri.toString(), UpdateService.versionUrl);
    expect(info?.version, '99.0.0', reason: 'das Manifest wird weiter gelesen');
  });

  test('mit Geräteschlüssel geht er NICHT an GitHub', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'device_key': _schluessel, 'device_id': 'test-geraet'});
    await DeviceKeyService().loadStoredDeviceKey();
    expect(DeviceKeyService().deviceKey, _schluessel,
        reason: 'Vorbedingung — sonst prüfte der Test nichts');

    final info = await UpdateService().checkForUpdate();

    final anfrage = attrappe.anfragen.single;
    expect(anfrage.uri.host, 'github.com');
    expect(anfrage.koepfe.keys, isNot(contains('x-device-key')));
    for (final kopf in anfrage.koepfe.entries) {
      expect(kopf.value.join(','), isNot(contains(_schluessel)),
          reason: 'Kopfzeile ${kopf.key}');
    }
    expect(info?.buildNumber, 9900);
  });
}

/// Was die Attrappe von einer Anfrage behält.
class _Anfrage {
  _Anfrage(this.uri, this.koepfe);
  final Uri uri;
  final Map<String, List<String>> koepfe;
}

/// Antwortet auf jede Anfrage mit einem Manifest, wie es build-android.yml
/// als Release-Datei hochlädt.
class _Attrappe extends HttpOverrides {
  final anfragen = <_Anfrage>[];

  static final _manifest = utf8.encode(jsonEncode({
    'success': true,
    'version': '99.0.0',
    'build_number': 9900,
    'download_url':
        'https://github.com/ICD360S-e-V/schatzmeister/releases/download/v99.0.0/schatzmeister.apk',
    'changelog': '',
  }));

  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(this);
}

class _Client implements HttpClient {
  _Client(this._attrappe);
  final _Attrappe _attrappe;

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Anfrageobjekt(method, url, _attrappe);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Koepfe implements HttpHeaders {
  final werte = <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      werte[name.toLowerCase()] = ['$value'];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      (werte[name.toLowerCase()] ??= []).add('$value');
  @override
  List<String>? operator [](String name) => werte[name.toLowerCase()];
  @override
  String? value(String name) => werte[name.toLowerCase()]?.join(',');
  @override
  void forEach(void Function(String name, List<String> values) action) =>
      werte.forEach(action);
  @override
  ContentType? contentType;
  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Anfrageobjekt implements HttpClientRequest {
  _Anfrageobjekt(this.method, this.uri, this._attrappe);
  final _Attrappe _attrappe;

  @override
  final String method;
  @override
  final Uri uri;
  @override
  final _Koepfe headers = _Koepfe();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;
  @override
  bool bufferOutput = true;
  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<HttpClientResponse> close() async {
    _attrappe.anfragen.add(_Anfrage(uri, Map.of(headers.werte)));
    return _Antwort(_Attrappe._manifest);
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Antwort extends Stream<List<int>> implements HttpClientResponse {
  _Antwort(this._bytes) {
    headers.set('content-type', 'application/json; charset=utf-8');
  }
  final List<int> _bytes;

  @override
  int get statusCode => 200;
  @override
  final HttpHeaders headers = _Koepfe();
  @override
  String get reasonPhrase => 'OK';
  @override
  int get contentLength => _bytes.length;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => false;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.fromIterable([_bytes]).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
