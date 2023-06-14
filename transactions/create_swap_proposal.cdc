import Swap from "../contracts/Swap.cdc"
import Utils from "../contracts/Utils.cdc"
import TransactionGenerationUtils from "../contracts/external/TransactionGenerationUtils.cdc"
import FungibleToken from "../contracts/external/FungibleToken.cdc"
import StringUtils from "../contracts/external/StringUtils.cdc"
import NonFungibleToken from "../contracts/external/NonFungibleToken.cdc"
import MetadataViews from "../contracts/external/MetadataViews.cdc"

/// This transaction creates a swap proposal, with leftUserNfts and rightUserNfts each maps of NFT type identifier
/// strings to NFT ID arrays, for example { "A.f8d6e0586b0a20c7.ExampleNFT.NFT": [0] }
transaction(rightUserAddress: Address, leftUserNfts: { String: [UInt64] }, rightUserNfts: { String: [UInt64] }, expirationInMinutes: UFix64, feeVaultIdentifier: String?) {

	let leftUserOffer: Swap.UserOffer
	let rightUserOffer: Swap.UserOffer
	let leftCollectionReceiverCapabilities: {String: Capability<&{NonFungibleToken.Receiver}>}
	let leftCollectionProviderCapabilities: {String: Capability<&{NonFungibleToken.Provider}>}
	let leftFeeProviderCapabilities: {String: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>}
	let leftUserAccount: AuthAccount

	prepare(signer: AuthAccount) {

		let missingReceiverMessage: String = "Missing or invalid receiver capability for "
		let providerLinkFailedMessage: String = "Unable to create private link to collection provider for "
		let invalidNftFormatMessage: String = "Invalid proposed NFT format"

		self.leftUserAccount = signer

		let mapNfts = fun (ownerAddress: Address, _ inputNfts: { String: [UInt64] }): [Swap.ProposedTradeAsset] {

            let collectionDataMap = Utils.getNFTCollectionData(ownerAddress: ownerAddress, nftIdentifiers: inputNfts.keys)

			var proposedNfts: [Swap.ProposedTradeAsset] = []

            inputNfts.forEachKey(fun (key: String): Bool {

                for nftID in inputNfts[key]! {

                    proposedNfts.append(Swap.ProposedTradeAsset(
                        nftID: nftID,
                        type: key,
                        collectionData: collectionDataMap[key] ?? panic("no collection data for: ".concat(key))
                    ))
                }

                return true
            })

			return proposedNfts
		}

		let leftProposedNfts: [Swap.ProposedTradeAsset] = mapNfts(ownerAddress: signer.address, leftUserNfts)

		let rightProposedNfts: [Swap.ProposedTradeAsset] = mapNfts(ownerAddress: rightUserAddress, rightUserNfts)

		self.leftFeeProviderCapabilities = { }

		if (feeVaultIdentifier != nil) {

			let getPathIdentifier = fun (_ path: String): String {

				let array = StringUtils.split(path, "/")

				return array[array.length - 1]
			}

			let ftSchema = TransactionGenerationUtils.getFtSchema(vaultIdentifier: feeVaultIdentifier!) ?? panic("Invalid vault identifier")

			let privatePath = ftSchema.privatePath.getType() == Type<String>() ? PrivatePath(identifier: getPathIdentifier(ftSchema.privatePath))! : ftSchema.privatePath as! PrivatePath
			let storagePath = ftSchema.storagePath.getType() == Type<String>() ? StoragePath(identifier: getPathIdentifier(ftSchema.storagePath))! : ftSchema.storagePath as! StoragePath

			var feeProvider = signer.getCapability<&{FungibleToken.Provider, FungibleToken.Balance}>(privatePath)
			if (feeProvider == nil || !feeProvider.check()) {

				let vaultRef = signer.borrow<&{FungibleToken.Provider}>(from: storagePath) ?? panic("Unable to find vault")
				signer.unlink(privatePath)
				feeProvider = signer.link<&{FungibleToken.Provider, FungibleToken.Balance}>(privatePath, target: storagePath)!
			}

			self.leftFeeProviderCapabilities[ftSchema.type.identifier] = feeProvider
		}

		self.leftUserOffer = Swap.UserOffer(userAddress: signer.address, proposedNfts: leftProposedNfts, metadata: nil)
		self.rightUserOffer = Swap.UserOffer(userAddress: rightUserAddress, proposedNfts: rightProposedNfts, metadata: nil)

		self.leftCollectionReceiverCapabilities = { }

		let partnerPublicAccount: PublicAccount = getAccount(rightUserAddress)

		for partnerProposedNft in self.rightUserOffer.proposedNfts {

			if (self.leftCollectionReceiverCapabilities[partnerProposedNft.type.identifier] == nil) {

				if (signer.type(at: partnerProposedNft.collectionData.storagePath) != nil) {

					let receiverCapability = signer.getCapability<&{NonFungibleToken.Receiver}>(partnerProposedNft.collectionData.publicPath)
					if (receiverCapability.check()) {

						self.leftCollectionReceiverCapabilities[partnerProposedNft.type.identifier] = receiverCapability
						continue
					}
				}

				panic(missingReceiverMessage.concat(partnerProposedNft.type.identifier))
			}
		}

		self.leftCollectionProviderCapabilities = { }

		for proposedNft in self.leftUserOffer.proposedNfts {

			if (self.leftCollectionProviderCapabilities[proposedNft.type.identifier] == nil) {

				if (signer.getCapability<&{NonFungibleToken.Provider}>(proposedNft.collectionData.providerPath).borrow() == nil) {

					signer.unlink(proposedNft.collectionData.providerPath)
					signer.link<&{NonFungibleToken.Provider}>(proposedNft.collectionData.providerPath, target: proposedNft.collectionData.storagePath)
				}

				let providerCapability = signer.getCapability<&{NonFungibleToken.Provider}>(proposedNft.collectionData.providerPath)
				if (providerCapability.check()) {

					self.leftCollectionProviderCapabilities[proposedNft.type.identifier] = providerCapability
					continue
				}

				panic(providerLinkFailedMessage.concat(proposedNft.type.identifier))
			}
		}
	}

	execute {

		let storedType = self.leftUserAccount.type(at: Swap.SwapCollectionStoragePath)

		if (storedType != nil && storedType != Type<@Swap.SwapCollection>()) {

			let oldCollection <- self.leftUserAccount.load<@AnyResource>(from: Swap.SwapCollectionStoragePath)
			destroy oldCollection
		}

		if (self.leftUserAccount.type(at: Swap.SwapCollectionStoragePath) == nil) {

			let newCollection <- Swap.createEmptySwapCollection()
			self.leftUserAccount.save(<-newCollection, to: Swap.SwapCollectionStoragePath)
		}

		if (self.leftUserAccount.getCapability<&{Swap.SwapCollectionPublic}>(Swap.SwapCollectionPublicPath).borrow() == nil) {

			self.leftUserAccount.unlink(Swap.SwapCollectionPublicPath)
			self.leftUserAccount.link<&{Swap.SwapCollectionPublic}>(Swap.SwapCollectionPublicPath, target: Swap.SwapCollectionStoragePath)
		}

		if (self.leftUserAccount.getCapability<&{Swap.SwapCollectionManager}>(Swap.SwapCollectionPrivatePath).borrow() == nil) {

			self.leftUserAccount.unlink(Swap.SwapCollectionPrivatePath)
			self.leftUserAccount.link<&{Swap.SwapCollectionManager}>(Swap.SwapCollectionPrivatePath, target: Swap.SwapCollectionStoragePath)
		}

		let swapCollectionManagerCapability = self.leftUserAccount.getCapability<&{Swap.SwapCollectionManager}>(Swap.SwapCollectionPrivatePath)
		assert(swapCollectionManagerCapability.check(), message: "Got invalid SwapCollectionManager capability")
		let swapCollectionManager = swapCollectionManagerCapability.borrow()!

		swapCollectionManager.createProposal(
			leftUserOffer: self.leftUserOffer,
			rightUserOffer: self.rightUserOffer,
			leftUserCapabilities: Swap.UserCapabilities(
				collectionReceiverCapabilities: self.leftCollectionReceiverCapabilities,
				collectionProviderCapabilities: self.leftCollectionProviderCapabilities,
				feeProviderCapabilities: self.leftFeeProviderCapabilities,
				extraCapabilities: nil
			),
			expirationOffsetMinutes: expirationInMinutes,
			metadata: nil
		)
	}
}
