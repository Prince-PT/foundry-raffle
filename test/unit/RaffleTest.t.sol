//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console, console2} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {VRFCoordinatorV2_5} from "@chainlink/contracts/v0.8/vrf/dev/VRFCoordinatorV2_5.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public STARTING_PLAYER_BALANCE = 1000 ether;

    event RaffleEntered(address indexed player);
    event winnerPicked(address indexed winner);

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaflleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address platerRecorded = raffle.getPlayer(0);
        assert(platerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, true, address(raffle));
        emit RaffleEntered(PLAYER);
        // Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    //To test out the events we have to copy and paste the events in the test file as events are not accessible in the test file as of now
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating()
        public
        raffleEntered
    {
        raffle.performUpkeep("");

        //Act
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //Assert
    }

    //CHECK UPKEEP
    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfItHasNoPlayers() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen()
        public
        raffleEntered
    {
        raffle.performUpkeep("");
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    //CHallenge
    function testCheckUpKeepReturnsFalseIfEnoughTimeHasPassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood()
        public
        raffleEntered
    {
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // Assert
        assert(upkeepNeeded);
    }

    // PERFORM UPKEEP TESTS
    function testPerformUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act /assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rstate = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers += 1;

        vm.warp(block.timestamp + interval - 1);

        //Act /assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rstate
            )
        );

        raffle.performUpkeep("");
    }

    // What if we need to get the data from emmitted events in our tests?
    // We can't do that as of now, so we have to copy and paste the events in the test file

    function testPerformUpkeepUpdatesRaffleStateAndEmitRequestId()
        public
        raffleEntered
    {
        //Act
        vm.recordLogs(); //Keep a track of all the logs and events performed by the performUpkeep function into an array.
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // The first log of Index 0 is going to be emitted by the vrfCoordinator so we take index 1. And we are using topic[1] instead of topic[0] because The 0th index (topics[0]) is always the event signature hash, which is a keccak256 hash of the event signature
        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    //Test to FullFill Randomn Words

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEntered {
        //Arrange/act/assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );

        // Here we hardcoded it and checked this fulfillRandomWords at index 0, but this is not so good practice, we should check it dynamically and here comes the concept of StateLess Fuzz Testing
    }

    // function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
    //     public
    //     raffleEntered
    // {
    //     //Arrange
    //     uint256 additionalEntrants = 3; // 4 total
    //     uint256 startingIndex = 1;
    //     address expectedWinner = address(1);

    //     for (
    //         uint256 i = startingIndex;
    //         i < startingIndex + additionalEntrants;
    //         i++
    //     ) {
    //         address newPlayer = address(uint160(i));
    //         hoax(newPlayer, 1 ether);
    //         raffle.enterRaffle{value: entranceFee}();
    //     }
    //     uint256 startingTimeStamps = raffle.getLastTimeStamp();
    //     uint256 winnerStartingBalance = expectedWinner.balance;
    //     //Act
    //     vm.recordLogs(); //Keep a track of all the logs and events performed by the performUpkeep function into an array.
    //     raffle.performUpkeep("");
    //     Vm.Log[] memory entries = vm.getRecordedLogs();
    //     bytes32 requestId = entries[1].topics[1];
    //     console.log("Request ID:", uint256(requestId));
    //     VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
    //         uint256(requestId),
    //         address(raffle)
    //     );
    //     //Assert
    //     address recentWinner = raffle.getRecentWinner();
    //     Raffle.RaffleState raffleState = raffle.getRaffleState();
    //     uint256 winnerBalance = recentWinner.balance;
    //     uint256 prize = entranceFee * (additionalEntrants + 1);

    //     assert(recentWinner == expectedWinner);
    //     assert(uint256(raffleState) == 0);
    //     assert(winnerBalance == winnerStartingBalance + prize);
    //     assert(raffle.getLastTimeStamp() > startingTimeStamps);
    // }
}
