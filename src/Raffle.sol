// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/*//////////////////////////////////////////////////////////////
                                IMPORTS
    //////////////////////////////////////////////////////////////*/
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * // (Slash, asterisk, asterisk for natspec comments)
 * @title Raffle
 * @author Hammad Iftikhar
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2.5
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Raffle__SendMoreToEnterRaffle(); // Errors can be capitalized
    // We can even go further and make them a custom error and define a parameter for it, it can be anything we want. Like I have done, gas efficient? No idea. But passing a parameter requires us to pass error names, and in the require function, it takes two parameters, which becomes directly equal, e.g., requiredAmount and sentAmount are equal to i_entranceFee, msg.value in the if function.
    // error Raffle__SendMoreToEnterRaffle(
    // uint256 requiredAmount,
    // uint256 sentAmount
    //  if (msg.value < i_entranceFee) {
    // revert Raffle__SendMoreToEnterRaffle(i_entranceFee, msg.value);
    // }
    // Updated to use a version with no parameters because it uses more gas.
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    enum RaffleState {
        OPEN, //0
        CALCULATING //1

    }

    /*//////////////////////////////////////////////////////////////
               STATE VARIABLES - CHAINLINK VRF VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /*//////////////////////////////////////////////////////////////
                           LOTTERY VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private immutable i_entranceFee; //@dev: The duration of the lottery in seconds.
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    // Every time we need to update storage, the rule of thumb is we need to emit an event.
    // 1. Event

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    // Constructor is a special function in Solidity. Whatever we put in it will be executed first and also prompted first. In this case, the constructor is asking for the user to pay first.
    // constructor(uint256 i_entranceFee) {
    // this.i_entranceFee = i_entranceFee; // this is also correct, serves the same purpose to create a new instance locally.
    // }
    // Temporary Local Variable for Calculations:
    // To remember
    // When you need to use or modify a state variable inside a function, it’s often more gas-efficient to work with a local copy. Perform calculations using this temporary local variable, and then, at the end, save the result back into the state variable if needed. This approach minimizes unnecessary access to the storage (state) variable, which can be costly in terms of gas.
    // Constructor Usage:
    // For constructors, if you need to initialize multiple values, using temporary variables can make complex initialization logic easier to read. However, constructors only run once and don’t need to be optimized for gas in the same way regular functions do.
    // Question: Does immutable values has to be passed as constructor always?
    // Answer: Yes, an immutable variable in Solidity must be initialized once, and this can only happen either:
    // Directly in the constructor (as in the case of i_entranceFee in your example)
    // At the point of declaration (when you define the variable).
    // // This is because immutable variables are set only once and are not intended to change after contract deployment, similar to constant values, but they allow more flexibility as they can be initialized dynamically.
    // Wehnever you inherit a contract,and it has constructor you as well pass that constructor in your contract constructor as well.

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane, //keyhash
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        i_subscriptionId = subscriptionId;
        s_lastTimeStamp = block.timestamp; // start the clock.
        s_raffleState = RaffleState.OPEN;
    }

    /*//////////////////////////////////////////////////////////////
                         1. ENTER RAFFLE FUNCTION
    //////////////////////////////////////////////////////////////*/
    function enterRaffle() external payable {
        // 1. require(msg.value >= i_entranceFee, "Raffle__NotEnoughEth"); // not gas efficient - old style
        // 2. require(msg.value >= i_entranceFee, SendMoreToEnterRaffle()); // new style but we are using an older version of Solidity. This came in 0.8.26 and is also less gas efficient than what we are using.
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        // 2. emit (Event --> Emit)
        emit RaffleEntered(msg.sender);
    }

    // When should the winner be picked?
    /**
     * @dev This is the function that the Chainlink nodes will call to see
     * if the lottery is ready to have a winner picked.
     * The following should be true in order for this upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH. / Has Players.
     * 4. Implicitly, your subscription has Link.
     * @param -ignored
     * @return upkeepNeeded - true if it's time to restart the lottery.
     * @return -ignored
     */

    /*//////////////////////////////////////////////////////////////
                             CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/
    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    /*//////////////////////////////////////////////////////////////
        2. PICK WINNER FUNCTION CHANGED TO PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/
    // For my Knowledge: Either we use enough time has based lottery or enough people are in that lottery both has pros and cons, but this is time-based.
    // 1. Get a random number.
    // 2. Use random number to pick a winner.
    // 3. Be automatically called.
    function performUpkeep(bytes calldata /*performData*/ ) external {
        // We need to see if enough has passed since that is time based lottery.
        // 1000 - 900 = 100, and interval is 50, so 100 > 50. lets start the lottery.
        // current time - last time stamp > interval.
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_gasLane,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, //requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN; //this will reopen the raffle after picking the winner
        s_lastTimeStamp = block.timestamp;
        s_players = new address payable[](0); //this will clear the players array after picking the winner
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(s_recentWinner);

        //         As a concept, this line:

        // Sends the entire Ether balance of the contract to the recentWinner address.
        // Uses the low-level .call function to perform the transfer, which is safer in terms of gas costs compared to .transfer.
        // Checks whether the transfer was successful by capturing the success boolean.
        // Why This Pattern?
        // This pattern is common in lottery or prize distribution contracts:
        // After selecting a winner (e.g., recentWinner), the contract sends them the entire prize pool (all Ether held by the contract).
        // Checking the success return value ensures the contract knows if the transfer was successful, which can help prevent failures silently.
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
