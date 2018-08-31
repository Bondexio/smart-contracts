pragma solidity ^0.4.24;

import "./ERC20Interface.sol";

/// @dev Mintable ERC20 Interface
contract MintableERC20Interface is ERC20Interface {
    function mint(uint256 _value, address _to) public returns (bool);
}



