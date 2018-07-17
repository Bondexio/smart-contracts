pragma solidity ^0.4.21;

import "./WhitelistInterface.sol";
import "../Libs/ClaimableTokensInterface.sol";

/// @dev Briq Whitelist Interface
contract BWLInterface is WhitelistInterface, ClaimableTokensInterface {
    function add(address _address) public;
    function remove(address _address) public;
    function bulkAdd(address[] _addresses) public;
    function bulkRemove(address[] _addresses) public;
    function changeController(address _newController) public;
}
