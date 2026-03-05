use anchor_lang::prelude::*;

declare_id!("HqPhVS24ZxhnuS6amTLa4MGuStoUadsjGHdQoih8hn5o");

const MAX_OWNERS: usize = 10;
const MAX_ROLES: usize = 10;
const MAX_APPROVALS: usize = 10;
const SECONDS_IN_MONTH: i64 = 30 * 24 * 60 * 60;
const LOW_APPROVAL_LAMPORTS: u64 = 100_000_000; // 0.1 SOL equivalent guard
const MID_APPROVAL_LAMPORTS: u64 = 1_000_000_000; // 1 SOL guard
const ACCOUNT_PADDING: usize = 128; // extra bytes to avoid account-too-small edge cases

#[program]
pub mod true_wallet_multisig {
    use super::*;

    pub fn initialize_multisig(
        ctx: Context<InitializeMultisig>,
        owners: Vec<Pubkey>,
        threshold: u8,
        role_mapping: Vec<RoleInput>,
    ) -> Result<()> {
        require!(!owners.is_empty(), MultisigError::NoOwners);
        require!((threshold as usize) <= owners.len(), MultisigError::InvalidThreshold);
        require!(owners.len() <= MAX_OWNERS, MultisigError::TooManyOwners);

        let multisig = &mut ctx.accounts.multisig;
        multisig.owners = owners.clone();
        multisig.threshold = threshold;
        multisig.nonce = ctx.accounts.clock.unix_timestamp as u64;
        multisig.last_reset_unix = ctx.accounts.clock.unix_timestamp;
        multisig.vault_bump = ctx.bumps.vault;

        require!(role_mapping.len() <= MAX_ROLES, MultisigError::TooManyRoles);
        for entry in role_mapping.iter() {
            require!(owners.contains(&entry.owner), MultisigError::OwnerNotFound);
            multisig.role_mapping.push(RoleData {
                owner: entry.owner,
                role: entry.role,
                monthly_limit: entry.monthly_limit,
                spent_this_month: 0,
            });
        }

        Ok(())
    }

    pub fn create_proposal(
        ctx: Context<CreateProposal>,
        destination: Pubkey,
        amount: u64,
        expires_at: i64,
        proposal_id: u64,
        action: ProposalAction,
    ) -> Result<()> {
        let clock = ctx.accounts.clock.unix_timestamp;
        require!(expires_at > clock, MultisigError::InvalidExpiration);

        let multisig = &ctx.accounts.multisig;
        require!(multisig.owners.contains(ctx.accounts.proposer.key), MultisigError::OwnerNotFound);

        let proposal = &mut ctx.accounts.proposal;
        proposal.proposer = *ctx.accounts.proposer.key;
        proposal.multisig = multisig.key();
        proposal.destination = destination;
        proposal.amount = amount;
        proposal.approvals = vec![*ctx.accounts.proposer.key];
        proposal.executed = false;
        proposal.created_at = clock;
        proposal.expires_at = expires_at;
        proposal.id = proposal_id;
        proposal.bump = ctx.bumps.proposal;
        proposal.action = action;

        Ok(())
    }

    pub fn approve_proposal(ctx: Context<ApproveProposal>) -> Result<()> {
        let multisig = &ctx.accounts.multisig;
        let proposal = &mut ctx.accounts.proposal;
        require!(!proposal.executed, MultisigError::AlreadyExecuted);
        require!(proposal.multisig == multisig.key(), MultisigError::ProposalMismatch);
        require!(multisig.owners.contains(ctx.accounts.signer.key), MultisigError::OwnerNotFound);
        require!(!proposal.approvals.contains(ctx.accounts.signer.key), MultisigError::AlreadyApproved);

        proposal.approvals.push(*ctx.accounts.signer.key);
        require!(proposal.approvals.len() <= MAX_APPROVALS, MultisigError::TooManyApprovals);
        Ok(())
    }

