import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  const SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(webOptions: WebOptions.defaultOptions);

  final FlutterSecureStorage _storage;

  Future<void> write({required String key, required String value}) {
    debugPrint(
      'SecureStorageService.write key=$key value=${value.length > 100 ? value.substring(0, 100) : value}',
    );
    return _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    final value = await _storage.read(key: key);
    debugPrint(
      'SecureStorageService.read key=$key value=${value?.substring(0, (value.length > 100 ? 100 : value.length)) ?? 'null'}',
    );
    return value;
  }

  Future<void> delete(String key) {
    debugPrint('SecureStorageService.delete key=$key');
    return _storage.delete(key: key);
  }
}
