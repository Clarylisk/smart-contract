// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "@forge-std/Script.sol";
import {CreatorHubFactory} from "@contract/CreatorHubFactory.sol";

contract DeployCreatorHubFactory is Script {
    function run() public returns (CreatorHubFactory) {
        uint96 processingFee = uint96(vm.envUint("PROCESSING_FEE"));
        
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        CreatorHubFactory factory = new CreatorHubFactory(processingFee);
        vm.stopBroadcast();

        // Auto-verify contract on Etherscan
        vm.writeFile(".env", string(abi.encodePacked("FACTORY_ADDRESS=", vm.toString(address(factory)))));
        return factory;
    }
}
