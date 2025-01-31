import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test bounty creation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            // Owner creating bounty should succeed
            Tx.contractCall('bug-bounty', 'create-bounty', [
                types.ascii("Test Bounty"),
                types.ascii("Find bugs in smart contract"),
                types.uint(1000)
            ], deployer.address),
            
            // Non-owner creating bounty should fail
            Tx.contractCall('bug-bounty', 'create-bounty', [
                types.ascii("Test Bounty 2"),
                types.ascii("Find more bugs"),
                types.uint(2000)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr(types.uint(100));
    },
});

Clarinet.test({
    name: "Test dispute resolution flow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const hunter = accounts.get('wallet_1')!;
        const other = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('bug-bounty', 'create-bounty', [
                types.ascii("Security Bug"),
                types.ascii("Find security vulnerabilities"),
                types.uint(5000)
            ], deployer.address),
            
            Tx.contractCall('bug-bounty', 'submit-bug', [
                types.uint(1)
            ], hunter.address),
            
            Tx.contractCall('bug-bounty', 'file-dispute', [
                types.uint(1),
                types.ascii("Incorrect rejection")
            ], hunter.address),

            // Non-hunter trying to file dispute should fail
            Tx.contractCall('bug-bounty', 'file-dispute', [
                types.uint(1),
                types.ascii("Invalid dispute")
            ], other.address),

            // Owner resolving dispute with approval
            Tx.contractCall('bug-bounty', 'resolve-dispute', [
                types.uint(1),
                types.bool(true)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk(); 
        block.receipts[2].result.expectOk();
        block.receipts[3].result.expectErr(types.uint(105));
        block.receipts[4].result.expectOk();
    },
});
