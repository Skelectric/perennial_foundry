// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

contract FFITest is Script {
    function run() external {
        string[] memory commands = new string[](4);
        commands[0] = "powershell.exe";
        commands[1] = "set-content";
        commands[2] = "env:\test2";
        commands[3] = "testvalue2";
        vm.ffi(commands);
    }
}