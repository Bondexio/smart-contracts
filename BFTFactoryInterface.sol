pragma solidity ^0.4.21;

import "./ClaimableTokensInterface.sol";

/// @dev Briq Fund Token Factory Interface
contract BFTFactoryInterface is ClaimableTokensInterface {
    function createBriqFundToken(
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

