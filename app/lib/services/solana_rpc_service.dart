import 'package:solana/solana.dart';

class SolanaRpcService {
  SolanaRpcService({String? rpcUrl})
    : _client = RpcClient(rpcUrl ?? 'https://api.devnet.solana.com');

  final RpcClient _client;

  RpcClient get client => _client;

  Future<int> getBalance(String address) async {
    final dynamic result = await _client.getBalance(address);

    if (result is int) {
      return result;
    }

    final dynamic value = (result as dynamic).value;
    if (value is int) {
      return value;
    }

    throw StateError('Unexpected balance response type: ${result.runtimeType}');
  }

  Future<void> close() async {
    // Placeholder for future cleanup hooks.
  }
}
