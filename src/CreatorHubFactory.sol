// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./CreatorHub.sol";

contract CreatorHubFactory is Ownable, Pausable {
    uint96 public processingFee;
    uint32 public creatorCount;
    mapping(address => address) public creatorContracts;
    address[] private creators;
    address public idrxTokenAddress;


    event CreatorRegistered(address indexed creatorAddress, address contractAddress);
    event FeeUpdated(uint96 newFee);
    event FeesWithdrawn(uint96 value);
    event CreatorExcessWithdrawn(address indexed creatorContract, uint96 value);

    error CreatorExists();
    error CreatorNotFound();
    error NoFeesToWithdraw();
    error TransferFailed();

    constructor(uint96 _processingFee, address _idrxTokenAddress) Ownable(msg.sender) {
        processingFee = _processingFee;
        idrxTokenAddress = _idrxTokenAddress;
    }

    function registerCreator() external whenNotPaused {
        if (creatorContracts[msg.sender] != address(0)) revert CreatorExists();

        CreatorHub newCreator = new CreatorHub(msg.sender, processingFee, address(this), idrxTokenAddress);

        creatorContracts[msg.sender] = address(newCreator);
        creators.push(address(newCreator));
        unchecked {
            ++creatorCount;
        }

        emit CreatorRegistered(msg.sender, address(newCreator));
    }

    function updateProcessingFee(uint96 _processingFee) external onlyOwner {
        processingFee = _processingFee;
        emit FeeUpdated(_processingFee);

        uint256 length = creators.length;
        for (uint256 i = 0; i < length;) {
            CreatorHub(payable(creators[i])).updateProcessingFee(_processingFee);
            unchecked {
                ++i;
            }
        }
    }

    function withdrawExcess(address creatorAddress) external onlyOwner {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();

        CreatorHub(payable(creatorContract)).withdrawExcess();
    }

    function withdrawAllCreatorsExcess() external onlyOwner {
        uint256 length = creators.length;
        for (uint256 i = 0; i < length;) {
            CreatorHub(payable(creators[i])).withdrawExcess();
            unchecked {
                ++i;
            }
        }
    }

    function getCreatorContract(address creatorAddress) external view returns (address) {
        return creatorContracts[creatorAddress];
    }

    function getAllCreators() external view returns (address[] memory) {
        return creators;
    }

    function getCreatorBalance(address creatorAddress) external view returns (uint96 balance, uint96 pendingvalue) {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();
        return CreatorHub(payable(creatorContract)).getContractBalances();
    }

    function pauseCreator(address creatorAddress) external onlyOwner {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();
        CreatorHub(payable(creatorContract)).pauseHub();
    }

    function unpauseCreator(address creatorAddress) external onlyOwner {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();
        CreatorHub(payable(creatorContract)).unpauseHub();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawFees() external onlyOwner {
        uint96 balance = uint96(address(this).balance);
        if (balance == 0) revert NoFeesToWithdraw();

        (bool success,) = owner().call{value: balance}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(balance);
    }

    function getCreators(uint256 offset, uint256 limit) external view returns (address[] memory, uint256) {
        uint256 total = creators.length;
        if (offset >= total) {
            return (new address[](0), total);
        }

        uint256 size = total - offset;
        if (size > limit) {
            size = limit;
        }

        address[] memory result = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            result[i] = creators[offset + i];
        }

        return (result, total);
    }

    struct SaweranWithCreator {
        address creator;
        address penyawer;
        uint96 value;
        string note;
        uint32 createdAt;
        bool approved;
        bool discarded;
    }

    function getSaweransByPenyawer(address penyawer, uint256 offset, uint256 limit)
        external
        view
        returns (SaweranWithCreator[] memory result, uint256 total)
    {
        // First count total sawerans
        total = 0;
        for (uint256 i = 0; i < creators.length; i++) {
            (, uint256 creatorTotal) = CreatorHub(payable(creators[i])).getSaweransByPenyawer(penyawer, 0, 0);
            total += creatorTotal;
        }

        if (total == 0 || offset >= total) {
            return (new SaweranWithCreator[](0), total);
        }

        // Calculate size of return array
        uint256 size = total - offset;
        if (size > limit) {
            size = limit;
        }

        result = new SaweranWithCreator[](size);
        uint256 resultIndex = 0;
        uint256 skipped = 0;

        // Fill result array
        for (uint256 i = 0; i < creators.length && resultIndex < size; i++) {
            CreatorHub creator = CreatorHub(payable(creators[i]));
            (CreatorHub.Saweran[] memory sawerans,) = creator.getSaweransByPenyawer(penyawer, 0, type(uint256).max);

            for (uint256 j = 0; j < sawerans.length && resultIndex < size; j++) {
                if (skipped < offset) {
                    skipped++;
                    continue;
                }
                result[resultIndex] = SaweranWithCreator({
                    creator: creators[i],
                    penyawer: sawerans[j].penyawer,
                    value: sawerans[j].value,
                    note: sawerans[j].note,
                    createdAt: sawerans[j].createdAt,
                    approved: sawerans[j].approved,
                    discarded: sawerans[j].discarded
                });
                resultIndex++;
            }
        }

        return (result, total);
    }

    receive() external payable {}
}