// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "@forge-std/Script.sol";
import {CreatorHub} from "@contract/CreatorHub.sol";

contract DeployCreator is Script {
    function run() public returns (CreatorHub) {
        string memory rpc = vm.envString("RPC_URL");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address factory = vm.envAddress("FACTORY_ADDRESS");
        uint96 feePerDonation = uint96(vm.envUint("FEE_PER_DONATION"));

        vm.createFork(rpc);
        vm.startBroadcast(pk);

        // Create links array

        CreatorHub creator = new CreatorHub(msg.sender, feePerDonation, factory);

        vm.stopBroadcast();
        return creator;
    }

    function _split(string memory str, string memory delimiter) internal pure returns (string[] memory) {
        uint256 count = 1;
        for (uint256 i = 0; i < bytes(str).length; i++) {
            if (bytes(str)[i] == bytes(delimiter)[0]) count++;
        }

        string[] memory parts = new string[](count);
        uint256 start = 0;
        uint256 partIndex = 0;

        for (uint256 i = 0; i <= bytes(str).length; i++) {
            if (i == bytes(str).length || bytes(str)[i] == bytes(delimiter)[0]) {
                uint256 length = i - start;
                bytes memory part = new bytes(length);
                for (uint256 j = 0; j < length; j++) {
                    part[j] = bytes(str)[start + j];
                }
                parts[partIndex] = string(part);
                partIndex++;
                start = i + 1;
            }
        }

        return parts;
    }
}