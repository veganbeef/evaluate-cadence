import NonFungibleToken from "../contracts/external/NonFungibleToken.cdc"
import WhozitsNFT from "../contracts/external/WhozitsNFT.cdc"
import WhatzitsNFT from "../contracts/external/WhatzitsNFT.cdc"
import MetadataViews from "../contracts/external/MetadataViews.cdc"

/// This transaction is what an account would run to set itself up to receive NFTs
transaction {
    let signer: AuthAccount

    prepare(signer: AuthAccount) {
        self.signer = signer
    }

    execute {
        if self.signer.borrow<&WhozitsNFT.Collection>(from: WhozitsNFT.CollectionStoragePath) == nil {

            // Create a new empty collection
            let collection <- WhozitsNFT.createEmptyCollection()

            // save it to the account
            self.signer.save(<-collection, to: WhozitsNFT.CollectionStoragePath)

            // create a public capability for the collection
            self.signer.link<&{NonFungibleToken.CollectionPublic, WhozitsNFT.WhozitsNFTCollectionPublic, MetadataViews.ResolverCollection, NonFungibleToken.Receiver}>(
                WhozitsNFT.CollectionPublicPath,
                target: WhozitsNFT.CollectionStoragePath
            )
        }

        if self.signer.borrow<&WhatzitsNFT.Collection>(from: WhatzitsNFT.CollectionStoragePath) == nil {

            // Create a new empty collection
            let collection <- WhatzitsNFT.createEmptyCollection()

            // save it to the account
            self.signer.save(<-collection, to: WhatzitsNFT.CollectionStoragePath)

            // create a public capability for the collection
            self.signer.link<&{NonFungibleToken.CollectionPublic, WhatzitsNFT.WhatzitsNFTCollectionPublic, MetadataViews.ResolverCollection, NonFungibleToken.Receiver}>(
                WhatzitsNFT.CollectionPublicPath,
                target: WhatzitsNFT.CollectionStoragePath
            )
        }
    }
}
