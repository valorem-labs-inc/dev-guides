// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/interfaces/IERC20.sol";

import {ValoremOptionsClearinghouse} from "valorem-core/ValoremOptionsClearinghouse.sol";
import {IValoremOptionsClearinghouse} from "valorem-core/interfaces/IValoremOptionsClearinghouse.sol";

abstract contract BaseClearTest is Test {
    // Valorem
    ValoremOptionsClearinghouse internal clearinghouse;

    // Assets
    IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal constant LINK = IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    IERC20 internal constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Users
    address internal constant ALICE = address(0xAAAA);
    address internal constant BOB = address(0xBBBB);
    address internal constant CAROL = address(0xCCCC);

    function setUp() public {
        // Fork mainnet.
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17425255); // ~ 2023-06-06 21:30 pm EST

        // Deploy Valorem infrastructure. // TODO replace with actual deployed address
        clearinghouse = new ValoremOptionsClearinghouse(address(0x1111), address(0x2222));
        vm.prank(address(0x1111));
        clearinghouse.setFeesEnabled(true);

        // Deal users some ether and tokens.
        address[] memory users = new address[](3);
        users[0] = ALICE;
        users[1] = BOB;
        users[2] = CAROL;
        for (uint256 i = 0; i < users.length; i++) {
            vm.deal(users[i], 100 ether);
            deal(address(WETH), users[i], 1_000_000e18);
            deal(address(LINK), users[i], 1_000_000e18);
            deal(address(USDC), users[i], 1_000_000e6);
        }
    }

    function _valoremFee(uint256 amount) internal view returns (uint256) {
        return (amount * clearinghouse.feeBps()) / 10_000;
    }
}
