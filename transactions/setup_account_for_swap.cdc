import Swap from "../contracts/Swap.cdc"

/// This transaction is what an account would run to set itself up for evaluate's Swap platform
transaction() {
    let acct: AuthAccount

    prepare(acct: AuthAccount) {
        self.acct = acct
    }

    execute {
        // Create and store swap collection
        let swapCollection <- Swap.createEmptySwapCollection()
        self.acct.save<@Swap.SwapCollection>(<-swapCollection, to: Swap.SwapCollectionStoragePath)

        // Link public and private capabilities
        self.acct.link<&Swap.SwapCollection{Swap.SwapCollectionManager}>(Swap.SwapCollectionPrivatePath, target: Swap.SwapCollectionStoragePath)
        self.acct.link<&Swap.SwapCollection{Swap.SwapCollectionPublic}>(Swap.SwapCollectionPublicPath, target: Swap.SwapCollectionStoragePath)
    }
}
