import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';

import '../repositories/financial_repository.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupInspection {
  const BackupInspection({
    required this.validEnvelope,
    required this.checksumValid,
    required this.decrypted,
    required this.createdAt,
    required this.schemaVersion,
    required this.incomeCount,
    required this.expenseCount,
    required this.liabilityCount,
    required this.categoryCount,
    required this.fileBytes,
    this.error,
  });

  final bool validEnvelope;
  final bool checksumValid;
  final bool decrypted;
  final String? createdAt;
  final int? schemaVersion;
  final int incomeCount;
  final int expenseCount;
  final int liabilityCount;
  final int categoryCount;
  final int fileBytes;
  final String? error;

  bool get healthy => validEnvelope && checksumValid && decrypted && error == null;
  int get recordCount => incomeCount + expenseCount + liabilityCount + categoryCount;
}

class BackupService {
  BackupService(this.repository);
  final FinancialRepository repository;
  static const _format = 'finaro-backup';
  static const _version = 1;
  static const _iterations = 120000;

  Future<String?> exportEncrypted({required String password}) async {
    _validatePassword(password);
    final payload = await _snapshot();
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveKey(password, salt);
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: key,
      nonce: nonce,
    );
    final checksum = await Sha256().hash(box.cipherText);
    final envelope = <String, dynamic>{
      'format': _format,
      'version': _version,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'kdf': {'name': 'PBKDF2-HMAC-SHA256', 'iterations': _iterations},
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'mac': base64Encode(box.mac.bytes),
      'ciphertext': base64Encode(box.cipherText),
      'checksumSha256': base64Encode(checksum.bytes),
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
    return FilePicker.platform.saveFile(
      dialogTitle: 'ذخیره نسخه پشتیبان Finaro',
      fileName: 'finaro-backup-${_stamp()}.finaro',
      bytes: bytes,
    );
  }

  Future<BackupInspection?> inspectSelected({required String password}) async {
    _validatePassword(password);
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'بررسی نسخه پشتیبان Finaro',
      type: FileType.custom,
      allowedExtensions: const ['finaro'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return null;
    return inspectBytes(result.files.single.bytes!, password: password);
  }

  Future<BackupInspection> inspectBytes(Uint8List bytes, {String? password}) async {
    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      envelope = decoded;
      if (envelope['format'] != _format || envelope['version'] != _version) {
        throw const FormatException();
      }
      _validateEnvelopeShape(envelope);
    } catch (_) {
      return BackupInspection(
        validEnvelope: false,
        checksumValid: false,
        decrypted: false,
        createdAt: null,
        schemaVersion: null,
        incomeCount: 0,
        expenseCount: 0,
        liabilityCount: 0,
        categoryCount: 0,
        fileBytes: bytes.length,
        error: 'ساختار فایل نسخه پشتیبان معتبر نیست.',
      );
    }

    try {
      final ciphertext = base64Decode(envelope['ciphertext'] as String);
      final expected = base64Decode(envelope['checksumSha256'] as String);
      final actual = (await Sha256().hash(ciphertext)).bytes;
      final checksumValid = _sameBytes(expected, actual);
      if (!checksumValid) {
        return BackupInspection(
          validEnvelope: true,
          checksumValid: false,
          decrypted: false,
          createdAt: envelope['createdAt'] as String?,
          schemaVersion: null,
          incomeCount: 0,
          expenseCount: 0,
          liabilityCount: 0,
          categoryCount: 0,
          fileBytes: bytes.length,
          error: 'یکپارچگی فایل تأیید نشد؛ فایل احتمالاً ناقص یا دستکاری شده است.',
        );
      }
      if (password == null) {
        return BackupInspection(
          validEnvelope: true,
          checksumValid: true,
          decrypted: false,
          createdAt: envelope['createdAt'] as String?,
          schemaVersion: null,
          incomeCount: 0,
          expenseCount: 0,
          liabilityCount: 0,
          categoryCount: 0,
          fileBytes: bytes.length,
          error: 'برای بررسی محتوای رمزنگاری‌شده، رمز عبور لازم است.',
        );
      }
      final payload = await _decryptEnvelope(envelope, password);
      _validatePayload(payload);
      return BackupInspection(
        validEnvelope: true,
        checksumValid: true,
        decrypted: true,
        createdAt: envelope['createdAt'] as String?,
        schemaVersion: (payload['schemaVersion'] as num?)?.toInt(),
        incomeCount: _listCount(payload['incomes']),
        expenseCount: _listCount(payload['expenses']),
        liabilityCount: _listCount(payload['liabilities']),
        categoryCount: _listCount(payload['categories']),
        fileBytes: bytes.length,
      );
    } on BackupException catch (e) {
      return BackupInspection(
        validEnvelope: true,
        checksumValid: true,
        decrypted: false,
        createdAt: envelope['createdAt'] as String?,
        schemaVersion: null,
        incomeCount: 0,
        expenseCount: 0,
        liabilityCount: 0,
        categoryCount: 0,
        fileBytes: bytes.length,
        error: e.message,
      );
    } catch (_) {
      return BackupInspection(
        validEnvelope: true,
        checksumValid: true,
        decrypted: false,
        createdAt: envelope['createdAt'] as String?,
        schemaVersion: null,
        incomeCount: 0,
        expenseCount: 0,
        liabilityCount: 0,
        categoryCount: 0,
        fileBytes: bytes.length,
        error: 'رمز عبور اشتباه است یا محتوای رمزنگاری‌شده قابل بازیابی نیست.',
      );
    }
  }

