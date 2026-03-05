/*
 * Run: ANCHOR_PROVIDER_URL=https://api.devnet.solana.com \
 *      ANCHOR_WALLET=~/.config/solana/id.json \
 *      node scripts/init_multisig.js
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const anchor = require('@coral-xyz/anchor');

const PROGRAM_ID = new anchor.web3.PublicKey('HqPhVS24ZxhnuS6amTLa4MGuStoUadsjGHdQoih8hn5o');
const OWNER_PUBKEYS = [
  '2GFiutByaUwh9CC2LG73bhQCg4YnPWZncvuKa8sgtXSD',
  'GtSdCQyUbrdntqNKsn1jNhVkhfXMGZWfE7Dt5HbDZ7Ub',
  '9LvfKFStxyGfMLBPMYEJvuPQQZcJ2jpHak8CX3LmpkTe',
  '6xrzfoWqUF9p1FUA87Jmsw62z3oNrWLTtU1yEL7yv7Aj',
  '4D8JQ8bd1AKs7zNcHURWKouk3i97Av2TYFS9NF9e3Mab',
];
const THRESHOLD = 2;
const ROLE_LIMITS_LAMPORTS = [10_000_000_000, 20_000_000_000, 10_000_000_000, 10_000_000_000, 10_000_000_000];
const OUTPUT_PATH = path.resolve(__dirname, '../.multisig-address.json');

async function main() {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const toSnake = (name) => name.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();

  const normalizeIdlTypes = (value) => {
    if (Array.isArray(value)) return value.map(normalizeIdlTypes);
    if (value && typeof value === 'object') {
      const out = { ...value };
      if (typeof out.defined === 'string') out.defined = { name: out.defined };
      if (out.type) out.type = normalizeIdlTypes(out.type);
      if (out.vec) out.vec = normalizeIdlTypes(out.vec);
      if (out.option) out.option = normalizeIdlTypes(out.option);
      if (out.array) out.array = out.array.map(normalizeIdlTypes);
      if (out.defined) out.defined = normalizeIdlTypes(out.defined);
      Object.keys(out).forEach((k) => {
        if (!['type', 'vec', 'option', 'array', 'defined'].includes(k)) out[k] = normalizeIdlTypes(out[k]);
      });
      return out;
    }
    return value;
  };

  const idlPathPrimary = path.resolve(__dirname, '../target/idl/true_wallet_multisig.json');
  const idlPathFallback = path.resolve(__dirname, '../../app/assets/idl/true_wallet_multisig.json');
  let idlSource = 'fetched';
  let idl = await anchor.Program.fetchIdl(PROGRAM_ID, provider);
  if (!idl) {
    const idlPath = fs.existsSync(idlPathPrimary) ? idlPathPrimary : idlPathFallback;
    const raw = fs.readFileSync(idlPath, 'utf8');
    // anchor 0.30 expects "pubkey" type strings; normalize older "publicKey" entries
    const normalized = raw.includes('publicKey') ? raw.replace(/publicKey/g, 'pubkey') : raw;
    idl = JSON.parse(normalized);
    idlSource = idlPath;
  } else {
    // normalize fetched IDL too
    const normalized = JSON.stringify(idl).replace(/publicKey/g, 'pubkey');
    idl = JSON.parse(normalized);
  }
  idl = normalizeIdlTypes(idl);
  idl.instructions = idl.instructions.map((ix) => ({ ...ix, name: toSnake(ix.name) }));
  if (!idl.types) idl.types = [];
  if (idl.accounts) {
    idl.accounts.forEach((acc) => {
      const existing = idl.types.find((t) => t.name === acc.name);
      if (!existing) {
        idl.types.push({ name: acc.name, type: acc.type });
      }
    });
  }
  idl.instructions = idl.instructions.map((ix) => {
    if (!ix.discriminator) {
      const hash = crypto.createHash('sha256').update(`global:${ix.name}`).digest();
      return { ...ix, discriminator: Array.from(hash.slice(0, 8)) };
    }
    return ix;
  });
  if (idl.accounts) {
    idl.accounts = idl.accounts.map((acc) => {
      if (!acc.discriminator) {
        const hash = crypto.createHash('sha256').update(`account:${acc.name}`).digest();
        return { ...acc, discriminator: Array.from(hash.slice(0, 8)) };
      }
      return acc;
    });
  }
  console.log('Using IDL', idlSource);
  console.log('Program ID', PROGRAM_ID.toBase58());
  idl.address = PROGRAM_ID.toBase58();
  console.log('First instruction shape', idl.instructions[0]);
  const program = new anchor.Program(idl, provider);

  const owners = OWNER_PUBKEYS.map((k) => new anchor.web3.PublicKey(k));
  const roleMapping = [
    { owner: owners[0], role: { boardMember: {} }, monthlyLimit: new anchor.BN(ROLE_LIMITS_LAMPORTS[0]) },
    { owner: owners[1], role: { financeOfficer: {} }, monthlyLimit: new anchor.BN(ROLE_LIMITS_LAMPORTS[1]) },
    { owner: owners[2], role: { auditor: {} }, monthlyLimit: new anchor.BN(ROLE_LIMITS_LAMPORTS[2]) },
    { owner: owners[3], role: { boardMember: {} }, monthlyLimit: new anchor.BN(ROLE_LIMITS_LAMPORTS[3]) },
    { owner: owners[4], role: { boardMember: {} }, monthlyLimit: new anchor.BN(ROLE_LIMITS_LAMPORTS[4]) },
  ];

  const multisig = anchor.web3.Keypair.generate();
  const [vault] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from('vault'), multisig.publicKey.toBuffer()],
    PROGRAM_ID,
  );

  console.log('Multisig pubkey', multisig.publicKey.toBase58());
  console.log('Vault PDA', vault.toBase58());

  console.log('Submitting initializeMultisig ...');
  const data = program.coder.instruction.encode('initializeMultisig', {
    owners,
    threshold: THRESHOLD,
    roleMapping,
  });
  const ix = new anchor.web3.TransactionInstruction({
    programId: PROGRAM_ID,
    keys: [
      { pubkey: multisig.publicKey, isSigner: true, isWritable: true },
      { pubkey: vault, isSigner: false, isWritable: true },
      { pubkey: provider.wallet.publicKey, isSigner: true, isWritable: true },
      { pubkey: anchor.web3.SystemProgram.programId, isSigner: false, isWritable: false },
      { pubkey: anchor.web3.SYSVAR_CLOCK_PUBKEY, isSigner: false, isWritable: false },
    ],
    data,
  });

  const tx = new anchor.web3.Transaction().add(ix);
  const sig = await provider.sendAndConfirm(tx, [multisig]);

  const result = {
    tx: sig,
    multisig: multisig.publicKey.toBase58(),
    vault: vault.toBase58(),
    owners: OWNER_PUBKEYS,
    threshold: THRESHOLD,
    rpc: provider.connection.rpcEndpoint,
  };

  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(result, null, 2));
  console.log('tx', sig);
  console.log('multisig', result.multisig);
  console.log('vault', result.vault);
  console.log('saved', OUTPUT_PATH);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
