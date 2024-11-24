// HelperConfig.s.sol
// Purpose:
// This file provides configuration details for various blockchain networks. It acts as a central hub for environment-specific variables that are used in deployment and testing scripts.

// Key Components:

// Network-Based Configurations:
// For example, on Sepolia, the VRF Coordinator address might differ from a local Anvil instance or the mainnet.
// Contains network-specific values like gas limits, subscription IDs, and oracle configurations.
// Reusability: Allows the developer to switch networks by modifying one file rather than updating multiple scripts or files.
// Dynamic Values: May generate or retrieve on-the-fly configurations for local setups (like creating a mock VRF).
// How They Work Together (Deploy Raffle Script and Helper Config)
// HelperConfig.s.sol supplies the necessary configuration data to DeployRaffle.s.sol. For example:
// On Sepolia, HelperConfig.s.sol provides the address of the Chainlink VRF Coordinator, and DeployRaffle.s.sol uses it during deployment.
// For a local network, HelperConfig.s.sol may include or deploy a mock VRF contract, and DeployRaffle.s.sol integrates with that mock setup.
// By separating these concerns, the code becomes modular, making it easier to maintain, extend, and test in different environments.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    // VRF Coordinator Mock Values //
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE = 1e9;
    //LINK / ETH PRICE
    int256 public MOCK_WEI_PER_UNIT_LINK = 4e16;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig; // Public variable to hold the network configuration
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30, // 30 seconds
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 73844590328363685127854103365298973163881372132530498354368679010039736095269,
            callbackGasLimit: 500000, // 500k
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x188A278f1E94B3Fb39Df76E07421F17cb9092A8d
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, MOCK_WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30, // 30 seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000, // 500k
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localNetworkConfig;
    }
}
