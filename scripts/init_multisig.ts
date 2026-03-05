import fs from 'fs';
import path from 'path';
import { AnchorProvider, BN, Program, Wallet, web3 } from '@coral-xyz/anchor';

// ---------- CONFIGURE THESE ----------
const RPC_URL = 'https://api.devnet.solana.com';
const PROGRAM_ID = new web3.PublicKey('HqPhVS24ZxhnuS6amTLa4MGuStoUadsjGHdQoih8hn5o');
const PAYER_KEYPAIR_PATH = path.resolve('payer.json');

// Owners you shared
const OWNER_PUBKEYS = [
  'J8PNo8YBbfVfUgA7b3uyLgFYQnnq9q55SBsRKEW3HADR',
  'GtSdCQyUbrdntqNKsn1jNhVkhfXMGZWfE7Dt5HbDZ7Ub',
  '9LvfKFStxyGfMLBPMYEJvuPQQZcJ2jpHak8CX3LmpkTe',
];
const THRESHOLD = 2;
const ROLE_LIMITS_LAMPORTS = [
  5_000_000_000,  // BoardMember
  20_000_000_000, // FinanceOfficer
  0,              // Auditor
];

// ---------- MAIN ----------
async function main() {
  const payer = web3.Keypair.fromSecretKey(
    Uint8Array.from(JSON.parse(fs.readFileSync(PAYER_KEYPAIR_PATH, 'utf8'))),
  );
  const wallet = new Wallet(payer);
  const connection = new web3.Connection(RPC_URL);
  const provider = new AnchorProvider(connection, wallet, {});

  const idlPath = path.resolve('app/assets/idl/true_wallet_multisig.json');
  const idl = JSON.parse(fs.readFileSync(idlPath, 'utf8'));
  const program = new Program(idl as any, PROGRAM_ID, provider);

  const owners = OWNER_PUBKEYS.map((k) => new web3.PublicKey(k));
  const roleMapping = [
    { owner: owners[0], role: { BoardMember: {} }, monthlyLimit: new BN(ROLE_LIMITS_LAMPORTS[0]) },
    { owner: owners[1], role: { FinanceOfficer: {} }, monthlyLimit: new BN(ROLE_LIMITS_LAMPORTS[1]) },
    { owner: owners[2], role: { Auditor: {} }, monthlyLimit: new BN(ROLE_LIMITS_LAMPORTS[2]) },
  ];

  const multisig = web3.Keypair.generate();
  const [vault] = web3.PublicKey.findProgramAddressSync(
    [Buffer.from('vault'), multisig.publicKey.toBuffer()],
    PROGRAM_ID,
  );

  console.log('Submitting initializeMultisig...');
  const sig = await program.methods
    .initializeMultisig(owners, THRESHOLD, roleMapping)
    .accounts({
      multisig: multisig.publicKey,
      vault,
      payer: payer.publicKey,
      systemProgram: web3.SystemProgram.programId,
      clock: web3.SYSVAR_CLOCK_PUBKEY,
    })
    .signers([multisig])
    .rpc();

  console.log('tx', sig);
  console.log('multisig', multisig.publicKey.toBase58());
  console.log('vault', vault.toBase58());
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
