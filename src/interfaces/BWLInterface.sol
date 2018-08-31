pragma solidity ^0.4.24;

import "./WhitelistInterface.sol";
import "./ClaimableTokensInterface.sol";

/// @dev Bond Whitelist Interface
contract BWLInterface is WhitelistInterface, ClaimableTokensInterface {
    function add(address _address) public;
    function remove(address _address) public;
    function bulkAdd(address[] _addresses) public;
    function bulkRemove(address[] _addresses) public;
    //function changeController(address _newController) public;
}
