// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

// import "../script/util/CreatePayoffDefinition.sol";

contract TestCreatePayoffDefinition is Test {
    address constant testAddr = 0xd6E1fE2d44555597828eD5a7401A481a7654A530;

    function testConversion() external {
        bytes30 bys = toBytes30(testAddr);
        address addr = toAddr(bys);
        console.log("testAddr: %s", testAddr);
        console.log("addr: %s", addr);
        assertEq(testAddr, addr);
    }

    function toBytes30(address addr) internal pure returns (bytes30) {
        return bytes30(bytes20(addr)) >> 80;
    }

    function toAddr(bytes30 bys) internal pure returns (address) {
        return address(bytes20(bys << 80));
    }
}