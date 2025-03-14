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

//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle Contract
 * @author Prince Thakkar
 * @notice This contract is used to create a raffle system.
 * @dev Implenets Chainlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );

    // Type Declaration
    enum RaffleState {
        OPEN, // 0
        CALCULATING_WINNER // 1
    }
    // State Variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev The interval at which the raffle will be held in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /*Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequstedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane, //keyyHash
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN; // RaffkeState.OPEN = RafleState(0)
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent!");
        // require(msg.value >= i_entranceFee,SendMoreToEnterRaffle()); // We Can't use this as of now as we are using Solidity 0.8.19
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender); // Anytime we update a state variable, we should emit an event
    }

    // When should the winner be picked?
    /**
     *
     * @dev This is the function that the Chainlink nodes will call to see
     * if the lottery is ready to have a winner picked.
     * the following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between the last raffle and now
     * 2. The raffle state is OPEN
     * 3. The contract has ETH
     * 4. The subscription has LINK
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the raffle
     * @return bytes - ignored
     */
    function checkUpKeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    // 1. Get a random number
    // 2. Use that random number to pick a winner
    // 3. Be automatically called
    // 4. Transfer the money to the winner

    function performUpkeep(bytes calldata) external {
        //Check to see if enough time has passed
        (bool upkeepNeeded, ) = checkUpKeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING_WINNER;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
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
        emit RequstedRaffleWinner(requestId); // This is redundant as we are emitting the event here but the chainlink also emits this requestId in vrfCoordinatorV2_Mock

        // Get a random number
    }

    // CEI : Check-Effect-Interaction
    // This is a design pattern that is used to write secure smart contracts
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal virtual override {
        //Checks

        // Use that random number to pick a winner
        //Lets say there are 10 players
        // and lets say the random number generated is 12
        // so 12 % 10 = 2 and the player at index 2 will be the winner

        //Effects(Internal Contract State Changes)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN; // Reset the raffle
        s_players = new address payable[](0); // reset the players array
        s_lastTimeStamp = block.timestamp; // reset the timestamp for the next raffle to start in i_interval seconds
        emit WinnerPicked(s_recentWinner);
        //Interactions
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    //Getter Function
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    // function getRecentWinner() external view returns (address) {
    //     return s_recentWinner();
    // }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
