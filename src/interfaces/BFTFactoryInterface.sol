pragma solidity ^0.4.24;

import "./ClaimableTokensInterface.sol";

/// @dev Bond Fund Token Factory Interface
contract BFTFactoryInterface is ClaimableTokensInterface {
    function createBondFundToken(
        string _name, 
        string _symbol, 
        uint256 _mintCap, 
        uint256 _startDate, 
        uint256 _maturityDate, 
        address _whitelist, 
        string _documentURL, 
        uint256 _documentHash
    ) public returns (address);
}

