pragma solidity ^0.4.24;

/// @dev Whitelist Interface
contract WhitelistInterface {
    function isWhitelisted(address _address) public view returns (bool);
}
