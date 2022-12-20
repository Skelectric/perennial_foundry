// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "./util/CreatePayoffDefinition.sol";
import "./util/ReuseOrDeployProduct.sol";

import "../src/interfaces/IController.sol";
import "../src/interfaces/IProduct.sol";
import "../src/Squeeth.sol";
import "../src/types/Fixed18.sol";
import "../src/types/UFixed18.sol";
import "../src/types/PackedFixed18.sol";
import "../src/types/PackedUFixed18.sol";
import {JumpRateUtilizationCurve} from "../src/types/JumpRateUtilizationCurve.sol";


address constant PERENNIAL_CONTROLLER_PROXY_GOERLI = 0x7c4ABBF7CB0C0BcB72917734B068Ed4D1AcdF8C5;
address constant CHAINLINK_ETHUSD_GOERLI = 0x2c43Fd948eF2DAFaf41Ef6d6FCa3B62e957fb2a7;


contract DeploySqueeth is Script {
    error DeployerNotCoordinator(address deployer);

    IController iController;
    Squeeth squeeth;

    function run() external {
        uint256 coordinatorID = vm.envUint("COORDINATOR_ID");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.recordLogs();

        // network constants
        iController = IController(PERENNIAL_CONTROLLER_PROXY_GOERLI);
        console.log("using Controller at %s", address(iController));

        // check coordinator owner
        if (deployer != iController.owner(coordinatorID)) {
            revert DeployerNotCoordinator(deployer);
        }

        // squeeth contract payoff provider
        squeeth = new Squeeth();

        // squeeth product info
        // n ether = n * 1e18
        IProduct.ProductInfo memory productInfo = IProduct.ProductInfo({
            name: "milli-Squeeth",
            symbol: "mSQTH",
            payoffDefinition: CreatePayoffDefinition.create(address(squeeth), false),
            oracle: IOracleProvider(CHAINLINK_ETHUSD_GOERLI),
            maintenance: UFixed18.wrap(0.3 ether),
            fundingFee: UFixed18.wrap(0.1 ether),
            makerFee: UFixed18.wrap(0),
            takerFee: UFixed18.wrap(0),
            positionFee: UFixed18.wrap(0),
            makerLimit: UFixed18.wrap(2500 ether),
            utilizationCurve: JumpRateUtilizationCurve({
                minRate: PackedFixed18.wrap(0.04 ether),
                maxRate: PackedFixed18.wrap(16.25 ether),
                targetRate: PackedFixed18.wrap(1.56 ether),
                targetUtilization: PackedUFixed18.wrap(0.80 ether)
            })
        });

        ReuseOrDeployProduct.reuseOrDeploy(coordinatorID, iController, productInfo);


        // vm.startBroadcast(deployerPrivateKey);

        Vm.Log[] memory logs = vm.getRecordedLogs();


    }

}