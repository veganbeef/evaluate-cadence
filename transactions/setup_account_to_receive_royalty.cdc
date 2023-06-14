import FungibleToken from "../contracts/external/FungibleToken.cdc"
import MetadataViews from "../contracts/external/MetadataViews.cdc"

/// This transaction can be used to set up a receiver for any fungible token, which is specified by the `vaultPath` argument
transaction(vaultPath: StoragePath) {

    prepare(signer: AuthAccount) {

        // Return early if the account doesn't have a FungibleToken Vault
        if signer.borrow<&FungibleToken.Vault>(from: vaultPath) == nil {
            panic("A vault for the specified fungible token path does not exist")
        }


				if signer.getCapability<&{FungibleToken.Receiver, FungibleToken.Balance}>(MetadataViews.getRoyaltyReceiverPublicPath()).check() {
					return
				}
					
        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        let capability = signer.link<&{FungibleToken.Receiver, FungibleToken.Balance}>(
            MetadataViews.getRoyaltyReceiverPublicPath(),
            target: vaultPath
        )!

        // Make sure the capability is valid
        if !capability.check() { panic("Beneficiary capability is not valid!") }
    }
}
