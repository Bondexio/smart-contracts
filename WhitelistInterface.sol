pragma solidity ^0.4.21;

/// @dev Whitelist Interface
contract WhitelistInterface {
    function isWhitelisted(address _address) public view returns (bool);
}