    pub fn execute_proposal(ctx: Context<ExecuteProposal>) -> Result<()> {
        let clock = ctx.accounts.clock.unix_timestamp;
        let multisig = &mut ctx.accounts.multisig;
        let proposal = &mut ctx.accounts.proposal;

        require!(!proposal.executed, MultisigError::AlreadyExecuted);
        require!(proposal.multisig == multisig.key(), MultisigError::ProposalMismatch);
        require!(clock <= proposal.expires_at, MultisigError::ProposalExpired);
        require!(multisig.owners.contains(ctx.accounts.signer.key), MultisigError::OwnerNotFound);
        require!(proposal.action.is_transfer(), MultisigError::InvalidProposalType);

        // Reset monthly counters if needed
        maybe_reset_counters(multisig, clock);

        let required_approvals = required_approvals_for_amount(proposal.amount, multisig.threshold);
        require!(proposal.approvals.len() as u8 >= required_approvals, MultisigError::NotEnoughApprovals);

        // Check monthly limit for proposer (not executor) to prevent delegate bypass
        let role_entry = multisig
            .role_mapping
            .iter_mut()
            .find(|r| r.owner == proposal.proposer)
            .ok_or(MultisigError::OwnerNotFound)?;

        let new_spent = role_entry
            .spent_this_month
            .checked_add(proposal.amount)
            .ok_or(MultisigError::Overflow)?;
        require!(new_spent <= role_entry.monthly_limit, MultisigError::MonthlyLimitExceeded);

        role_entry.spent_this_month = new_spent;

        // Transfer SOL from vault by direct lamport manipulation (program owns the vault)
        let vault_lamports = ctx.accounts.vault.lamports();
        require!(vault_lamports >= proposal.amount, MultisigError::InsufficientFunds);

        **ctx.accounts.vault.try_borrow_mut_lamports()? -= proposal.amount;
        **ctx.accounts.destination.try_borrow_mut_lamports()? += proposal.amount;

        proposal.executed = true;
        Ok(())
    }

    pub fn reset_monthly(ctx: Context<ResetMonthly>) -> Result<()> {
        let clock = ctx.accounts.clock.unix_timestamp;
        let multisig = &mut ctx.accounts.multisig;
        require!(multisig.owners.contains(ctx.accounts.signer.key), MultisigError::OwnerNotFound);
        multisig.last_reset_unix = clock;
        for entry in multisig.role_mapping.iter_mut() {
            entry.spent_this_month = 0;
        }
        Ok(())
    }

    pub fn update_threshold(ctx: Context<GovernanceUpdate>, new_threshold: u8) -> Result<()> {
        let multisig = &mut ctx.accounts.multisig;
        let proposal = &mut ctx.accounts.proposal;
        let clock = ctx.accounts.clock.unix_timestamp;
        let expected = ProposalAction::UpdateThreshold { new_threshold };
        governance_guard(multisig, proposal, ctx.accounts.authority.key, clock, &expected)?;

        require!((new_threshold as usize) <= multisig.owners.len(), MultisigError::InvalidThreshold);
        multisig.threshold = new_threshold;
        proposal.executed = true;
        Ok(())
    }

    pub fn add_owner(ctx: Context<GovernanceUpdate>, new_owner: Pubkey) -> Result<()> {
        let multisig = &mut ctx.accounts.multisig;
        let proposal = &mut ctx.accounts.proposal;
        let clock = ctx.accounts.clock.unix_timestamp;
        let expected = ProposalAction::AddOwner { new_owner };
        governance_guard(multisig, proposal, ctx.accounts.authority.key, clock, &expected)?;
        require!(!multisig.owners.contains(&new_owner), MultisigError::OwnerExists);
        require!(multisig.owners.len() < MAX_OWNERS, MultisigError::TooManyOwners);
        multisig.owners.push(new_owner);
        // Give new owner a default role entry to avoid missing-role errors later.
        multisig.role_mapping.push(RoleData {
            owner: new_owner,
            role: Role::BoardMember,
            monthly_limit: 0,
            spent_this_month: 0,
        });
        proposal.executed = true;
        Ok(())
    }

