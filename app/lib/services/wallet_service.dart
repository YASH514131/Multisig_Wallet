import 'package:bip39/bip39.dart' as bip39;
import 'package:solana/solana.dart';

import '../domain/entities/wallet_account.dart';
import 'secure_storage_service.dart';

class WalletService {
  WalletService({SecureStorageService? storage})
    : _storage = storage ?? const SecureStorageService();

  static const _mnemonicKey = 'wallet_mnemonic';

  final SecureStorageService _storage;

  Future<WalletAccount?> loadExisting() async {
    final saved = await _storage.read(_mnemonicKey);
    if (saved == null || saved.isEmpty) {
      return null;
    }

    return _deriveFromMnemonic(saved);
  }

  Future<String> readMnemonic() async {
    final saved = await _storage.read(_mnemonicKey);
    if (saved == null || saved.isEmpty) {
      throw StateError('No wallet mnemonic found');
    }
    return saved;
  }

  Future<WalletAccount> createNew() async {
    final mnemonic = bip39.generateMnemonic();
    final account = await _deriveFromMnemonic(mnemonic);
    await _storage.write(key: _mnemonicKey, value: mnemonic);
    return account;
  }

  Future<WalletAccount> importMnemonic(String mnemonic) async {
    final cleaned = mnemonic.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!bip39.validateMnemonic(cleaned)) {
      throw ArgumentError('Invalid mnemonic');
    }

    final account = await _deriveFromMnemonic(cleaned);
    await _storage.write(key: _mnemonicKey, value: cleaned);
    return account;
  }

  Future<void> clear() {
    return _storage.delete(_mnemonicKey);
  }

  Future<WalletAccount> _deriveFromMnemonic(String mnemonic) async {
    final keypair = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
    final pubkey = await keypair.extractPublicKey();

    return WalletAccount(
      address: keypair.address,
      publicKey: pubkey.toBase58(),
      mnemonic: mnemonic,
    );
  }
}
