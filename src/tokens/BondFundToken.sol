pragma solidity ^0.4.24;

import "./DividendHistoryToken.sol";

/// @dev Bond Fund Token
contract BondFundToken is DividendHistoryToken {
    // Token name
    string public name;
    // IPFS URL
    string public documentURL;
    // Integrity check of IPFS stored JSON doc
    uint256 public documentHash;
    // An arbitrary versioning scheme
    string public constant version = "v1";

    /// @notice Constructor to create a BondFundToken
    /// @param _symbol The address of the recipient
    constructor(string _name,
                string _symbol,
                uint256 _mintCap,
                uint256 _startDate,
                uint256 _maturityDate,
                address _whitelist,
                string _documentURL,
                uint256 _documentHash) HistoryToken(_symbol, 18, _mintCap, _startDate, _maturityDate, _whitelist) public {
        name = _name;
        documentURL = _documentURL;
        documentHash = _documentHash;
    }
}