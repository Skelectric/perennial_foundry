// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/console.sol";

import "../../src/interfaces/IController.sol";
import "../../src/interfaces/IProduct.sol";

import "./stdJsonDB.sol";

address constant deployedAddress = address(0);

library ReuseOrDeployProduct {

    function reuseOrDeploy(
        uint coordinatorID, 
        IController controller, 
        IProduct.ProductInfo memory productInfo
    ) external {

        string memory deploymentName = string.concat("Product_", productInfo.symbol);



        if (deployedAddress == address(0)) {
            
            console.log("Creating %s...", deploymentName);
            
            IProduct product = controller.createProduct(coordinatorID, productInfo);

            console.log("Created at %s", address(product));

        } else {

            console.log("Reusing %s at %s", deploymentName, deployedAddress);

        }

    }

}