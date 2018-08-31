pragma solidity ^0.4.24;

/// @dev Interface which defines the ability of contract to claim mistakenly sent ERC20 tokens or Ether
contract ClaimableTokensInterface {
    function claimTokens(address _token) public;
}
