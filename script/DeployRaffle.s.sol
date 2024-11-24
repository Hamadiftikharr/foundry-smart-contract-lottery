// DeployRaffle.s.sol
// Purpose:
// This script is responsible for deploying the Raffle contract (or similar) onto a blockchain network. It automates the deployment process, ensuring the correct parameters are passed to the contract and managing deployment steps for different environments (e.g., local, testnets, or mainnet).

// Key Components:

// Constructor Arguments: Sets the required parameters for initializing the Raffle contract (e.g., entrance fee, interval, VRF parameters).
// Network Specifics: Uses helper configurations to adapt deployment settings (e.g., VRF Coordinator address, subscription ID) based on the target network.
// Automation: Removes the need for manual deployment, enabling reproducibility and avoiding human error.
// How They Work Together (Deploy Raffle Script and Helper Config)
// HelperConfig.s.sol supplies the necessary configuration data to DeployRaffle.s.sol. For example:
// On Sepolia, HelperConfig.s.sol provides the address of the Chainlink VRF Coordinator, and DeployRaffle.s.sol uses it during deployment.
// For a local network, HelperConfig.s.sol may include or deploy a mock VRF contract, and DeployRaffle.s.sol integrates with that mock setup.
// By separating these concerns, the code becomes modular, making it easier to maintain, extend, and test in different environments.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        //local->deploy mocks and then get local network
        //sepolia->get sepolia config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            //createsubscription
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscription.createSubscription(config.vrfCoordinator, config.account);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer(); //no need to broadcat cause its been used already in function.
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account);

        return (raffle, helperConfig);
    }
}
