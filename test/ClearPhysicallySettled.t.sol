// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BaseClearTest.t.sol";

contract ValoremClearPhysicallySettledTest is BaseClearTest {
    function test_clearPhysicallySettled() public {
        //////// Creating an option type ////////

        // Alice creates a new option type.
        vm.startPrank(ALICE);

        uint96 underlyingAmount = 1e18;
        uint96 exerciseAmount = 2100e6;
        uint40 earliestExercise = uint40(block.timestamp);
        uint40 expiry = uint40(earliestExercise + 1 weeks);

        uint256 optionId = clearinghouse.newOptionType({
            underlyingAsset: address(WETH),
            underlyingAmount: underlyingAmount,
            exerciseAsset: address(USDC),
            exerciseAmount: exerciseAmount,
            exerciseTimestamp: earliestExercise,
            expiryTimestamp: expiry
        });

        //////// Writing an option ////////

        // Check balances before write.
        assertEq(WETH.balanceOf(ALICE), 1_000_000e18, "Alice WETH balance before wrwriteiting");
        assertEq(WETH.balanceOf(BOB), 1_000_000e18, "Bob WETH balance before write");
        assertEq(WETH.balanceOf(address(clearinghouse)), 0, "Clearinghouse WETH balance before write");

        // Alice writes 10 options, receiving 10 (long) option tokens and 1 (short) claim NFT.
        // The option tokens are fungible and have token ID `optionId`, while there can only
        // ever be one claim NFT with the given token ID `claimId`.
        WETH.approve(address(clearinghouse), type(uint256).max);
        uint256 claimId = clearinghouse.write(optionId, 10);

        // Write 5 more options on the same claim, for a total of 15.
        clearinghouse.write(claimId, 5);

        // Demonstrate how claim IDs auto-increment.
        assertEq(claimId, optionId + 1); // next claim written would be optionId + 2, then optionId + 3, etc.

        // Demonstrate how claims are linked to options written.
        IValoremOptionsClearinghouse.Claim memory claim = clearinghouse.claim(claimId);
        assertEq(claim.amountWritten, 15e18);
        assertEq(claim.amountExercised, 0);
        assertEq(claim.optionId, optionId);

        // Check balances after write.
        assertEq(clearinghouse.balanceOf(ALICE, optionId), 15, "Alice option balance after write");
        assertEq(clearinghouse.balanceOf(ALICE, claimId), 1, "Alice claim balance after write");
        assertEq(clearinghouse.balanceOf(BOB, optionId), 0, "Bob option balance after write");
        assertEq(WETH.balanceOf(ALICE), 1_000_000e18 - (15 * 1e18) - _valoremFee(15 * 1e18), "Alice WETH balance after write");
        assertEq(WETH.balanceOf(BOB), 1_000_000e18, "Bob WETH balance after write");
        assertEq(WETH.balanceOf(address(clearinghouse)), (15 * 1e18) + _valoremFee(15 * 1e18), "Clearinghouse WETH balance after write");

        //////// Transferring a long position ////////

        // Alice transfers 4 options to Bob.
        vm.prank(ALICE);
        clearinghouse.safeTransferFrom(ALICE, BOB, optionId, 4, "");

        // Check balances after transfer.
        assertEq(clearinghouse.balanceOf(ALICE, optionId), 11, "Alice option balance after transfer"); // 4 less due to transfer
        assertEq(clearinghouse.balanceOf(BOB, optionId), 4, "Bob option balance after transfer");

        //////// Exercising an option ////////

        // Check balances before exercise.
        assertEq(USDC.balanceOf(BOB), 1_000_000e6, "Bob USDC balance before exercise");
        assertEq(USDC.balanceOf(address(clearinghouse)), 0, "Clearinghouse USDC balance before exercise");

        // Warp to the exercise timestamp.
        vm.warp(earliestExercise);

        // Bob exercises 3 of his 4 options.
        vm.startPrank(BOB);
        USDC.approve(address(clearinghouse), type(uint256).max);
        clearinghouse.exercise(optionId, 3);
        vm.stopPrank();

        // Check balances after exercise.
        uint256 clearinghouseWethBalance = (12 * 1e18) + _valoremFee(15 * 1e18); // (3 * 1e18) less WETH due to exercise
        uint256 clearinghouseUsdcBalance = (3 * 2100e6) + _valoremFee(3 * 2100e6); // (3 * 2100e6) more USDC

        assertEq(clearinghouse.balanceOf(BOB, optionId), 1, "Bob option balance after exercise");
        assertEq(WETH.balanceOf(BOB), 1_000_000e18 + (3 * 1e18), "Bob WETH balance after exercise");
        assertEq(WETH.balanceOf(address(clearinghouse)), clearinghouseWethBalance, "Clearinghouse WETH balance after write");
        assertEq(USDC.balanceOf(BOB), 1_000_000e6 - (3 * 2100e6) - _valoremFee(3 * 2100e6), "Bob USDC balance after exercise");
        assertEq(USDC.balanceOf(address(clearinghouse)), clearinghouseUsdcBalance, "Clearinghouse USDC balance after exercise");

        //////// Redeeming a claim ////////

        // Warp to the expiry timestamp.
        vm.warp(expiry);

        // Check balances before redeem.
        uint256 aliceWethBalance = 1_000_000e18 - (15 * 1e18) - _valoremFee(15 * 1e18);
        uint256 aliceUsdcBalance = 1_000_000e6;

        assertEq(clearinghouse.balanceOf(ALICE, claimId), 1, "Alice claim balance before redeem");
        assertEq(WETH.balanceOf(ALICE), aliceWethBalance, "Alice WETH balance before redeem");
        assertEq(USDC.balanceOf(ALICE), aliceUsdcBalance, "Alice USDC balance before redeem");

        // Alice redeems her claim.
        vm.prank(ALICE);
        clearinghouse.redeem(claimId);

        // Check balances after redeem.
        // Alice has (12 * 1e18) more WETH due to redeeming claim over 12 options that were not exercised,
        // and (3 * 2100e6) more USDC from the 3 options that were exercised. (And Bob still has the final
        // option that Alice originally wrote and transferred to him, but he let it expire.)
        aliceWethBalance += 12 * 1e18;
        aliceUsdcBalance += 3 * 2100e6;
        clearinghouseWethBalance -= 12 * 1e18;
        clearinghouseUsdcBalance -= 3 * 2100e6;

        assertEq(clearinghouse.balanceOf(ALICE, claimId), 0, "Alice claim balance after redeem");
        assertEq(WETH.balanceOf(ALICE), aliceWethBalance, "Alice WETH balance after redeem");
        assertEq(WETH.balanceOf(address(clearinghouse)), clearinghouseWethBalance, "Clearinghouse WETH balance after redeem");
        assertEq(USDC.balanceOf(ALICE), aliceUsdcBalance, "Alice USDC balance after redeem");
        assertEq(USDC.balanceOf(address(clearinghouse)), clearinghouseUsdcBalance, "Clearinghouse USDC balance after redeem");
        assertEq(clearinghouse.balanceOf(BOB, optionId), 1, "Bob option balance after redeem");
    }
}
