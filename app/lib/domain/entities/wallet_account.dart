class WalletAccount {
  const WalletAccount({
    required this.address,
    required this.publicKey,
    required this.mnemonic,
  });

  final String address;
  final String publicKey;
  final String mnemonic;
}
