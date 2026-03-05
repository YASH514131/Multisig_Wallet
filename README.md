Perfect. Below is a **complete, structured README-style master prompt** you can give to another AI to build your system from scratch.

It includes:

* Solana program (Anchor-based multisig)
* Role-based policy logic
* Flutter mobile app
* Backend indexing (optional but included)
* Security requirements
* Deployment steps
* Production readiness checklist

You can copy-paste this directly.

---

# 📘 PROJECT README – Institutional Role-Based Multisig Wallet on Solana

## 🎯 Project Goal

Build a production-ready institutional multisig wallet on **Solana** using:

* On-chain smart contract (NO MPC, NO key sharding)
* Role-based access control
* Threshold approvals
* Monthly withdrawal limits
* Proposal-based transaction workflow
* Flutter mobile application frontend
* Secure key storage
* Full deployment pipeline

This is for institutions (board members, finance officers, auditors).

---

# 🧠 SYSTEM ARCHITECTURE OVERVIEW

We will build:

1. **Solana Smart Contract (Anchor framework)**
2. **Flutter Mobile App (iOS + Android)**
3. Optional Backend (indexing + notifications)
4. Deployment scripts
5. Production security setup

We are NOT using:

* Shamir Secret Sharing
* MPC
* Private key reconstruction
* Off-chain signing aggregation

Everything must rely on **Solana program-controlled multisig logic**.

---

# 🔐 SECURITY MODEL

* Each board member owns their own wallet private key.
* Keys are stored in:

  * Android Keystore
  * iOS Secure Enclave
* The multisig account is controlled by a Solana Program.
* No private keys are ever shared.
* All approvals are separate transaction signatures.

---

# 🏗 SMART CONTRACT REQUIREMENTS (ANCHOR)

Use:

* Rust
* Anchor framework

## 1️⃣ Multisig Account Structure

Create:

```
MultisigAccount {
    owners: Vec<Pubkey>,
    threshold: u8,
    role_mapping: Vec<RoleData>,
    nonce: u64,
}
```

```
RoleData {
    owner: Pubkey,
    role: Role,
    monthly_limit: u64,
    spent_this_month: u64,
}
```

```
enum Role {
    BoardMember,
    FinanceOfficer,
    Auditor
}
```

---

## 2️⃣ Proposal Account Structure

```
Proposal {
    proposer: Pubkey,
    destination: Pubkey,
    amount: u64,
    approvals: Vec<Pubkey>,
    executed: bool,
    created_at: i64,
    expires_at: i64,
}
```

---

## 3️⃣ Smart Contract Instructions

Implement the following instructions:

### ✅ Initialize Multisig

* Set owners
* Set threshold
* Assign roles
* Set monthly limits

---

### ✅ Create Proposal

* Validate proposer is owner
* Store proposal
* Set expiration time

---

### ✅ Approve Proposal

* Verify signer is owner
* Prevent duplicate approval
* Add to approvals array

---

### ✅ Execute Proposal

Conditions:

* approvals >= threshold
* proposal not expired
* proposal not executed
* role-based monthly limits respected
* sufficient balance available

Then:

* Transfer SOL or SPL token
* Mark executed = true

---

### ✅ Update Monthly Counters

* Reset counters monthly (timestamp-based logic)

---

### ✅ Governance Actions (Advanced)

* Add owner
* Remove owner
* Change threshold
* Update role
* Update monthly limit

These actions must also go through proposal + threshold.

---

# 💰 ROLE-BASED RULE LOGIC

Implement dynamic approval requirements:

| Amount Range       | Required Approvals |
| ------------------ | ------------------ |
| <= $100 equivalent | 1                  |
| <= $1000           | 2                  |
| > $1000            | threshold          |

Monthly withdrawal rule:

* Each member has a personal monthly cap
* Contract must track usage

---

# 📱 FLUTTER APPLICATION REQUIREMENTS

Use:

* Flutter (latest stable)
* solana_dart package OR direct RPC
* Secure storage
* Clean architecture pattern

---

## App Screens

### 1️⃣ Onboarding

* Create wallet
* Import wallet
* Biometric enable
* Join multisig via invitation

---

### 2️⃣ Dashboard

* Multisig balance
* Pending proposals
* Approved proposals
* Monthly usage per member

---

### 3️⃣ Create Proposal

* Enter destination
* Enter amount
* Add memo
* Submit

---

### 4️⃣ Proposal Detail

* Show:

  * Approvals
  * Required approvals
  * Expiration
  * Role requirement
* Approve button
* Execute button (if eligible)

---

### 5️⃣ Governance Panel (Admin Only)

* Add member
* Remove member
* Change threshold
* Adjust limits

---

# 🧱 FLUTTER ARCHITECTURE

Use clean architecture:

```
lib/
 ├── core/
 ├── data/
 ├── domain/
 ├── presentation/
 ├── services/
```

Separate:

* Blockchain service
* Wallet service
* Proposal service
* Governance service

---

# 🔔 OPTIONAL BACKEND (RECOMMENDED)

Use:

* Node.js
* PostgreSQL
* Websocket listener

Purpose:

* Index proposals
* Push notifications
* Email alerts
* Analytics dashboard

NOT required for MVP but recommended.

---

# 🚀 DEPLOYMENT PROCESS

## Step 1 – Smart Contract

* Install Solana CLI
* Install Anchor
* Write program
* Deploy to devnet
* Test
* Deploy to mainnet-beta

---

## Step 2 – Flutter Build

* Configure RPC endpoint
* Configure program ID
* Secure storage implementation
* Android release build
* iOS release build

---

## Step 3 – Infrastructure

* Dedicated RPC provider
* Domain + SSL
* Monitoring setup
* Log aggregation

---

# 🧪 TESTING REQUIREMENTS

Smart contract tests:

* Threshold enforcement
* Double approval prevention
* Expired proposal rejection
* Insufficient balance rejection
* Monthly cap enforcement

Flutter tests:

* Wallet recovery
* Biometric lock
* Transaction simulation
* RPC error handling

---

# 🔥 PRODUCTION HARDENING

Must implement:

* Transaction simulation before execution
* Proposal expiration
* Rate limiting
* Emergency freeze
* Audit log export (CSV)
* Time lock (optional 24h delay for large tx)

---

# ⚠️ EDGE CASES TO HANDLE

* Owner loses key
* Owner removed mid-proposal
* Threshold changed mid-proposal
* Proposal executed twice
* Replay attack
* Network RPC failure
* Solana congestion

---

# 📊 FUTURE ROADMAP (DO NOT BUILD NOW)

* Hardware wallet support
* Multi-token treasury
* DAO voting integration
* Compliance module
* On-chain analytics

---

# 🎯 FINAL REQUIREMENTS

The system must:

* Never reconstruct private keys
* Never share private keys
* Only rely on Solana program logic
* Be production-ready for institutions
* Be secure against internal fraud
* Be scalable to 50+ members

---

# 📦 OUTPUT REQUIRED FROM AI

Generate:

1. Complete Anchor smart contract
2. Full Flutter project
3. Deployment guide
4. Testing scripts
5. Folder structure
6. Environment configuration
7. Production checklist

---

Build this as if it will secure millions of dollars.

Security > UX
Correctness > Speed
Auditability > Simplicity

---

