class AppConfig {
  const AppConfig({
    required this.rpcUrl,
    required this.programId,
    required this.multisigAddress,
  });

  final String rpcUrl;
  final String programId;
  final String multisigAddress;

  AppConfig copyWith({
    String? rpcUrl,
    String? programId,
    String? multisigAddress,
  }) {
    return AppConfig(
      rpcUrl: rpcUrl ?? this.rpcUrl,
      programId: programId ?? this.programId,
      multisigAddress: multisigAddress ?? this.multisigAddress,
    );
  }
}