    pub fn remove_owner(ctx: Context<GovernanceUpdate>, owner: Pubkey) -> Result<()> {
        let multisig = &mut ctx.accounts.multisig;
        let proposal = &mut ctx.accounts.proposal;
        let clock = ctx.accounts.clock.unix_timestamp;
        let expected = ProposalAction::RemoveOwner { owner };
        governance_guard(multisig, proposal, ctx.accounts.authority.key, clock, &expected)?;
        multisig.owners.retain(|o| *o != owner);
        multisig.role_mapping.retain(|r| r.owner != owner);
        require!(!multisig.owners.is_empty(), MultisigError::NoOwners);
        require!((multisig.threshold as usize) <= multisig.owners.len(), MultisigError::InvalidThreshold);
        proposal.executed = true;
        Ok(())
    }

    pub fn update_role(ctx: Context<GovernanceUpdate>, owner: Pubkey, role: Role) -> Result<()> {
        let multisig = &mut ctx.accounts.multisig;
        let proposal = &mut ctx.accounts.proposal;
        let clock = ctx.accounts.clock.unix_timestamp;
        let expected = ProposalAction::UpdateRole { owner, role };
        governance_guard(multisig, proposal, ctx.accounts.authority.key, clock, &expected)?;
        let entry = multisig
            .role_mapping
            .iter_mut()
            .find(|r| r.owner == owner)
            .ok_or(MultisigError::OwnerNotFound)?;
        entry.role = role;
        proposal.executed = true;
        Ok(())
    }

    pub fn update_monthly_limit(ctx: Context<GovernanceUpdate>, owner: Pubkey, new_limit: u64) -> Result<()> {
        let multisig = &mut ctx.accounts.multisig;
        let proposal = &mut ctx.accounts.proposal;
        let clock = ctx.accounts.clock.unix_timestamp;
        let expected = ProposalAction::UpdateMonthlyLimit { owner, new_limit };
        governance_guard(multisig, proposal, ctx.accounts.authority.key, clock, &expected)?;
        let entry = multisig
            .role_mapping
            .iter_mut()
            .find(|r| r.owner == owner)
            .ok_or(MultisigError::OwnerNotFound)?;
        entry.monthly_limit = new_limit;
        proposal.executed = true;
        Ok(())
    }
}

fn required_approvals_for_amount(amount: u64, threshold: u8) -> u8 {
    if amount <= LOW_APPROVAL_LAMPORTS {
        1
    } else if amount <= MID_APPROVAL_LAMPORTS {
        2.min(threshold)
    } else {
        threshold
    }
}

fn maybe_reset_counters(multisig: &mut Account<MultisigAccount>, now: i64) {
    if now.saturating_sub(multisig.last_reset_unix) >= SECONDS_IN_MONTH {
        for entry in multisig.role_mapping.iter_mut() {
            entry.spent_this_month = 0;
        }
        multisig.last_reset_unix = now;
    }
}

fn governance_guard(
    multisig: &mut Account<MultisigAccount>,
    proposal: &mut Account<Proposal>,
    authority: &Pubkey,
    now: i64,
    expected_action: &ProposalAction,
) -> Result<()> {
    require!(multisig.owners.contains(authority), MultisigError::OwnerNotFound);
    require!(!proposal.action.is_transfer(), MultisigError::InvalidProposalType);
    require!(proposal.action == *expected_action, MultisigError::ActionMismatch);
    require!(!proposal.executed, MultisigError::AlreadyExecuted);
    require!(proposal.multisig == multisig.key(), MultisigError::ProposalMismatch);
    require!(now <= proposal.expires_at, MultisigError::ProposalExpired);
    let required = multisig.threshold; // governance always needs full threshold, ignore amount
    require!(proposal.approvals.len() as u8 >= required, MultisigError::NotEnoughApprovals);
    Ok(())
}

