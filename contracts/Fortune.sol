// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

contract Fortune is Pausable, VRFConsumerBaseV2Plus {
    using SafeERC20 for IERC20;

    enum DrawStatus {
        INITIAL,
        OPEN,
        CLOSING,
        CLOSED
    }

    struct DistributionRate {
        uint256 first;
        uint256 second;
        uint256 third;
    }

    struct Draw {
        uint256 startTime;
        DrawStatus status;
        uint256 price;
        uint256 usdcAmount;
        uint256 usdceAmount;
        address firstPlace;
        address secondPlace;
        address thirdPlace;
        DistributionRate distributionRate;
        uint256 hardcap;
        uint256 softcap;
        uint256 expiredTime;
    }

    IERC20 public usdc;
    IERC20 public usdce;

    DistributionRate public distributionRate;
    IVRFCoordinatorV2Plus COORDINATOR;

    address public treasurer;

    uint256 public nextDrawId;
    uint256 public s_subscriptionId;
    // bytes32 s_keyHash =
    //     0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae; // sepolia key hash
    bytes32 s_keyHash =
        0x0ffbbd0c1c18c0263dd778dadd1d64240d7bc338d95fec1cf0473928ca7eaf9e; // polygon mainnet key hash
    uint32 callbackGasLimit = 2_500_000;
    uint16 private constant requestConfirmations = 3;

    mapping(uint256 => Draw) public draws;
    mapping(uint256 => address[]) public participants;
    mapping(address => mapping(uint256 => uint256))
        public addressToDrawToTickets;
    mapping(address => mapping(uint256 => uint256)) public addressToDrawToUSDC;
    mapping(address => mapping(uint256 => uint256)) public addressToDrawToUSDCe;

    mapping(uint256 => bool) public isDistributed;
    mapping(address => mapping(uint256 => bool)) public isRefunded;
    mapping(uint256 => uint256) requestedDrawId;

    event NewDrawOpened(uint256 indexed drawId, uint256 price);
    event DrawFinished(
        uint256 indexed drawId,
        address firstPlace,
        address secondPlace,
        address thirdPlace
    );
    event WinningClaimed(uint256 indexed drawId);
    event EnterDraw(uint256 indexed drawId, address participant, uint256 count);
    event Refunded(address participant, uint256 drawId);
    event ExpiredTimeChanged(uint256 drawId);

    constructor(
        address _usdc,
        address _usdce,
        address _vrfCoordinator
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        require(_usdc != address(0), "invalid usdc address");
        require(_usdce != address(0), "invalid usdce address");
        require(_vrfCoordinator != address(0), "invalid vrf");

        treasurer = msg.sender;
        nextDrawId = 1;

        usdc = IERC20(_usdc);
        usdce = IERC20(_usdce);
        COORDINATOR = IVRFCoordinatorV2Plus(_vrfCoordinator);
    }

    function enterMultiple(
        uint256 _drawId,
        uint256 _count,
        bool isUSDC
    ) public {
        Draw storage draw = draws[_drawId];

        require(draw.status == DrawStatus.OPEN, "Draw Not Opend");
        if (draw.usdcAmount + draw.usdceAmount < draw.softcap) {
            require(
                block.timestamp < draw.startTime + draw.expiredTime,
                "Draw Expired"
            );
        }

        uint256 totalPrice = draw.price * _count;

        if (isUSDC) {
            usdc.safeTransferFrom(msg.sender, address(this), totalPrice);
            draw.usdcAmount += totalPrice;
            addressToDrawToUSDC[msg.sender][_drawId] += totalPrice;
        } else {
            usdce.safeTransferFrom(msg.sender, address(this), totalPrice);
            draw.usdceAmount += totalPrice;
            addressToDrawToUSDCe[msg.sender][_drawId] += totalPrice;
        }

        uint256 count = _count + (_count / 10);
        for (uint256 i = 0; i < count; i++) {
            participants[_drawId].push(msg.sender);
        }

        addressToDrawToTickets[msg.sender][_drawId] += count;

        if (draw.usdcAmount + draw.usdceAmount >= draw.hardcap)
            _pickWinner(_drawId);

        emit EnterDraw(_drawId, msg.sender, _count);
    }

    function openNextDraw(
        uint256 _price,
        uint256 _hardcap,
        uint256 _softcap,
        uint256 _expiredTime
    ) external onlyOwner {
        require(_price > 0, "Invalid Entry Price");
        require(_hardcap > _softcap && _softcap >= _price, "Invalid Price");
        require(_expiredTime > 0, "Invalid Expired Time");

        uint256 drawId = nextDrawId;

        Draw memory draw = Draw({
            startTime: block.timestamp,
            status: DrawStatus.OPEN,
            price: _price,
            usdcAmount: 0,
            usdceAmount: 0,
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

        emit NewDrawOpened(drawId, _price);
    }

    function editExpiredTime(
        uint256 _drawId,
        uint256 _expiredTime
    ) external onlyOwner {
        require(_drawId < nextDrawId, "Invalid Draw");

        Draw storage draw = draws[_drawId];

        require(draw.status == DrawStatus.OPEN, "Draw Should Be Open");
        require(
            block.timestamp < draw.startTime + draw.expiredTime,
            "Draw Expired"
        );
        require(_expiredTime > draw.expiredTime, "Invalid Expired Time");

        draw.expiredTime = _expiredTime;

        emit ExpiredTimeChanged(_drawId);
    }

    function _pickWinner(uint256 _drawId) internal returns (uint256 requestId) {
        Draw storage draw = draws[_drawId];

        require(draw.status == DrawStatus.OPEN, "Draw Not Opened");

        draw.status = DrawStatus.CLOSING;

        requestId = COORDINATOR.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: 3,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        requestedDrawId[requestId] = _drawId;

        return requestId;
    }

    function pickWinner(uint256 _drawId) public onlyOwner {
        _pickWinner(_drawId);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] calldata _randomWords
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

        emit DrawFinished(drawId, firstPlace, secondPlace, thirdPlace);
    }

    function distribute(uint256 _drawId) public {
        Draw memory draw = draws[_drawId];

        require(draw.status == DrawStatus.CLOSED, "Draw Not Completed");
        require(!isDistributed[_drawId], "Already Distributed");

        isDistributed[_drawId] = true;

        uint256 totalUSDCAmount = draw.usdcAmount;
        uint256 totalUSDCeAmount = draw.usdceAmount;

        // Calculate distribution for USDC
        uint256 usdcAmountForFirst = (totalUSDCAmount *
            draw.distributionRate.first) / 10000;
        uint256 usdcAmountForSecond = (totalUSDCAmount *
            draw.distributionRate.second) / 10000;
        uint256 usdcAmountForThird = (totalUSDCAmount *
            draw.distributionRate.third) / 10000;

        uint256 usdcRestAmount = totalUSDCAmount;

        // Distribute USDC amounts
        if (usdcAmountForFirst > 0 && draw.firstPlace != address(0)) {
            usdc.safeTransfer(draw.firstPlace, usdcAmountForFirst);
            usdcRestAmount -= usdcAmountForFirst;
        }

        if (usdcAmountForSecond > 0 && draw.secondPlace != address(0)) {
            usdc.safeTransfer(draw.secondPlace, usdcAmountForSecond);
            usdcRestAmount -= usdcAmountForSecond;
        }

        if (usdcAmountForThird > 0 && draw.thirdPlace != address(0)) {
            usdc.safeTransfer(draw.thirdPlace, usdcAmountForThird);
            usdcRestAmount -= usdcAmountForThird;
        }

        // Transfer remaining USDC to treasurer
        if (usdcRestAmount > 0) {
            usdc.safeTransfer(treasurer, usdcRestAmount);
        }

        // Calculate distribution for USDCe
        uint256 usdceAmountForFirst = (totalUSDCeAmount *
            draw.distributionRate.first) / 10000;
        uint256 usdceAmountForSecond = (totalUSDCeAmount *
            draw.distributionRate.second) / 10000;
        uint256 usdceAmountForThird = (totalUSDCeAmount *
            draw.distributionRate.third) / 10000;

        uint256 usdceRestAmount = totalUSDCeAmount;

        // Distribute USDCe amounts
        if (usdceAmountForFirst > 0 && draw.firstPlace != address(0)) {
            usdce.safeTransfer(draw.firstPlace, usdceAmountForFirst);
            usdceRestAmount -= usdceAmountForFirst;
        }

        if (usdceAmountForSecond > 0 && draw.secondPlace != address(0)) {
            usdce.safeTransfer(draw.secondPlace, usdceAmountForSecond);
            usdceRestAmount -= usdceAmountForSecond;
        }

        if (usdceAmountForThird > 0 && draw.thirdPlace != address(0)) {
            usdce.safeTransfer(draw.thirdPlace, usdceAmountForThird);
            usdceRestAmount -= usdceAmountForThird;
        }

        // Transfer remaining USDCe to treasurer
        if (usdceRestAmount > 0) {
            usdce.safeTransfer(treasurer, usdceRestAmount);
        }

        emit WinningClaimed(_drawId);
    }

    function setVRFCoordinator(address _vrfCoordinator) external onlyOwner {
        require(_vrfCoordinator != address(0), "invalid address");

        COORDINATOR = IVRFCoordinatorV2Plus(_vrfCoordinator);
    }

    function setSubscriptionData(
        // bytes32 _keyHash,
        uint256 _subscriptionId
    )
        external
        // uint32 _callbackGasLimit
        onlyOwner
    {
        // s_keyHash = _keyHash;
        s_subscriptionId = _subscriptionId;
        // callbackGasLimit = _callbackGasLimit;
    }

    function setDistributionRate(
        uint256 _first,
        uint256 _second,
        uint256 _third
    ) external onlyOwner {
        require(_first + _second + _third <= 10000, "exceed");

        distributionRate = DistributionRate({
            first: _first,
            second: _second,
            third: _third
        });
    }

    // function setEntryToken(address _addr) external onlyOwner {
    //     require(_addr != address(0), "zero address");
    //     entryToken = IERC20(_addr);
    // }

    function refund(uint256 _drawId) public {
        bool expired = isExpired(_drawId);

        require(expired, "Draw Not Expired");
        require(
            addressToDrawToUSDC[msg.sender][_drawId] > 0 ||
                addressToDrawToUSDCe[msg.sender][_drawId] > 0,
            "Not Eligible"
        );
        require(!isRefunded[msg.sender][_drawId], "Already Refund");

        if (addressToDrawToUSDC[msg.sender][_drawId] > 0) {
            usdc.safeTransfer(
                msg.sender,
                addressToDrawToUSDC[msg.sender][_drawId]
            );
        }

        if (addressToDrawToUSDCe[msg.sender][_drawId] > 0) {
            usdce.safeTransfer(
                msg.sender,
                addressToDrawToUSDCe[msg.sender][_drawId]
            );
        }

        isRefunded[msg.sender][_drawId] = true;

        emit Refunded(msg.sender, _drawId);
    }

    function isExpired(uint256 _drawId) public view returns (bool) {
        Draw memory draw = draws[_drawId];
        bool expired = draw.status == DrawStatus.OPEN &&
            draw.usdcAmount + draw.usdceAmount < draw.softcap &&
            block.timestamp >= (draw.startTime + draw.expiredTime);
        return expired;
    }

    function setTreasurer(address _treasurer) external onlyOwner {
        require(_treasurer != address(0), "zero address");
        treasurer = _treasurer;
    }
}
