// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

contract WriteScript is Script {

    string filepath = "script/hello_world.txt";

    function run() external {
        vm.writeFile(filepath, "hello world!");
        string memory data = vm.readFile(filepath);
        console.log(data);
    }

}