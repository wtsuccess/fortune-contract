// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Fortune is Ownable, Pausable, VRFConsumerBaseV2 {
    using SafeERC20 for IERC20;

    enum DrawStatus {
        INITIAL,
        OPEN,
        CLOSING,
        CLOSED,
        EXPIRED
    }

    struct DistributionRate {
        uint256 first;
        uint256 second;
        uint256 third;
    }

    struct Draw {
        uint256 startTime;
        DrawStatus status;
        uint256 entryPrice;
        uint256 amount;
        address firstPlace;
        address secondPlace;
        address thirdPlace;
        DistributionRate distributionRate;
        uint256 hardcap;
        uint256 softcap;
        uint256 expiredTime;
    }

    uint256 public nextDrawId;

    IERC20 public entryToken;

    address treasurer;

    DistributionRate public distributionRate;

    VRFCoordinatorV2Interface COORDINATOR;

    uint64 public s_subscriptionId;
    bytes32 s_keyHash =
        0x17cd473250a9a479dc7f234c64332ed4bc8af9e8ded7556aa6e66d83da49f470;
    uint32 callbackGasLimit = 2_500_000;
    uint16 private constant requestConfirmations = 3;

    mapping(uint256 => Draw) public draws;

    mapping(uint256 => address[]) public participants;

    mapping(uint256 => mapping(address => uint256)) public winReward;

    mapping(address => mapping(uint256 => uint256))
        public addressToDrawToTickets; // Mapping to track user, draw ID, and tickets
    mapping(address => mapping(uint256 => uint256))
        public addressToDrawToTokens; // Mapping to track user, draw ID, and deposited tokens

    mapping(uint256 => bool) public isDistributed;
    mapping(address => mapping(uint256 => bool)) public isRefunded;

    mapping(uint256 => uint256) requestedDrawId;

    event NewDrawOpened(uint256 indexed drawId, uint256 entryPrice);
    event DrawCompleted(
        uint256 indexed drawId,
        address firstPlace,
        address secondPlace,
        address thirdPlace
    );
    event WinningClaimed(uint256 indexed drawId);
    event EnterDraw(uint256 indexed drawId, address participant, uint256 count);
    event Refunded(address participant, uint256 drawId);

    constructor(
        address _entryToken,
        address _vrfCoordinator
    ) Ownable() VRFConsumerBaseV2(_vrfCoordinator) {
        require(_entryToken != address(0), "invalid token");
        require(_vrfCoordinator != address(0), "invalid vrf");

        treasurer = msg.sender;
        nextDrawId = 1;

        entryToken = IERC20(_entryToken);
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
    }

    function enterMultiple(uint256 _drawId, uint256 _count) public {
        Draw storage draw = draws[_drawId];

        require(draw.status == DrawStatus.OPEN, "Draw Not Opend");

        entryToken.safeTransferFrom(
            msg.sender,
            address(this),
            draw.entryPrice * _count
        );

        draw.amount += draw.entryPrice * _count;

        uint256 count = _count + (_count / 10);

        for (uint256 i = 0; i < count; i++) {
            participants[_drawId].push(msg.sender);
        }

        addressToDrawToTickets[msg.sender][_drawId] = count;
        addressToDrawToTokens[msg.sender][_drawId] = draw.entryPrice * _count;

        if (draw.amount >= draw.hardcap) pickWinner(_drawId);

        emit EnterDraw(_drawId, msg.sender, _count);
    }

    function openNextDraw(
        uint256 _entryPrice,
        uint256 _hardcap,
        uint256 _softcap,
        uint256 _expiredTime
    ) external onlyOwner {
        require(_entryPrice > 0, "zero Error");
        require(_hardcap > _softcap && _softcap > 0, "Invalid");
        require(_expiredTime > 0, "Zero Error");

        uint256 drawId = nextDrawId;

        Draw memory draw = Draw({
            startTime: block.timestamp,
            status: DrawStatus.OPEN,
            entryPrice: _entryPrice,
            amount: 0,
            firstPlace: address(0),
            secondPlace: address(0),
            thirdPlace: address(0),
            distributionRate: distributionRate,
            hardcap: _hardcap,
            softcap: _softcap,
            expiredTime: _expiredTime
        });

        draws[drawId] = draw;
        nextDrawId++;

        emit NewDrawOpened(drawId, _entryPrice);
    }

    function pickWinner(uint256 _drawId) internal returns (uint256 requestId) {
        Draw storage draw = draws[_drawId];

        require(draw.status == DrawStatus.OPEN, "Draw Not Opened");

        draw.status = DrawStatus.CLOSING;

        requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            3
        );

        requestedDrawId[requestId] = _drawId;

        return requestId; //
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        uint256 drawId = requestedDrawId[_requestId];

        uint256 indexFirst;
        uint256 indexSecond;
        uint256 indexThird;
        address firstPlace;
        address secondPlace;
        address thirdPlace;
        uint256 numberOfParticipants = participants[drawId].length;

        draws[drawId].status = DrawStatus.CLOSED;

        if (numberOfParticipants > 0) {
            indexFirst = _randomWords[0] % numberOfParticipants;
            firstPlace = participants[drawId][indexFirst];
        }
        if (numberOfParticipants > 1) {
            indexSecond = _randomWords[1] % (numberOfParticipants - 1);
            if (indexSecond >= indexFirst) {
                indexSecond += 1;
            }
            secondPlace = participants[drawId][indexSecond];
        }
        if (numberOfParticipants > 2) {
            (uint256 index0, uint256 index1) = indexFirst < indexSecond
                ? (indexFirst, indexSecond)
                : (indexSecond, indexFirst);

            indexThird = _randomWords[2] % (numberOfParticipants - 2);
            if (indexThird >= index0) {
                indexThird += 1;
            }
            if (indexThird >= index1) {
                indexThird += 1;
            }
            thirdPlace = participants[drawId][indexThird];
        }

        draws[drawId].firstPlace = firstPlace;
        draws[drawId].secondPlace = secondPlace;
        draws[drawId].thirdPlace = thirdPlace;

        emit DrawCompleted(drawId, firstPlace, secondPlace, thirdPlace);
    }

    function distribute(uint256 _drawId) public {
        Draw memory draw = draws[_drawId];

        require(draw.status == DrawStatus.CLOSED, "Draw Not Completed");
        require(!isDistributed[_drawId], "Already Distributed");

        isDistributed[_drawId] = true;

        uint256 amountForFirst = (draw.amount * draw.distributionRate.first) /
            10000;
        uint256 amountForSecond = (draw.amount * draw.distributionRate.second) /
            10000;
        uint256 amountForThird = (draw.amount * draw.distributionRate.third) /
            10000;
        uint256 restAmount = draw.amount;

        if (amountForFirst > 0 && draw.firstPlace != address(0)) {
            entryToken.safeTransfer(draw.firstPlace, amountForFirst);
            restAmount -= amountForFirst;
        }

        if (amountForSecond > 0 && draw.secondPlace != address(0)) {
            entryToken.safeTransfer(draw.secondPlace, amountForSecond);
            restAmount -= amountForSecond;
        }

        if (amountForThird > 0 && draw.thirdPlace != address(0)) {
            entryToken.safeTransfer(draw.thirdPlace, amountForThird);
            restAmount -= amountForThird;
        }

        if (restAmount > 0) {
            entryToken.safeTransfer(treasurer, restAmount);
        }

        emit WinningClaimed(_drawId);
    }

    function setVRFCoordinator(address _vrf) external onlyOwner {
        require(_vrf != address(0), "invalid address");

        COORDINATOR = VRFCoordinatorV2Interface(_vrf);
    }

    function setSubscriptionData(
        bytes32 _keyHash,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) external onlyOwner {
        s_keyHash = _keyHash;
        s_subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;
    }

    function updateDistributionRate(
        uint256 _first,
        uint256 _second,
        uint256 _third
    ) external onlyOwner {
        require(_first + _second + _third <= 100, "exceed");

        distributionRate = DistributionRate({
            first: _first,
            second: _second,
            third: _third
        });
    }

    function setEntryToken(address _addr) external onlyOwner {
        require(_addr != address(0), "zero");
        entryToken = IERC20(_addr);
    }

    function getUserTicketsForDraw(
        address _address,
        uint256 _drawId
    ) public view returns (uint256) {
        return addressToDrawToTickets[_address][_drawId];
    }

    function refund(uint256 _drawId) public {
        Draw memory draw = draws[_drawId];

        require(
            draw.status == DrawStatus.OPEN &&
                block.timestamp > draw.startTime + draw.expiredTime &&
                draw.amount < draw.softcap,
            "Not Refund"
        );

        require(
            addressToDrawToTokens[msg.sender][_drawId] > 0,
            "You did not enter in draw"
        );
        require(!isRefunded[msg.sender][_drawId], "You Already Refunded");

        entryToken.safeTransferFrom(
            address(this),
            msg.sender,
            addressToDrawToTokens[msg.sender][_drawId]
        );
        isRefunded[msg.sender][_drawId] = true;
        emit Refunded(msg.sender, _drawId);
    }
}
