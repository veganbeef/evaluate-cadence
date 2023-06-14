import Swap from "../contracts/Swap.cdc"

/// This script returns the first swap proposal stored on the specified account (meant to be used when only one
/// proposal is present in the collection)
pub fun main(proposalOwner: Address): String {
    let authAccount = getAuthAccount(proposalOwner)
    let swapCollection = authAccount.borrow<&Swap.SwapCollection>(from: Swap.SwapCollectionStoragePath)!
    return swapCollection.getAllProposals().keys[0]
}