#[derive(Accounts)]
pub struct InitializeMultisig<'info> {
    #[account(init, payer = payer, space = 8 + MultisigAccount::MAX_SIZE)]
    pub multisig: Account<'info, MultisigAccount>,
    #[account(
        init,
        payer = payer,
        seeds = [b"vault", multisig.key().as_ref()],
        bump,
        space = 0
    )]
    /// CHECK: vault holds SOL only
    pub vault: AccountInfo<'info>,
    #[account(mut)]
    pub payer: Signer<'info>,
    pub system_program: Program<'info, System>,
    pub clock: Sysvar<'info, Clock>,
}

#[derive(Accounts)]
#[instruction(destination: Pubkey, amount: u64, expires_at: i64, proposal_id: u64, action: ProposalAction)]
pub struct CreateProposal<'info> {
    #[account(mut)]
    pub multisig: Account<'info, MultisigAccount>,
    #[account(
        init,
        payer = proposer,
        space = 8 + Proposal::MAX_SIZE,
        seeds = [b"proposal", multisig.key().as_ref(), &proposal_id.to_le_bytes()],
        bump
    )]
    pub proposal: Account<'info, Proposal>,
    #[account(mut)]
    pub proposer: Signer<'info>,
    pub system_program: Program<'info, System>,
    pub clock: Sysvar<'info, Clock>,
}

#[derive(Accounts)]
pub struct ApproveProposal<'info> {
    #[account(mut)]
    pub multisig: Account<'info, MultisigAccount>,
    #[account(mut, has_one = multisig, seeds = [b"proposal", multisig.key().as_ref(), &proposal.id.to_le_bytes()], bump = proposal.bump)]
    pub proposal: Account<'info, Proposal>,
    pub signer: Signer<'info>,
}

#[derive(Accounts)]
pub struct ExecuteProposal<'info> {
    #[account(mut)]
    pub multisig: Account<'info, MultisigAccount>,
    #[account(mut, has_one = multisig, seeds = [b"proposal", multisig.key().as_ref(), &proposal.id.to_le_bytes()], bump = proposal.bump)]
    pub proposal: Account<'info, Proposal>,
    #[account(mut, seeds = [b"vault", multisig.key().as_ref()], bump = multisig.vault_bump)]
    /// CHECK: vault holds SOL only
    pub vault: AccountInfo<'info>,
    /// CHECK: destination can be any account
    #[account(mut)]
    pub destination: AccountInfo<'info>,
    pub system_program: Program<'info, System>,
    pub clock: Sysvar<'info, Clock>,
    pub signer: Signer<'info>,
}

#[derive(Accounts)]
pub struct ResetMonthly<'info> {
    #[account(mut)]
    pub multisig: Account<'info, MultisigAccount>,
    pub signer: Signer<'info>,
    pub clock: Sysvar<'info, Clock>,
}

#[derive(Accounts)]
pub struct GovernanceUpdate<'info> {
    #[account(mut)]
    pub multisig: Account<'info, MultisigAccount>,
    #[account(mut, has_one = multisig, seeds = [b"proposal", multisig.key().as_ref(), &proposal.id.to_le_bytes()], bump = proposal.bump)]
    pub proposal: Account<'info, Proposal>,
    pub authority: Signer<'info>,
    pub clock: Sysvar<'info, Clock>,
}

#[account]
pub struct MultisigAccount {
    pub owners: Vec<Pubkey>,
    pub threshold: u8,
    pub role_mapping: Vec<RoleData>,
    pub nonce: u64,
    pub last_reset_unix: i64,
    pub vault_bump: u8,
}

impl MultisigAccount {
    pub const MAX_SIZE: usize = 4 + MAX_OWNERS * 32 // owners vec
        + 1 // threshold
        + 4 + MAX_ROLES * RoleData::SIZE // role mapping
        + 8 // nonce
    + 8 // last_reset_unix
    + 1 // vault_bump
    + ACCOUNT_PADDING; // safety padding
}

