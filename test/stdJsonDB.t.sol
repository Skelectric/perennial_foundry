// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import "../script/util/stdJsonDB.sol";

contract stdJsonDBTest is Test {
    using stdJson for string;

    function storeVars_setA(string memory _filepath) internal {
        stdJsonDB.set("zero", address(0), _filepath);
        stdJsonDB.set("one", address(1), _filepath);
        stdJsonDB.set("oneEther", 1 ether, _filepath);
    }

    function storeVars_setB(string memory _filepath) internal {
        stdJsonDB.set("two", address(2), _filepath);
        stdJsonDB.set("three", address(3), _filepath);
        stdJsonDB.set("twoEther", 2 ether, _filepath);
    }

    function storeVars_setC(string memory _filepath) internal {
        stdJsonDB.set("Name", "stdJsonDB", _filepath);
    }

    function changeVars_setA2(string memory _filepath) internal {
        stdJsonDB.set("zero", address(3), _filepath);
        stdJsonDB.set("one", address(10), _filepath);
        stdJsonDB.set("oneEther", 0.1 ether, _filepath);
    }

    function checkVars_setA(string memory _filepath) internal {
        address parsedZero = stdJsonDB.getAddr("zero", _filepath);
        address parsedOne = stdJsonDB.getAddr("one", _filepath);
        uint parsedOneEth = stdJsonDB.getUint("oneEther", _filepath);
        assertEq(parsedZero, address(0));
        assertEq(parsedOne, address(1));
        assertEq(parsedOneEth, 1 ether);       
    }

    function checkVars_setB(string memory _filepath) internal {
        address parsedTwo = stdJsonDB.getAddr("two", _filepath);
        address parsedThree = stdJsonDB.getAddr("three", _filepath);
        uint parsedTwoEth = stdJsonDB.getUint("twoEther", _filepath);
        assertEq(parsedTwo, address(2));
        assertEq(parsedThree, address(3));
        assertEq(parsedTwoEth, 2 ether);       
    }

    function checkVars_setA2(string memory _filepath) internal {
        address parsedZero = stdJsonDB.getAddr("zero", _filepath);
        address parsedOne = stdJsonDB.getAddr("one", _filepath);
        uint parsedOneEth = stdJsonDB.getUint("oneEther", _filepath);
        assertEq(parsedZero, address(3));
        assertEq(parsedOne, address(10));
        assertEq(parsedOneEth, 0.1 ether);    
    }

    function checkVars_setC(string memory _filepath) internal {
        string memory name = stdJsonDB.getString("Name", _filepath);
        assertEq(name, "stdJsonDB");
    }

    function testSerializationAndDeserialization() public {

        string memory filepath = "/test/json_tests/testJson.json";

        storeVars_setA(filepath);
        checkVars_setA(filepath);

        storeVars_setB(filepath);
        checkVars_setA(filepath);
        checkVars_setB(filepath);

        changeVars_setA2(filepath);
        checkVars_setA2(filepath);

    }

    function testSubsequentWrites() external {

        testSerializationAndDeserialization();

        string memory filepath = "/test/json_tests/testJson.json";

        storeVars_setC(filepath);
        checkVars_setC(filepath);

    }
}