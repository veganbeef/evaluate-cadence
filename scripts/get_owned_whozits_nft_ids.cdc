import WhozitsNFT from "../contracts/external/WhozitsNFT.cdc"
import NonFungibleToken from "../contracts/external/NonFungibleToken.cdc"

/// This script returns the array of NFT IDs owned by the specified account
pub fun main(owner: Address): [UInt64] {
    let publicAccount = getAccount(owner)
    let collectionPublic = publicAccount.getCapability<&{NonFungibleToken.CollectionPublic}>(WhozitsNFT.CollectionPublicPath).borrow()!
    return collectionPublic.getIDs()
}