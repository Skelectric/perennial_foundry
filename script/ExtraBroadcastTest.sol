// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

contract ExtraBroadcastTest is Script {
    function run() external {
        SomeLibrary.reflect(5);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        (bool success,) = address(0).call{value: 0 ether}("");
        vm.stopBroadcast();

        require(success, "Call failed.");

    }
}

library SomeLibrary {
    function reflect(uint number) external pure returns (uint) {
        return number;
    }
}