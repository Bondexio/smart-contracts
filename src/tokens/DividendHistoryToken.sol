pragma solidity ^0.4.24;

import "../libs/SafeMath.sol";
import "./HistoryToken.sol";

/// @dev Dividend History Token
contract DividendHistoryToken is HistoryToken {
    using SafeMath for uint256;

    /// @dev `Dividend` is the structure that represents a dividend deposit
    struct Dividend {
        // Block number of deposit
        uint256 blockNumber;
        // Block timestamp of deposit
        uint256 timestamp;
        // Deposit amount
        uint256 amount;
        // Total current claimed amount
        uint256 claimedAmount;
        // Total supply at the block
        uint256 totalSupply;
        // Indicates if address has already claimed the dividend
        mapping (address => bool) claimed;
    }

    // Array of depositeddividends
    Dividend[] public dividends;

    // Indicates the newest dividends address has claimed
    mapping (address => uint256) dividendsClaimed;

    ////////////////
    // Dividend deposits
    ////////////////

    /// @notice This method can be used by the controller to deposit dividends.
    /// @param _amount The amount that is going to be created as new dividend
    function depositDividend(uint256 _amount) public onlyController onlyActive {
        uint256 currentSupply = totalSupplyAt(block.number);
        require(currentSupply > 0);
        uint256 dividendIndex = dividends.length;
        require(block.number > 0);    
        uint256 blockNumber = block.number - 1; 
        dividends.push(Dividend(blockNumber, now, _amount, 0, currentSupply));
        emit DividendDeposited(msg.sender, blockNumber, _amount, currentSupply, dividendIndex);
    }

    ////////////////
    // Dividend claims
    ////////////////

    /// @dev Claims dividend on `_dividendIndex` to `_owner` address.
    /// @param _owner The address where dividends are registered to be claimed
    /// @param _dividendIndex The index of the dividend to claim
    /// @return The total amount of available EUR tokens for claim
    function claimDividendByIndex(address _owner, uint256 _dividendIndex) internal returns (uint256) {
        uint256 claim = calculateClaimByIndex(_owner, _dividendIndex);
        Dividend storage dividend = dividends[_dividendIndex];
        dividend.claimed[_owner] = true;
        dividend.claimedAmount = dividend.claimedAmount.add(claim);
        return claim;
    }

    /// @dev Calculates available dividend on `_dividendIndex` for `_owner` address.
    /// @param _owner Address of belonging amount
    /// @param _dividendIndex The index of the dividend for which calculation is done
    /// @return The total amount of available EUR tokens for claim
    function calculateClaimByIndex(address _owner, uint256 _dividendIndex) internal view returns (uint256) {
        Dividend storage dividend = dividends[_dividendIndex];
        uint256 balance = balanceOfAt(_owner, dividend.blockNumber);
        uint256 claim = balance.mul(dividend.amount).div(dividend.totalSupply);
        return claim;
    }

    /// @notice Calculates available dividends for `_owner` address.
    /// @param _owner Address of belonging amount
    /// @return The total amount of available EUR tokens for claim
    function unclaimedDividends(address _owner) public view returns (uint256) {
        uint256 sumOfDividends = 0;
        if (dividendsClaimed[_owner] < dividends.length) {
            for (uint256 i = dividendsClaimed[_owner]; i < dividends.length; i++) {
                if (!dividends[i].claimed[_owner]) {
                    uint256 dividend = calculateClaimByIndex(_owner, i);
                    sumOfDividends = sumOfDividends.add(dividend);
                }
            }
        }
        return sumOfDividends;
    }

    /// @notice Claims available dividends for `_owner` address.
    /// @param _owner Address for which dividends are going to be claimed
    /// @return The total amount of available EUR tokens for claim
    function claimAllDividends(address _owner) public onlyController onlyActive returns (uint256) {
        uint256 sumOfDividends = 0;
        if (dividendsClaimed[_owner] < dividends.length) {
            for (uint256 i = dividendsClaimed[_owner]; i < dividends.length; i++) {
                if (!dividends[i].claimed[_owner]) {
                    dividendsClaimed[_owner] = SafeMath.add(i, 1);
                    uint256 dividend = claimDividendByIndex(_owner, i);
                    sumOfDividends = sumOfDividends.add(dividend);
                }
            }
            emit DividendClaimed(_owner, sumOfDividends);
        }
        return sumOfDividends;
    }

    ////////////////
    // Events
    ////////////////

    event DividendDeposited (address indexed _depositor, uint256 _blockNumber, uint256 _amount, uint256 _totalSupply, uint256 _dividendIndex);
    event DividendClaimed (address _fundWallet, uint256 _amount);

}