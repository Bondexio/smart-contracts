pragma solidity ^0.4.21;

import "../Libs/MintableERC20Interface.sol";
import "../Libs/ClaimableTokensInterface.sol";

/// @dev EUR Token Interface
contract EURTokenInterface is MintableERC20Interface, ClaimableTokensInterface {
    function burn(uint256 _value, address _from) public returns (bool);
    function enableTransfers(bool _transfersEnabled) public;
}
