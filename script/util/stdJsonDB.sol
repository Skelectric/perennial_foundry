// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/StdJson.sol";
import "forge-std/Vm.sol";

/// @dev Convenience functions for storing/retrieving variables to/from a local JSON file easily
library stdJsonDB {

    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm internal constant vm = Vm(VM_ADDRESS);

    // keeping this blank maintains a single json mapping on writes
    string constant jsonkey = "";

    function toAbsolutePath(string memory rel_path) internal view returns (string memory) {
        return string.concat(vm.projectRoot(), rel_path);
    }

    /// @dev adds serialized json string to file specified by relative_filepath
    /// @dev creates file if it doesn't already exist
    function set(string memory json, string memory path) public {
        string memory abs_path = toAbsolutePath(path);

        try vm.readFile(abs_path) {
            stdJson.write(json, abs_path);
        } catch {
            vm.writeFile(abs_path, ""); // creates file if it doesn't already exist
            stdJson.write(json, abs_path);
        }
    
    }

    // todo: add more types

    function set(string memory key, address value, string memory path) public {
        string memory json = stdJson.serialize(jsonkey, key, value);
        set(json, path);
    }

    function set(string memory key, uint value, string memory path) public {
        string memory json = stdJson.serialize(jsonkey, key, value);
        set(json, path);
    }

    function set(string memory key, string memory value, string memory path) public {
        string memory json = stdJson.serialize(jsonkey, key, value);
        set(json, path);
    }

    function set(string memory key, bool value, string memory path) public {
        string memory json = stdJson.serialize(jsonkey, key, value);
        set(json, path);
    }

    /// @dev retrieves value, in bytes, of key-value pair from json file specified by rel_path
    function get(string memory key, string memory path) public view returns (bytes memory) {
        string memory abs_path = toAbsolutePath(path);
        string memory json = vm.readFile(abs_path);
        return stdJson.parseRaw(json, key);
    }

    // todo: add more types

    function getAddr(string memory key, string memory path) public view returns (address) {
        return abi.decode(get(key, path), (address));
    }

    function getUint(string memory key, string memory path) public view returns (uint) {
        return abi.decode(get(key, path), (uint));
    }

    function getString(string memory key, string memory path) public view returns (string memory) {
        return abi.decode(get(key, path), (string));
    }

    function getBool(string memory key, string memory path) public view returns (bool) {
        return abi.decode(get(key, path), (bool));
    }

}