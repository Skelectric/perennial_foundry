// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

contract WriteTest is Test {

    string filepath = "test/write_test/hello_world.txt";

    function testWrite() external {
        vm.writeFile(filepath, "hello world!");
        string memory data = vm.readFile(filepath);
        assertEq(data, "hello world!");
    }

}