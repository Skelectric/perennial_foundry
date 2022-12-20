// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "../../src/types/PayoffDefinition.sol";

library CreatePayoffDefinition {

    function create(address contractAddress, bool short) external pure returns (PayoffDefinition memory definition) {

        definition = PayoffDefinition({
            payoffType: PayoffDefinitionLib.PayoffType.PASSTHROUGH,
            payoffDirection: PayoffDefinitionLib.PayoffDirection.LONG,
            data: bytes30(0)
        });

        if (short) {
            definition.payoffDirection = PayoffDefinitionLib.PayoffDirection.SHORT;
        }

        if (contractAddress != address(0)) {
            definition.payoffType = PayoffDefinitionLib.PayoffType.CONTRACT;
            definition.data = toBytes30(contractAddress);
        }
    }

    function toBytes30(address addr) internal pure returns (bytes30) {
        return bytes30(bytes20(addr)) >> 80;
    }
}