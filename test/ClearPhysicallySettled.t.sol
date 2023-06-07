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

        // Check balances before writing.
        assertEq(WETH.balanceOf(ALICE), 1_000_000e18, "Alice WETH balance before writing");
        assertEq(WETH.balanceOf(BOB), 1_000_000e18, "Bob WETH balance before writing");
        assertEq(WETH.balanceOf(CAROL), 1_000_000e18, "Carol WETH balance before writing");
        assertEq(WETH.balanceOf(address(clearinghouse)), 0, "Clearinghouse WETH balance before writing");

        // Alice writes 10 options, receiving 10 (long) option tokens and 1 (short) claim NFT.
        // The option tokens are fungible and have token ID `optionId`, while there can only
        // ever be one claim NFT with the given token ID `claimId`.
        WETH.approve(address(clearinghouse), type(uint256).max);
        uint256 claimId = clearinghouse.write(optionId, 10);

        // Write 5 more options on the same claim, for a total of 15.
        clearinghouse.write(claimId, 5);

        // Carol writes 20 options on a new claim.
        vm.stopPrank();
        vm.startPrank(CAROL);
        WETH.approve(address(clearinghouse), type(uint256).max);
        uint256 claimId2 = clearinghouse.write(optionId, 20);
        vm.stopPrank();

        // Demonstrate how claim IDs auto-increment.
        assertEq(claimId, optionId + 1);
        assertEq(claimId2, optionId + 2);

        // Demonstrate how claims are linked to options written.
        IValoremOptionsClearinghouse.Claim memory claim1 = clearinghouse.claim(claimId);
        assertEq(claim1.amountWritten, 15e18);
        assertEq(claim1.amountExercised, 0);
        assertEq(claim1.optionId, optionId);
        IValoremOptionsClearinghouse.Claim memory claim2 = clearinghouse.claim(claimId2);
        assertEq(claim2.amountWritten, 20e18);
        assertEq(claim2.amountExercised, 0);
        assertEq(claim2.optionId, optionId);

        // Check balances after writing.
        assertEq(clearinghouse.balanceOf(ALICE, optionId), 15, "Alice option balance after writing");
        assertEq(clearinghouse.balanceOf(ALICE, claimId), 1, "Alice claim1 balance after writing");
        assertEq(clearinghouse.balanceOf(BOB, optionId), 0, "Bob option balance after writing");
        assertEq(clearinghouse.balanceOf(CAROL, optionId), 20, "Carol option balance after writing");
        assertEq(clearinghouse.balanceOf(CAROL, claimId2), 1, "Carol claim2 balance after writing");
        assertEq(
            WETH.balanceOf(ALICE),
            1_000_000e18 - (15 * 1e18) - _valoremFee(15 * 1e18),
            "Alice WETH balance after writing"
        );
        assertEq(WETH.balanceOf(BOB), 1_000_000e18, "Bob WETH balance after writing");
        assertEq(
            WETH.balanceOf(CAROL),
            1_000_000e18 - (20 * 1e18) - _valoremFee(20 * 1e18),
            "Carol WETH balance after writing"
        );
        assertEq(
            WETH.balanceOf(address(clearinghouse)),
            (35 * 1e18) + _valoremFee(35 * 1e18),
            "Clearinghouse WETH balance after writing"
        );

        //////// Transferring a long position ////////

        // Alice transfers 4 options to Bob.
        vm.prank(ALICE);
        clearinghouse.safeTransferFrom(ALICE, BOB, optionId, 4, "");

        // Check balances after transfer.
        assertEq(clearinghouse.balanceOf(ALICE, optionId), 11, "Alice option balance after transferring");
        assertEq(clearinghouse.balanceOf(BOB, optionId), 4, "Bob option balance after transferring");
        assertEq(clearinghouse.balanceOf(CAROL, optionId), 20, "Carol option balance after transferring");

        //////// Exercising an option ////////

        // Check balances before exercise.
        assertEq(USDC.balanceOf(BOB), 1_000_000e6, "Bob USDC balance before exercising");
        assertEq(USDC.balanceOf(address(clearinghouse)), 0, "Clearinghouse USDC balance before exercising");

        // Warp to the exercise timestamp.
        vm.warp(earliestExercise);

        // Bob exercises 3 of his 4 options.
        vm.startPrank(BOB);
        USDC.approve(address(clearinghouse), type(uint256).max);
        clearinghouse.exercise(optionId, 3);
        vm.stopPrank();

        // Check balances after exercise.
        assertEq(clearinghouse.balanceOf(BOB, optionId), 1, "Bob option balance after exercising");
        assertEq(
            USDC.balanceOf(BOB),
            1_000_000e6 - (3 * 2100e6) - _valoremFee(3 * 2100e6),
            "Bob USDC balance after exercising"
        );
        assertEq(
            USDC.balanceOf(address(clearinghouse)),
            (3 * 2100e6) + _valoremFee(3 * 2100e6),
            "Clearinghouse USDC balance after exercising"
        );

        //////// Redeeming a claim ////////

        // Warp to the expiry timestamp.
        vm.warp(expiry);

        // Check balances before redeeming.
        // TODO

        // Redeem our claim.
        vm.prank(ALICE);
        clearinghouse.redeem(claimId);

        // Check balances after redeeming.
        // TODO
    }
}
