// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

// import "./util/stdJsonDB.sol";

import "../src/interfaces/IController.sol";
import "../src/interfaces/IProduct.sol";
import "../src/interfaces/IContractPayoffProvider.sol";

import "../src/types/Fixed18.sol";
import "../src/types/UFixed18.sol";
import "../src/types/PackedFixed18.sol";
import "../src/types/PackedUFixed18.sol";
import {JumpRateUtilizationCurve} from "../src/types/JumpRateUtilizationCurve.sol";

// @author: Skelectric
// -------------------------------------------Perennial Product Deployment Steps-------------------------------------------
//
// 1. Ensure that the Perennial controller and chainlink oracle addresses are accurate
//
// 2. Determine whether your product needs a payoff provider.
//
//      - Your product DOES NOT need a payoff provider if the oracle, by itself, is enough to determine payoff.
//          - If so, comment-out the call to reuseOrDeployPayoffProvider().
//
//      - Your product DOES need a payoff provider if additional transformations are needed on top of the price
//        provided by the oracle.
//          - If so, define the payoff provider in a separate contract that inherits from IPayoffContractProvider
//
// 3. Finalize the product info parameters, including the jump rate curve parameters and payoff definition direction
//
// 4. Ensure that the following environment vars are loaded into memory:
//
//      - PRIVATE_KEY (required)
//      - RPC_URL (required)
//
//      - COORDINATOR_ID (optional)
//          - If the COORDINATOR_ID is not supplied, this script will call the Controller and generate a new one and add
//            it to the deployment_info json file.
//
//
// 5. If using contracts that have already been deployed (such as when updating market parameters), 
//      populate the script/deployment_info.json with the contract addresses for payoff provider and product
//      as below. Note that the substring after the '_' should be the product info NAME:
//
//          {
//              "Product_skellySqueeth3": "0x3E9e53FD1915dEBE0ee8E4297570c023d24FA4FA",
//              "PayoffProvider_skellySqueeth3": "0xc26ce2318995AF1A657C7d8750d5BA5FaAC9f3bb",
//              "COORDINATOR_ID": 1337
//          }
//  
//
// 6. In the terminal, run the following command (adjust for OS, below command is for Windows Powershell):
//
//      forge script script/Squeeth.s.sol:Deploy --rpc-url=$env:RPC_URL --private-key=$env:PRIVATE_KEY --slow -vv
// 
// 7. If simulation is successful, add `--broadcast --skip-simulation --verify` to the same command and rerun. 
// 
//---------------------------------------------------------------------------------------------------------------
//
// Script TODO Items, Limitations
//
//  - This script currently does nothing if coordinator ID and addresses for payoff provider and product are provided.
//      Plan to add functionality to update product parameters?
//
//  - If any of the keys in the deployment_info are missing, the script will fail. This is because vm.parseJson() does not 
//      revert if a key is a missing and abi.decode() cannot be used in a try-catch pattern. Need to investigate this
//      further for a workaround.
//
//  - Foundry's support for libaries within scripts is currently bugged, so convenience methods cannot be refactored into 
//      other files until the issue is resolved: https://github.com/foundry-rs/foundry/issues/3924
//
//  - Foundry's forge scripting does not yet offer a way to adjust operations based on whether the script is running
//      through a simulation, or through the final broadcast. This limitation results in simulations creating a 
//      a deploymentInfo.json file that interferes with the final broadcast. Until this feature is added, the workaround
//      is to comment-out the saveInfo() call unless the `--skip-simulation` flag is included in the final run.
//
//  - vm.writeFile() can create a file if it doesn't yet exist, but it cannot recursively create a directory. 
//      Investigate using vm.ffi() as a workaround. 
//


address constant PERENNIAL_CONTROLLER_PROXY_GOERLI = 0x7c4ABBF7CB0C0BcB72917734B068Ed4D1AcdF8C5;
address constant CHAINLINK_ETHUSD_GOERLI = 0x2c43Fd948eF2DAFaf41Ef6d6FCa3B62e957fb2a7;

// ---------------- PRODUCT INFO --------------------
// n ether = n * 1e18
string constant NAME = "skellySqueeth3";
string constant SYMBOL = "skSQTH3";
uint256 constant MAINTENANCE = 0.3 ether;
uint256 constant FUNDING_FEE = 0.1 ether;
uint256 constant MAKER_FEE = 0 ether;
uint256 constant TAKER_FEE = 0 ether;
uint256 constant POSITION_FEE = 0 ether;
uint256 constant MAKER_LIMIT = 2500 ether;
// jump rate utilization curve parameters
int128 constant MIN_RATE = 0.04 ether;
int128 constant MAX_RATE = 16.25 ether;
int128 constant TARGET_RATE = 1.56 ether;
uint128 constant TARGET_UTILIZATION = 0.80 ether;
// payoff definition 
bool constant SHORT = false;