#[account]
pub struct Proposal {
    pub proposer: Pubkey,
    pub multisig: Pubkey,
    pub destination: Pubkey,
    pub amount: u64,
    pub approvals: Vec<Pubkey>,
    pub executed: bool,
    pub created_at: i64,
    pub expires_at: i64,
    pub id: u64,
    pub bump: u8,
    /// Replaces the old `is_governance: bool`.  Now records the **exact**
    /// action (and its parameters) the proposal authorises.
    pub action: ProposalAction,
}

impl Proposal {
    pub const MAX_SIZE: usize = 32 + 32 + 32 + 8 + 4 + MAX_APPROVALS * 32 + 1 + 8 + 8 + 8 + 1
        + ProposalAction::MAX_SIZE
        + ACCOUNT_PADDING;
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum Role {
    BoardMember,
    FinanceOfficer,
    Auditor,
}

/// Encodes the exact governance action (or a plain transfer) so that
/// an approved proposal can **only** be used for its intended purpose.
#[derive(AnchorSerialize, AnchorDeserialize, Clone, PartialEq, Eq)]
pub enum ProposalAction {
    /// Regular SOL transfer – not a governance action.
    Transfer,
    /// Change the multisig approval threshold.
    UpdateThreshold { new_threshold: u8 },
    /// Add a new owner to the multisig.
    AddOwner { new_owner: Pubkey },
    /// Remove an existing owner from the multisig.
    RemoveOwner { owner: Pubkey },
    /// Change an owner's role.
    UpdateRole { owner: Pubkey, role: Role },
    /// Change an owner's monthly spending limit.
    UpdateMonthlyLimit { owner: Pubkey, new_limit: u64 },
}

impl ProposalAction {
    /// Returns `true` when the action is a plain SOL transfer.
    pub fn is_transfer(&self) -> bool {
        matches!(self, ProposalAction::Transfer)
    }

    /// Worst-case Borsh-serialised size (discriminator + largest payload).
    /// Largest variant: UpdateMonthlyLimit = 1 + 32 + 8 = 41 bytes.
    pub const MAX_SIZE: usize = 1 + 32 + 8;
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy)]
pub struct RoleData {
    pub owner: Pubkey,
    pub role: Role,
    pub monthly_limit: u64,
    pub spent_this_month: u64,
}

impl RoleData {
    pub const SIZE: usize = 32 + 1 + 8 + 8;
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct RoleInput {
    pub owner: Pubkey,
    pub role: Role,
    pub monthly_limit: u64,
}

#[error_code]
pub enum MultisigError {
    #[msg("No owners provided")]
    NoOwners,
    #[msg("Threshold invalid")]
    InvalidThreshold,
    #[msg("Too many owners")]
    TooManyOwners,
    #[msg("Too many roles")]
    TooManyRoles,
    #[msg("Owner not found")]
    OwnerNotFound,
    #[msg("Owner already exists")]
    OwnerExists,
    #[msg("Proposal already executed")]
    AlreadyExecuted,
    #[msg("Proposal expired")]
    ProposalExpired,
    #[msg("Proposal approvals exceed cap")]
    TooManyApprovals,
    #[msg("Not enough approvals")]
    NotEnoughApprovals,
    #[msg("Already approved")]
    AlreadyApproved,
    #[msg("Proposal mismatch")]
    ProposalMismatch,
    #[msg("Monthly limit exceeded")]
    MonthlyLimitExceeded,
    #[msg("Overflow")]
    Overflow,
    #[msg("Invalid expiration")]
    InvalidExpiration,
    #[msg("Invalid proposal type for this instruction")]
    InvalidProposalType,
    #[msg("Proposal action does not match the instruction being executed")]
    ActionMismatch,
    #[msg("Insufficient funds in vault")]
    InsufficientFunds,
}
