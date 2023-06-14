import Swap from "../contracts/Swap.cdc"
import TransactionGenerationUtils from "../contracts/external/TransactionGenerationUtils.cdc"
import StringUtils from "../contracts/external/StringUtils.cdc"
import MetadataViews from "../contracts/external/MetadataViews.cdc"
import NonFungibleToken from "../contracts/external/NonFungibleToken.cdc"
import FungibleToken from "../contracts/external/FungibleToken.cdc"

/// This transaction executes the specified swap proposal created by the specified leftUserAddress
transaction(leftUserAddress: Address, proposalId: String, feeVaultIdentifier: String?) {

	let rightCollectionReceiverCapabilities: {String: Capability<&{NonFungibleToken.Receiver}>}
	let rightCollectionProviderCapabilities: {String: Capability<&{NonFungibleToken.Provider}>}
	let rightUserFeeProviderCapabilities: {String: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>}
	let leftUserSwapCollection: &{Swap.SwapCollectionPublic}

	prepare(signer: AuthAccount) {

		let missingProviderMessage: String = "Missing or invalid provider capability for "
		let providerLinkFailedMessage: String = "Unable to create private link to collection provider for "

		let leftUserAccount: PublicAccount = getAccount(leftUserAddress)

		let leftUserSwapCollectionCapability = leftUserAccount.getCapability<&{Swap.SwapCollectionPublic}>(Swap.SwapCollectionPublicPath)
		assert(leftUserSwapCollectionCapability.check(), message: "Invalid SwapCollectionPublic capability")
		self.leftUserSwapCollection = leftUserSwapCollectionCapability.borrow() ?? panic("leftUserSwapCollection is invalid")

		self.rightUserFeeProviderCapabilities = { }

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

			self.rightUserFeeProviderCapabilities[ftSchema.type.identifier] = feeProvider
		}

		self.rightCollectionReceiverCapabilities = { }

		let leftUserOffer = self.leftUserSwapCollection.getUserOffer(proposalId: proposalId, leftOrRight: "left")

		for partnerProposedNft in leftUserOffer.proposedNfts {

			if (self.rightCollectionReceiverCapabilities[partnerProposedNft.type.identifier] == nil) {

				if (signer.type(at: partnerProposedNft.collectionData.storagePath) != nil) {

					let receiverCapability = signer.getCapability<&{NonFungibleToken.Receiver}>(partnerProposedNft.collectionData.publicPath)
					if (receiverCapability.check()) {

						self.rightCollectionReceiverCapabilities[partnerProposedNft.type.identifier] = receiverCapability
						continue
					}
				}

				panic(missingProviderMessage.concat(partnerProposedNft.type.identifier))
			}
		}

		self.rightCollectionProviderCapabilities = { }

		let rightUserOffer = self.leftUserSwapCollection.getUserOffer(proposalId: proposalId, leftOrRight: "right")

		for proposedNft in rightUserOffer.proposedNfts {

			if (self.rightCollectionProviderCapabilities[proposedNft.type.identifier] == nil) {

				if (signer.getCapability<&{NonFungibleToken.Provider}>(proposedNft.collectionData.providerPath).borrow() == nil) {

					signer.unlink(proposedNft.collectionData.providerPath)
					signer.link<&{NonFungibleToken.Provider}>(proposedNft.collectionData.providerPath, target: proposedNft.collectionData.storagePath)
				}

				let providerCapability = signer.getCapability<&{NonFungibleToken.Provider}>(proposedNft.collectionData.providerPath)
				if (providerCapability.check()) {

					self.rightCollectionProviderCapabilities[proposedNft.type.identifier] = providerCapability
					continue

				}

				panic(providerLinkFailedMessage.concat(proposedNft.type.identifier))
			}
		}
	}

	execute {

		self.leftUserSwapCollection.executeProposal(
			id: proposalId,
			rightUserCapabilities: Swap.UserCapabilities(
				collectionReceiverCapabilities: self.rightCollectionReceiverCapabilities,
				collectionProviderCapabilities: self.rightCollectionProviderCapabilities,
				feeProviderCapabilities: self.rightUserFeeProviderCapabilities,
				extraCapabilities: nil
			)
		)
	}
}