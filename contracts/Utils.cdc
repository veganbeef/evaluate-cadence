import MetadataViews from "./external/MetadataViews.cdc"
import NonFungibleToken from "./external/NonFungibleToken.cdc"
import StringUtils from "./external/StringUtils.cdc"

access(all) contract Utils {

    /// StorableNFTCollectionData
    /// This struct copies MetadataViews.NFTCollectionData without the createEmptyCollection reference to be storable.
    access(all) struct StorableNFTCollectionData {
        pub let storagePath: StoragePath
        pub let publicPath: PublicPath
        pub let providerPath: PrivatePath
        pub let publicCollection: Type
        pub let publicLinkedType: Type
        pub let providerLinkedType: Type

        init(_ collectionData: MetadataViews.NFTCollectionData) {
            self.storagePath = collectionData.storagePath
            self.publicPath = collectionData.publicPath
            self.providerPath = collectionData.providerPath
            self.publicCollection = collectionData.publicCollection
            self.publicLinkedType = collectionData.publicLinkedType
            self.providerLinkedType = collectionData.providerLinkedType
        }
    }

    /// ContractMetadata
    /// This struct holds all relevant metadata for a given contract type.
    access(all) struct ContractMetadata {
        pub let type: Type
        pub let address: String
        pub let name: String
        pub let context: {String: String}?

        init(type: Type, context: {String: String}?) {
            let parts = StringUtils.split(type.identifier, ".")

            self.type = type
            self.address = "0x".concat(parts[1])
            self.name = parts[2]
            self.context = context
        }
    }

    /// getIdentifierContractMetadata
    /// This helper function returns the contract metadata for a given type identifier.
    access(all) fun getIdentifierContractMetadata(identifier: String): ContractMetadata {

    	return ContractMetadata(type: Utils.getIdentifierContractType(identifier: identifier), context: nil)
    }

    /// getIdentifierContractType
    /// This helper function returns the contract type for a given type identifier.
    access(all) fun getIdentifierContractType(identifier: String): Type {

        let parts = StringUtils.split(identifier, ".")

        assert(parts.length == 4, message: "invalid identifier")

        let contractIdentifier = StringUtils.join(parts.slice(from: 0, upTo: parts.length - 1), ".")

        return CompositeType(contractIdentifier)!
    }

    /// getCollectionPaths
    /// This function searches the specified account and returns a dictionary of NFTCollectionData structs by
    /// collectionIdentifier. If a collectionIdentifier is not found in the specified ownerAddress, or that collection
    /// does not provide a resolver for NFTCollectionData, the response value will be "nil".
    access(all) fun getNFTCollectionData(ownerAddress: Address, nftIdentifiers: [String]): {String: MetadataViews.NFTCollectionData} {

        let response: {String: MetadataViews.NFTCollectionData} = {}

        let account = getAccount(ownerAddress)

    	account.forEachPublic(fun (path: PublicPath, type: Type): Bool {

            let collectionPublic = account.getCapability<&{NonFungibleToken.CollectionPublic}>(path).borrow()
    	    if (collectionPublic == nil) {

    		    return true
    	    }

            let contractType = Utils.getIdentifierContractType(identifier: collectionPublic!.getType().identifier)
            let nftIdentifier = contractType.identifier.concat(".NFT")

    		if (!nftIdentifiers.contains(nftIdentifier) || response.containsKey(nftIdentifier)) {

    		    return true
    	    }

            let nftRef: &{NonFungibleToken.INFT} = collectionPublic!.borrowNFT(id: collectionPublic!.getIDs()[0]) as &{NonFungibleToken.INFT}

            let collectionData = (nftRef.resolveView(Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?)
                ?? panic("collection lookup failed")

            response.insert(key: nftIdentifier, collectionData)

            return true
        })

    	return response
    }
}
