// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "./util/stdJsonDB.sol";

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

    string constant deployments = "/script/deployments.json";

    uint256 coordinatorID;
    uint256 deployerPrivateKey;
    
    address deployer;

    function run() external {
        coordinatorID = vm.envUint("COORDINATOR_ID");
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        vm.recordLogs();

        // network constants
        iController = IController(PERENNIAL_CONTROLLER_PROXY_GOERLI);
        console.log("using Controller at %s", address(iController));

        // check coordinator owner
        if (deployer != iController.owner(coordinatorID)) {
            revert DeployerNotCoordinator(deployer);
        }

        // squeeth contract payoff provider
        try stdJsonDB.getAddr("ContractPayoffProvider_Squeeth", deployments) returns (address deployedAddr) {
            squeeth = Squeeth(deployedAddr);
            console.log("Using payoff provider at %s", address(squeeth));
        } catch {
            
            vm.startBroadcast(deployerPrivateKey);
            squeeth = new Squeeth();
            vm.stopBroadcast();

            console.log("Deployed new payoff provider to %s", address(squeeth));

            // uncomment only if skipping simulation
            // stdJsonDB.set("ContractPayoffProvider_Squeeth", address(squeeth), deployments);

        }

        // squeeth product info
        // n ether = n * 1e18
        IProduct.ProductInfo memory productInfo = IProduct.ProductInfo({
            name: "skelly-Squeeth2",
            symbol: "skSQTH2",
            payoffDefinition: createPayoffDefinition(address(squeeth), false),
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

        reuseOrDeploy(iController, productInfo);

        // Vm.Log[] memory logs = vm.getRecordedLogs();

    }

    function reuseOrDeploy(IController controller, IProduct.ProductInfo memory productInfo) internal {

        string memory deploymentName = string.concat("Product_", productInfo.symbol);

        try stdJsonDB.getAddr(deploymentName, deployments) returns (address productAddress) {
            console.log("Reusing %s at %s", deploymentName, productAddress);
        } catch {
            console.log("Creating %s...", deploymentName);

            vm.startBroadcast(deployerPrivateKey);
            (bool success, bytes memory data) = address(controller).call(
                abi.encodeCall(IController.createProduct, (coordinatorID, productInfo))
            );
            vm.stopBroadcast();

            require(success, "createProduct() failed");

            (address productAddr) = abi.decode(data, (address));
            IProduct product = IProduct(productAddr);

            console.log("Created at %s", address(product));

            // uncomment only if skipping simulation
            // stdJsonDB.set(deploymentName, address(product), deployments);
        }
    }

    function createPayoffDefinition(address contractAddress, bool short) 
        internal pure returns (PayoffDefinition memory definition) 
    {

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