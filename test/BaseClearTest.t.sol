// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ValoremOptionsClearinghouse} from "valorem-core/ValoremOptionsClearinghouse.sol";

abstract contract BaseClearTest is Test {
    ValoremOptionsClearinghouse internal clearinghouse;

    address internal constant ALICE = address(0xAAAA);
    address internal constant BOB = address(0xBBBB);
    address internal constant CAROL = address(0xCCCC);

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17425255); // ~ 2023-06-06 21:30 pm EST
        clearinghouse = new ValoremOptionsClearinghouse(address(0x1111), address(0x2222));
    }
}
