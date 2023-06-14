package main

import (
	. "github.com/bjartek/overflow"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestSwap(t *testing.T) {
	o, err := OverflowTesting()
	assert.NoError(t, err)

	setupFlowRoyalty := o.TxFileNameFN("setup_account_to_receive_royalty", WithArg("vaultPath", "/storage/flowTokenVault"))
	setupAccountForNFTs := o.TxFileNameFN("setup_account_for_example_nfts")
	setupAccountForSwap := o.TxFileNameFN("setup_account_for_swap")
	mintWhozitsNft := o.TxFileNameFN("mint_whozits_nft",
		WithSignerServiceAccount(),
		WithArg("description", "This is an example NFT"),
		WithArg("thumbnail", "example.jpeg"),
		WithArg("cuts", "[0.25, 0.40]"),
		WithArg("royaltyDescriptions", `["minter","creator"]`),
		WithAddresses("royaltyBeneficiaries", "alice", "bob"))
	mintWhatzitsNft := o.TxFileNameFN("mint_whatzits_nft",
		WithSignerServiceAccount(),
		WithArg("description", "This is an example NFT"),
		WithArg("thumbnail", "example.jpeg"),
		WithArg("cuts", "[0.25, 0.40]"),
		WithArg("royaltyDescriptions", `["minter","creator"]`),
		WithAddresses("royaltyBeneficiaries", "alice", "bob"))

	t.Run("Should properly initialize accounts", func(t *testing.T) {
		setupFlowRoyalty(WithSigner("alice")).AssertSuccess(t)
		setupFlowRoyalty(WithSigner("bob")).AssertSuccess(t)

		setupAccountForNFTs(WithSigner("alice")).AssertSuccess(t)
		setupAccountForNFTs(WithSigner("bob")).AssertSuccess(t)

		setupAccountForSwap(WithSigner("alice")).AssertSuccess(t)
		setupAccountForSwap(WithSigner("bob")).AssertSuccess(t)
		setupAccountForSwap(WithSigner("alice")).AssertFailure(t, "failed to save object: path /storage/evaluateSwapCollection in account 0x01cf0e2f2f715450 already stores an object")

		mintWhozitsNft(WithArg("recipient", "alice"), WithArg("name", "Whozits NFT 0"), WithSignerServiceAccount()).AssertSuccess(t)
		mintWhozitsNft(WithArg("recipient", "alice"), WithArg("name", "Whozits NFT 1"), WithSignerServiceAccount()).AssertSuccess(t)
		mintWhatzitsNft(WithArg("recipient", "bob"), WithArg("name", "Whatzits NFT 0"), WithSignerServiceAccount()).AssertSuccess(t)
		mintWhatzitsNft(WithArg("recipient", "bob"), WithArg("name", "Whatzits NFT 1"), WithSignerServiceAccount()).AssertSuccess(t)
	})

	createSwapProposal := o.TxFileNameFN("create_swap_proposal", WithArg("expirationInMinutes", 10.0))
	executeSwapProposal := o.TxFileNameFN("execute_swap_proposal", WithArg("feeVaultIdentifier", nil))

	t.Run("Should properly setup, execute, and delete swap proposal", func(t *testing.T) {
		createSwapProposal(WithSigner("alice"),
			WithArg("rightUserAddress", "bob"),
			WithArg("leftUserNfts", map[string][]uint64{
				"A.f8d6e0586b0a20c7.WhozitsNFT.NFT": []uint64{1},
			}),
			WithArg("rightUserNfts", map[string][]uint64{
				"A.f8d6e0586b0a20c7.WhatzitsNFT.NFT": []uint64{0},
			}),
			WithArg("feeVaultIdentifier", nil)).AssertSuccess(t)

		proposalId, scriptErr := o.Script("get_swap_proposal_id", WithArg("proposalOwner", "alice")).GetAsInterface()
		assert.NoError(t, scriptErr)

		executeSwapProposal(WithSigner("bob"),
			WithArg("leftUserAddress", "alice"),
			WithArg("proposalId", proposalId)).AssertSuccess(t)

		aliceOwnedWhozitsNFTs, scriptErr := o.Script("get_owned_whozits_nft_ids", WithArg("owner", "alice")).GetAsInterface()
		aliceOwnedWhatzitsNFTs, scriptErr := o.Script("get_owned_whatzits_nft_ids", WithArg("owner", "alice")).GetAsInterface()
		bobOwnedWhozitsNFTs, scriptErr := o.Script("get_owned_whozits_nft_ids", WithArg("owner", "bob")).GetAsInterface()
		bobOwnedWhatzitsNFTs, scriptErr := o.Script("get_owned_whatzits_nft_ids", WithArg("owner", "bob")).GetAsInterface()
		assert.NoError(t, scriptErr)

		assert.Equal(t, aliceOwnedWhozitsNFTs, []interface{}{uint64(0)}, "swap error")
		assert.Equal(t, aliceOwnedWhatzitsNFTs, []interface{}{uint64(0)}, "swap error")
		assert.Equal(t, bobOwnedWhozitsNFTs, []interface{}{uint64(1)}, "swap error")
		assert.Equal(t, bobOwnedWhatzitsNFTs, []interface{}{uint64(1)}, "swap error")

		executeSwapProposal(WithSigner("bob"),
			WithArg("leftUserAddress", "alice"),
			WithArg("proposalId", proposalId)).AssertFailure(t, "found no swap proposal with id")
	})

	deleteSwapProposal := o.TxFileNameFN("delete_swap_proposal")

	t.Run("Should properly setup and delete swap proposal", func(t *testing.T) {
		createSwapProposal(WithSigner("bob"),
			WithArg("rightUserAddress", "alice"),
			WithArg("leftUserNfts", map[string][]uint64{
				"A.f8d6e0586b0a20c7.WhozitsNFT.NFT": []uint64{1},
			}),
			WithArg("rightUserNfts", map[string][]uint64{
				"A.f8d6e0586b0a20c7.WhatzitsNFT.NFT": []uint64{0},
			}),
			WithArg("feeVaultIdentifier", nil)).AssertSuccess(t)

		proposalId, scriptErr := o.Script("get_swap_proposal_id", WithArg("proposalOwner", "bob")).GetAsInterface()
		assert.NoError(t, scriptErr)

		deleteSwapProposal(WithSigner("alice"), WithArg("proposalId", proposalId)).AssertFailure(t, "")
		deleteSwapProposal(WithSigner("bob"), WithArg("proposalId", proposalId)).AssertSuccess(t)

		deletedProposalId, scriptErr := o.Script("get_swap_proposal_id", WithArg("proposalOwner", "bob")).GetAsInterface()
		assert.Equal(t, nil, deletedProposalId, "swap proposal deletion error")

		executeSwapProposal(WithSigner("alice"),
			WithArg("leftUserAddress", "bob"),
			WithArg("proposalId", proposalId)).AssertFailure(t, "found no swap proposal with id")
	})
}
