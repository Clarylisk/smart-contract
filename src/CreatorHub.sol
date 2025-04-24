// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// struct WebLink {
//     string url;
//     string description;
// }

contract CreatorHub is Ownable, ReentrancyGuard, Pausable {
    struct Saweran {
        address penyawer;
        uint96 value;
        string note;
        uint32 createdAt;
        bool approved;
        bool discarded;
    }

    IERC20 public immutable idrxToken;
    address public immutable hubFactory;    
    uint96 public processingFee;
    string public creatorId;
    // string public profileBio;
    // string public profilePicture;
    // WebLink[] public socialLinks;
    Saweran[] public sawerans;  
    uint96 private pendingBalance;
    uint96 private approvedBalance;

    event SaweranReceived(address indexed penyawer, uint96 value, string note, uint32 createdAt);
    event SaweranApproved(uint256 indexed SaweranId);
    event SaweranDiscarded(uint256 indexed SaweranId);
    event Withdraw(address indexed to, uint96 amount);
    event WithdrawExcess(address indexed to, uint96 amount);
    event ExcessFundsWithdrawn(uint96 value);
    event Paused();
    event Unpaused();

    error UnauthorizedAccess();

    modifier onlyHubFactory() {
        if (msg.sender != hubFactory) revert("Unauthorized: Only hub factory");
        _;
    }

    modifier onlyFactoryAdmin() {
        if (msg.sender != Ownable(hubFactory).owner()) revert UnauthorizedAccess();
        _;
    }

    constructor(
        address _owner,
        uint96 _processingFee,
        address _hubFactory,
        address _idrxTokenAddress
    ) Ownable(_owner) {
        processingFee = _processingFee;
        hubFactory = _hubFactory;   
        idrxToken = IERC20(_idrxTokenAddress);
    }

    function sawer(uint96 amount, string calldata note) external payable nonReentrant whenNotPaused {
        require(amount > processingFee, "Insufficient Saweran amount");
        require(idrxToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        unchecked {
            pendingBalance += amount;
            sawerans.push(Saweran({
                penyawer: msg.sender,
                value: amount,
                note: note,
                createdAt: uint32(block.timestamp),
                approved: false,
                discarded: false
            }));
        }
        emit SaweranReceived(msg.sender, amount, note, uint32(block.timestamp));
    }

    function approveSaweran(uint256 SaweranId) external onlyOwner nonReentrant whenNotPaused {
        require(SaweranId < sawerans.length, "Invalid ID");

        Saweran storage saweran = sawerans[SaweranId];
        require(!saweran.approved && !saweran.discarded, "Already handled");

        saweran.approved = true;

        uint96 fee = processingFee;
        uint96 totalAmount = saweran.value;
        uint96 payout = totalAmount - fee;
        unchecked {
            pendingBalance -= totalAmount;
            approvedBalance += payout;
        }

        require(idrxToken.transfer(hubFactory, fee), "Fee transfer failed");
        require(idrxToken.transfer(owner(), payout), "Payout transfer failed");

        emit SaweranApproved(SaweranId);
    }

    function discardSaweran(uint256 SaweranId) external onlyOwner nonReentrant whenNotPaused {
        require(SaweranId < sawerans.length, "Invalid ID");

        Saweran storage saweran = sawerans[SaweranId];
        require(!saweran.approved && !saweran.discarded, "Already processed");

        saweran.discarded = true;

        uint96 fee = processingFee;
        uint96 refundAmount = saweran.value - fee;
        unchecked {
            pendingBalance -= saweran.value;
        }

        (bool feeSent,) = hubFactory.call{value: fee}("");
        require(feeSent, "Fee transfer failed");

        (bool refundSent,) = saweran.penyawer.call{value: refundAmount}("");
        require(refundSent, "Refund failed");

        emit SaweranDiscarded(SaweranId);
    }

    function acceptAllSawerans() external onlyOwner nonReentrant whenNotPaused {
        for (uint256 i = 0; i < sawerans.length; i++) {
            Saweran storage saweran = sawerans[i];

            if (!saweran.approved && !saweran.discarded) {
                saweran.approved = true;
                
                uint96 fee = processingFee;
                uint96 totalAmount = saweran.value;
                uint96 payout = totalAmount - fee;
                unchecked {
                    pendingBalance -= totalAmount;
                    approvedBalance += payout;
                }

                require(idrxToken.transfer(hubFactory, fee), "Fee transfer failed");
                require(idrxToken.transfer(owner(), payout), "Payout transfer failed");     

                emit SaweranApproved(i);
            }
        }
    }

    function withdraw() external onlyOwner nonReentrant {
        uint96 amount = approvedBalance;
        require(amount > 0, "Nothing to withdraw");
        approvedBalance = 0;

        require(idrxToken.transfer(owner(), amount), "Withdraw failed");

        emit Withdraw(owner(), amount);
    }

    function withdrawExcess() external onlyOwner nonReentrant {
        uint96 totalHeld = uint96(idrxToken.balanceOf(address(this)));
        uint96 reserved = pendingBalance + approvedBalance;
        require(totalHeld > reserved, "No excess");

        uint96 excess = totalHeld - reserved;
        require(idrxToken.transfer(owner(), excess), "Withdraw excess failed");

        emit WithdrawExcess(owner(), excess);
    }

    function updateProcessingFee(uint96 _processingFee) external onlyHubFactory {
        processingFee = _processingFee;
    }

    function pauseHub() external onlyHubFactory {
        _pause();
        emit Paused();
    }

    function unpauseHub() external onlyHubFactory {
        _unpause();
        emit Unpaused();
    }

    function getTotalSawerans() external view returns (uint256) {
        return sawerans.length;
    }

    function getContractBalances() external view returns (uint96 approved, uint96 pending) {
        return (approvedBalance, pendingBalance);
    }

    function getSaweran(uint256 id)
        external
        view
        returns (
            address penyawer,
            uint96 value,
            string memory note,
            uint32 createdAt,
            bool approved,
            bool discarded
        )
    {
        require(id < sawerans.length, "Invalid ID");
        Saweran storage saweran = sawerans[id];
        return (saweran.penyawer, saweran.value, saweran.note, saweran.createdAt, saweran.approved, saweran.discarded);
    }

    function getSaweransByPenyawer(address penyawer, uint256 offset, uint256 limit)
        external
        view
        returns (Saweran[] memory result, uint256 total)
    {
        // First count total donations by this donator
        uint256 count = 0;
        for (uint256 i = 0; i < sawerans.length; i++) {
            if (sawerans[i].penyawer == penyawer) {
                count++;
            }
        }

        if (count == 0 || offset >= count) {
            return (new Saweran[](0), count);
        }

        // Calculate size of return array
        uint256 size = count - offset;
        if (size > limit) {
            size = limit;
        }

        // Create result array
        result = new Saweran[](size);
        uint256 resultIndex = 0;
        uint256 skipped = 0;

        // Fill result array
        for (uint256 i = 0; i < sawerans.length && resultIndex < size; i++) {
            if (sawerans[i].penyawer == penyawer) {
                if (skipped < offset) {
                    skipped++;
                    continue;
                }
                result[resultIndex] = sawerans[i];
                resultIndex++;
            }
        }

        return (result, count);
    }

    receive() external payable {}
}
