import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'device_key_service.dart';

/// Member document model
class MemberDokument {
  final int id;
  final int userId;
  final String dokumentName;
  final String originalFilename;
  final String storedFilename;
  final int filesize;
  final String mimeType;
  final String? beschreibung;
  final String kategorie; // 'vereindokumente' or 'behoerde'
  final String? dokumentTyp;
  final DateTime? ablaufDatum;
  final bool isEncrypted;
  final int? daysUntilExpiry;
  final int uploadedBy;
  final String uploadedByName;
  final DateTime createdAt;

  MemberDokument({
    required this.id,
    required this.userId,
    required this.dokumentName,
    required this.originalFilename,
    required this.storedFilename,
    required this.filesize,
    required this.mimeType,
    this.beschreibung,
    required this.kategorie,
    this.dokumentTyp,
    this.ablaufDatum,
    this.isEncrypted = false,
    this.daysUntilExpiry,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.createdAt,
  });

  factory MemberDokument.fromJson(Map<String, dynamic> json) {
    return MemberDokument(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['user_id'] is int ? json['user_id'] : int.parse(json['user_id'].toString()),
      dokumentName: json['dokument_name'] ?? '',
      originalFilename: json['original_filename'] ?? '',
      storedFilename: json['stored_filename'] ?? '',
      filesize: json['filesize'] is int ? json['filesize'] : int.parse(json['filesize'].toString()),
      mimeType: json['mime_type'] ?? '',
      beschreibung: json['beschreibung'],
      kategorie: json['kategorie'] ?? 'vereindokumente',
      dokumentTyp: json['dokument_typ'],
      ablaufDatum: json['ablauf_datum'] != null ? DateTime.tryParse(json['ablauf_datum']) : null,
      isEncrypted: json['is_encrypted'] == 1 || json['is_encrypted'] == true,
      daysUntilExpiry: json['days_until_expiry'] != null ? (json['days_until_expiry'] is int ? json['days_until_expiry'] : int.tryParse(json['days_until_expiry'].toString())) : null,
      uploadedBy: json['uploaded_by'] is int ? json['uploaded_by'] : int.parse(json['uploaded_by'].toString()),
      uploadedByName: json['uploaded_by_name'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get filesizeFormatted {
    if (filesize < 1024) return '$filesize B';
    if (filesize < 1024 * 1024) return '${(filesize / 1024).toStringAsFixed(1)} KB';
    return '${(filesize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get fileExtension {
    final parts = originalFilename.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : '';
  }
}

/// DokumenteService - handles member document API calls
class DokumenteService {
  static const String baseUrl = 'https://icd360sev.icd360s.de/api';
  // ✅ SECURITY FIX: Removed hardcoded API key (extractable via reverse engineering)
  // All requests now use dynamic Device Key only

  late http.Client _client;
  final DeviceKeyService _deviceKeyService = DeviceKeyService();
  String? _token;

  // Singleton
  static final DokumenteService _instance = DokumenteService._internal();
  factory DokumenteService() => _instance;
  DokumenteService._internal() {
    _client = IOClient(HttpClient());
  }

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers {
    final deviceKey = _deviceKeyService.deviceKey;
    return {
      'Content-Type': 'application/json',
      'User-Agent': 'ICD360S-Schatzmeister/1.0',
      if (_token != null) 'Authorization': 'Bearer $_token',
      if (deviceKey != null) 'X-Device-Key': deviceKey,
    };
  }

  /// Get all documents for a user
  Future<List<MemberDokument>> getDokumente(int userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/schatzmeister/dokumente_list.php?user_id=$userId'),
        headers: _headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final list = data['dokumente'] as List;
        return list.map((d) => MemberDokument.fromJson(d)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Download a document (returns base64 data)
  Future<Map<String, dynamic>?> downloadDokument(int id) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/schatzmeister/dokumente_download.php'),
        headers: _headers,
        body: jsonEncode({'id': id}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'filename': data['filename'],
          'mime_type': data['mime_type'],
          'filesize': data['filesize'],
          'data': data['data'], // base64
        };
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
