import Swap from "../contracts/Swap.cdc"

/// This transaction allows or disallows swap proposal creation and is meant to be signed by the Swap contract owner
transaction(isCreationAllowed: Bool) {
    let swapAdmin: &{Swap.SwapProposalManager}

    prepare(signer: AuthAccount) {
        self.swapAdmin = signer.getCapability<&{Swap.SwapProposalManager}>(Swap.SwapAdminPrivatePath).borrow()!
    }

    execute {
        if (isCreationAllowed) {
            self.swapAdmin.startProposalCreation()
        } else {
            self.swapAdmin.stopProposalCreation()
        }
    }
}