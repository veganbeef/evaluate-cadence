import Swap from "../contracts/Swap.cdc"

/// This transaction deletes the specified swap proposal from the signer's account
transaction(proposalId: String) {
    let swapCollectionManager: &{Swap.SwapCollectionManager}

    prepare(signer: AuthAccount) {
        self.swapCollectionManager = signer.getCapability<&{Swap.SwapCollectionManager}>(Swap.SwapCollectionPrivatePath).borrow()!
    }

    execute {
        self.swapCollectionManager.deleteProposal(id: proposalId)
    }
}