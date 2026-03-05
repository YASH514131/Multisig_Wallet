import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { TrueWalletMultisig } from "../target/types/true_wallet_multisig";

// Placeholder smoke test to ensure workspace compiles.
describe("true_wallet_multisig", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);
  const program = anchor.workspace.TrueWalletMultisig as Program<TrueWalletMultisig>;

  it("Loads the program id", async () => {
    expect(program.programId).toBeDefined();
  });
});