  Future<void> restoreSelected({required String password}) async {
    _validatePassword(password);
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'انتخاب نسخه پشتیبان Finaro',
      type: FileType.custom,
      allowedExtensions: const ['finaro'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    await restoreBytes(result.files.single.bytes!, password: password);
  }

  Future<void> restoreBytes(Uint8List bytes, {required String password}) async {
    _validatePassword(password);
    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> || decoded['format'] != _format || decoded['version'] != _version) {
        throw const FormatException();
      }
      envelope = decoded;
      _validateEnvelopeShape(envelope);
    } catch (_) {
      throw const BackupException('این فایل نسخه پشتیبان معتبر Finaro نیست.');
    }
    try {
      final payload = await _decryptEnvelope(envelope, password);
      _validatePayload(payload);
      await repository.restoreBackup(payload);
    } catch (e) {
      if (e is BackupException) rethrow;
      throw const BackupException('رمز عبور اشتباه است یا فایل پشتیبان آسیب دیده است. اطلاعات فعلی تغییری نکرده است.');
    }
  }

  Future<void> restoreEncrypted({required String password}) => restoreSelected(password: password);

  Future<Map<String, dynamic>> _decryptEnvelope(Map<String, dynamic> envelope, String password) async {
    try {
      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final mac = Mac(base64Decode(envelope['mac'] as String));
      final ciphertext = base64Decode(envelope['ciphertext'] as String);
      final expectedChecksum = base64Decode(envelope['checksumSha256'] as String);
      final actualChecksum = (await Sha256().hash(ciphertext)).bytes;
      if (!_sameBytes(expectedChecksum, actualChecksum)) throw const BackupException('یکپارچگی فایل نسخه پشتیبان تأیید نشد.');
      final key = await _deriveKey(password, salt);
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: mac),
        secretKey: key,
      );
      final payload = jsonDecode(utf8.decode(clear));
      if (payload is! Map<String, dynamic>) throw const FormatException();
      return payload;
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException('رمز عبور اشتباه است یا فایل پشتیبان آسیب دیده است.');
    }
  }

  void _validateEnvelopeShape(Map<String, dynamic> envelope) {
    for (final key in const ['createdAt', 'salt', 'nonce', 'mac', 'ciphertext', 'checksumSha256']) {
      if (envelope[key] is! String || (envelope[key] as String).isEmpty) throw const FormatException();
    }
    if (envelope['cipher'] != 'AES-256-GCM') throw const FormatException();
    final kdf = envelope['kdf'];
    if (kdf is! Map || kdf['name'] != 'PBKDF2-HMAC-SHA256' || kdf['iterations'] != _iterations) throw const FormatException();
  }

  void _validatePayload(Map<String, dynamic> payload) {
    if (payload['schemaVersion'] != 2) throw const BackupException('نسخه ساختار داده این پشتیبان با نسخه فعلی Finaro سازگار نیست.');
    if (payload['profile'] is! Map<String, dynamic>) throw const BackupException('اطلاعات پروفایل نسخه پشتیبان ناقص است.');
    for (final key in const ['incomes', 'expenses', 'liabilities', 'categories']) {
      if (payload[key] is! List) throw const BackupException('ساختار اطلاعات مالی نسخه پشتیبان ناقص است.');
    }
  }

  int _listCount(dynamic value) => value is List ? value.length : 0;

  Future<Map<String, dynamic>> _snapshot() async {
    final profile = await repository.profile();
    final incomes = await repository.incomes();
    final expenses = await repository.expenses();
    final liabilities = await repository.liabilities();
    final categories = await repository.categories();
    return {
      'schemaVersion': 2,
      'profile': {
        'id': profile.id,
        'name': profile.name,
        'openingBalanceRials': profile.openingBalanceRials,
        'openingBalanceDate': profile.openingBalanceDate,
      },
      'incomes': incomes.map((x) => {'id': x.id, 'title': x.title, 'amountRials': x.amountRials, 'frequency': x.frequency, 'start': x.start, 'payDay': x.payDay}).toList(),
      'expenses': expenses.map((x) => {'id': x.id, 'title': x.title, 'amountRials': x.amountRials, 'frequency': x.frequency, 'category': x.category, 'date': x.date, 'startDate': x.startDate, 'paymentDay': x.paymentDay}).toList(),
      'liabilities': liabilities.map((x) => {'id': x.id, 'title': x.title, 'type': x.type, 'totalRials': x.totalRials, 'installmentRials': x.installmentRials, 'remainingInstallments': x.remainingInstallments, 'frequency': x.frequency, 'paymentDate': x.paymentDate, 'paymentDay': x.paymentDay}).toList(),
      'categories': categories.map((x) => {'id': x.id, 'title': x.title}).toList(),
    };
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) async => Pbkdf2(
    macAlgorithm: Hmac.sha256(), iterations: _iterations, bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  List<int> _randomBytes(int length) { final random = Random.secure(); return List<int>.generate(length, (_) => random.nextInt(256)); }
  bool _sameBytes(List<int> a, List<int> b) { if (a.length != b.length) return false; for (var i = 0; i < a.length; i++) { if (a[i] != b[i]) return false; } return true; }
  String _stamp() => DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
  void _validatePassword(String password) { if (password.length < 8) throw const BackupException('رمز عبور پشتیبان باید حداقل ۸ کاراکتر باشد.'); }
}
