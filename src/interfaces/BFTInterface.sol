pragma solidity ^0.4.24;

import "./MintableERC20Interface.sol";
import "./ClaimableTokensInterface.sol";

/// @dev Bond Fund Token Interface
contract BFTInterface is MintableERC20Interface, ClaimableTokensInterface {
    function close() public;
    function enableTransfers(bool _transfersEnabled) public;
    function depositDividend(uint256 _amount) public;
    function isActive() public view returns (bool);
    function claimAllDividends(address _to) public returns (uint256);
    function unclaimedDividends(address _owner) public view returns (uint256);
}


