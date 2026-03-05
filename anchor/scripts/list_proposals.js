const { Connection, PublicKey } = require('@solana/web3.js');
const bs58 = require('bs58');
const crypto = require('crypto');

const PROGRAM_ID = new PublicKey('HqPhVS24ZxhnuS6amTLa4MGuStoUadsjGHdQoih8hn5o');
const MULTISIG = process.argv[2] || '56BV24CSAibcDzkyAKU9FozGsWAbFSYC8ehAiSYZwst2';
const RPC_URL = process.env.RPC_URL || 'https://api.devnet.solana.com';

const connection = new Connection(RPC_URL, 'confirmed');

function discriminator(name) {
  return crypto.createHash('sha256').update(name).digest().slice(0, 8);
}

function readU32LE(buf, offset) {
  return buf.readUInt32LE(offset);
}

function readU64LE(buf, offset) {
  const lo = buf.readUInt32LE(offset);
  const hi = buf.readUInt32LE(offset + 4);
  return hi * 2 ** 32 + lo;
}

function readI64LE(buf, offset) {
  const lo = buf.readUInt32LE(offset);
  const hi = buf.readInt32LE(offset + 4);
  return hi * 2 ** 32 + lo;
}

async function main() {
  console.log('RPC', RPC_URL);
  console.log('Program', PROGRAM_ID.toBase58());
  console.log('Multisig filter', MULTISIG);

  const proposalDisc = discriminator('account:Proposal');
  const filters = [
    { memcmp: { offset: 0, bytes: bs58.encode(proposalDisc) } },
    { memcmp: { offset: 40, bytes: MULTISIG } }, // 8 disc + 32 proposer => multisig starts at 40
  ];

  const accounts = await connection.getProgramAccounts(PROGRAM_ID, {
    commitment: 'confirmed',
    filters,
  });

  if (!accounts.length) {
    console.log('No proposals found for multisig');
    return;
  }

  const parsed = accounts.map(({ pubkey, account }) => {
    const raw = Buffer.isBuffer(account.data)
      ? account.data
      : Buffer.from(account.data[0], 'base64');
    let o = 8; // skip discriminator
    const proposer = new PublicKey(raw.subarray(o, o + 32));
    o += 32;
    const multisig = new PublicKey(raw.subarray(o, o + 32));
    o += 32;
    const destination = new PublicKey(raw.subarray(o, o + 32));
    o += 32;
    const amount = readU64LE(raw, o);
    o += 8;
    const approvalsLen = readU32LE(raw, o);
    o += 4 + approvalsLen * 32; // skip approvals
    const executed = raw[o] !== 0;
    o += 1;
    const createdAt = readI64LE(raw, o);
    o += 8;
    const expiresAt = readI64LE(raw, o);
    o += 8;
    const id = readU64LE(raw, o);
    o += 8;
    const bump = raw[o];
    o += 1;

    // Decode ProposalAction enum (replaces old isGovernance bool)
    const actionDisc = raw[o];
    let action;
    switch (actionDisc) {
      case 0:
        action = { type: 'Transfer' };
        o += 1;
        break;
      case 1:
        action = { type: 'UpdateThreshold', newThreshold: raw[o + 1] };
        o += 2;
        break;
      case 2:
        action = { type: 'AddOwner', newOwner: new PublicKey(raw.subarray(o + 1, o + 33)).toBase58() };
        o += 33;
        break;
      case 3:
        action = { type: 'RemoveOwner', owner: new PublicKey(raw.subarray(o + 1, o + 33)).toBase58() };
        o += 33;
        break;
      case 4:
        action = { type: 'UpdateRole', owner: new PublicKey(raw.subarray(o + 1, o + 33)).toBase58(), role: raw[o + 33] };
        o += 34;
        break;
      case 5:
        action = { type: 'UpdateMonthlyLimit', owner: new PublicKey(raw.subarray(o + 1, o + 33)).toBase58(), newLimit: readU64LE(raw, o + 33) };
        o += 41;
        break;
      default:
        action = { type: 'Unknown', discriminator: actionDisc };
        o += 1;
    }
    const isGovernance = actionDisc !== 0;

    return {
      account: pubkey.toBase58(),
      proposer: proposer.toBase58(),
      multisig: multisig.toBase58(),
      destination: destination.toBase58(),
      amount,
      approvalsLen,
      executed,
      createdAt,
      expiresAt,
      id,
      bump,
      action,
      isGovernance,
    };
  });

  console.log(JSON.stringify(parsed, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