// ---------------------------------------------------

// deployment info
// string constant deploymentInfo = "deployment_info.json";


contract Deploy is Script {

    // error DeployerNotCoordinator(address deployerAddr);

    IController iController = IController(PERENNIAL_CONTROLLER_PROXY_GOERLI);

    string deploymentInfo = "deployment_info.json";

    address deployerAddr;
    uint256 deployerPrivateKey;
    uint256 coordinatorID;

    address payoffProviderAddr;
    address productAddr;

    IProduct.ProductInfo productInfo;

    bool _new = false;

    function run() external {

        // vm.recordLogs();

        deriveInfoFilepath();

        console.log("Using Controller at %s", address(iController));
        
        loadDeployer();
        
        getCoordinatorID();

        reuseOrDeployPayoffProvider();  // comment-out for products that do not need a payoff provider

        buildProductInfo();

        reuseOrDeployProduct();

        // comment-out unless deploying with --broadcast --skip-simulation flags, or testing
        saveInfo(); 

        // Vm.Log[] memory logs = vm.getRecordedLogs();

    }

    function loadDeployer() internal {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployerAddr = vm.addr(deployerPrivateKey);
        console.log("Deploying from %s", deployerAddr);
    }

    function getCoordinatorID() internal {

        // attempt to retrieve coordinatorID from environment vars
        try vm.envUint("COORDINATOR_ID") returns (uint _coordinatorID) {
            coordinatorID = _coordinatorID;

            // check coordinator owner
            if (deployerAddr != iController.owner(coordinatorID)) {
                console.log("Owner(coordinatorID) != deployerAddr. Making new coordinator...");
                makeNewCoordinatorID();
            }

        } catch {

            // attempt to retrieve coordinatorID from json file
            // Replace with convenience function after Foundry Issue #3924 is resolved: https://github.com/foundry-rs/foundry/issues/3924 
            try vm.readFile(toAbsolutePath(deploymentInfo)) returns (string memory json) {

                try vm.parseJson(json, "COORDINATOR_ID") returns (bytes memory coordinatorIDRaw) {
                    coordinatorID = abi.decode(coordinatorIDRaw, (uint));
                } catch {
                    makeNewCoordinatorID();
                }

            } catch {
                console.log("COORDINATOR_ID not found in env vars or '%s'.", deploymentInfo);
                makeNewCoordinatorID();
            }

        }
        address coordinatorIDOwner = iController.owner(coordinatorID);
        console.log("Using Coordinator ID %s for deployment, with owner %s", coordinatorID, coordinatorIDOwner);

        require(coordinatorIDOwner == deployerAddr, "deployer != coordinatorID owner");
    }

    function makeNewCoordinatorID() internal {
        console.log("Retreiving new coordinator ID from controller...");
        vm.startBroadcast(deployerPrivateKey);
        coordinatorID = iController.createCoordinator();
        vm.stopBroadcast();
        _new = true;
    }

    function reuseOrDeployPayoffProvider() internal {

        string memory payoffProviderName = string.concat("PayoffProvider_", NAME);

        // Replace with convenience function after Foundry Issue #3924 is resolved: https://github.com/foundry-rs/foundry/issues/3924
        // try stdJsonDB.getAddr(payoffProviderName, deploymentInfo) returns (address deployedAddr) {
        try vm.readFile(toAbsolutePath(deploymentInfo)) returns (string memory json) {

            try vm.parseJson(json, payoffProviderName) returns (bytes memory payoffProviderAddrRaw) {
                payoffProviderAddr = abi.decode(payoffProviderAddrRaw, (address));                
                console.log("Reusing %s at %s", payoffProviderName, payoffProviderAddr);
            } catch {
                deployNewPayoffProvider();
            }

        } catch {
            deployNewPayoffProvider();
        }
    }

    function deployNewPayoffProvider() internal {
        PayoffProvider payoffProvider;

        vm.startBroadcast(deployerPrivateKey);
        payoffProvider = new PayoffProvider();
        vm.stopBroadcast();

        payoffProviderAddr = address(payoffProvider);

        console.log("Deployed %s to %s", string.concat("PayoffProvider_", NAME), payoffProviderAddr);

        _new = true;
    }

    function buildProductInfo() internal {
        productInfo = IProduct.ProductInfo({
            name: NAME,
            symbol: SYMBOL,
            payoffDefinition: createPayoffDefinition(payoffProviderAddr, SHORT),
            oracle: IOracleProvider(CHAINLINK_ETHUSD_GOERLI),
            maintenance: UFixed18.wrap(MAINTENANCE),
            fundingFee: UFixed18.wrap(FUNDING_FEE),
            makerFee: UFixed18.wrap(MAKER_FEE),
            takerFee: UFixed18.wrap(TAKER_FEE),
            positionFee: UFixed18.wrap(POSITION_FEE),
            makerLimit: UFixed18.wrap(MAKER_LIMIT),
            utilizationCurve: JumpRateUtilizationCurve({
                minRate: PackedFixed18.wrap(MIN_RATE),
                maxRate: PackedFixed18.wrap(MAX_RATE),
                targetRate: PackedFixed18.wrap(TARGET_RATE),
                targetUtilization: PackedUFixed18.wrap(TARGET_UTILIZATION)
            })
        });
    }

    function reuseOrDeployProduct() internal {

        string memory productName = string.concat("Product_", productInfo.name);

        // Replace with convenience function after Foundry Issue #3924 is resolved: https://github.com/foundry-rs/foundry/issues/3924
        // try stdJsonDB.getAddr(productName, deploymentInfo) returns (address productAddress) {
        try vm.readFile(toAbsolutePath(deploymentInfo)) returns (string memory json) {
            
            try vm.parseJson(json, productName) returns (bytes memory productAddressRaw) {
                productAddr = abi.decode(productAddressRaw, (address));                
                console.log("Reusing %s at %s", productName, productAddr);
            } catch {
                deployNewProduct();
            }

        } catch {
            deployNewProduct();
        }
    }

    function deployNewProduct() internal {

        vm.startBroadcast(deployerPrivateKey);
        IProduct product = iController.createProduct(coordinatorID, productInfo);
        vm.stopBroadcast();

        productAddr = address(product);
        console.log("Deployed %s to %s", string.concat("Product_", productInfo.name), productAddr);

        _new = true;
    }

    function deriveInfoFilepath() internal {
        deploymentInfo = string.concat("/script/", NAME, "_", deploymentInfo);
    }

    function saveInfo() internal {
        // Replace with convenience function after Foundry Issue #3924 is resolved: https://github.com/foundry-rs/foundry/issues/3924
        // stdJsonDB.set(productName, address(product), deploymentInfo);
        //
        // uncomment set() call only if using --skip-simulation flag
        // to-do: after foundry adds method to differentiate between different runtime environments,
        // add condition that only calls set() during broadcasts
        // (https://github.com/foundry-rs/foundry/issues/3928)

        if (_new) {
            set("COORDINATOR_ID", coordinatorID, deploymentInfo);
            set(string.concat("Product_", productInfo.name), productAddr, deploymentInfo);
            set(string.concat("PayoffProvider_", productInfo.name), payoffProviderAddr, deploymentInfo);
        } else {
            console.log("No changes.");
        }
    }

    function createPayoffDefinition(address contractAddress, bool short) internal pure returns (PayoffDefinition memory definition) {

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

    // Pasting in stdJsonDB convenience functions until Foundry Issue #3924 is resolved
    // https://github.com/foundry-rs/foundry/issues/3924

    function toAbsolutePath(string memory rel_path) internal view returns (string memory) {
        return string.concat(vm.projectRoot(), rel_path);
    }

    /// @dev adds serialized json string to file specified by relative_filepath
    /// @dev and creates file if it doesn't already exist
    function set(string memory json, string memory path) public {
        string memory abs_path = toAbsolutePath(path);

        try vm.readFile(abs_path) {
            stdJson.write(json, abs_path);
        } catch {
            vm.writeFile(abs_path, "");
            stdJson.write(json, abs_path);
        }
    
    }

    function set(string memory key, address value, string memory path) public {
        string memory json = stdJson.serialize("", key, value);
        set(json, path);
    }

    function set(string memory key, uint value, string memory path) public {
        string memory json = stdJson.serialize("", key, value);
        set(json, path);
    }

}

contract PayoffProvider is IContractPayoffProvider {

    function payoff(Fixed18 price) external pure override returns (Fixed18) {
        return price.mul(price).div(Fixed18Lib.from(1000));
    }
}