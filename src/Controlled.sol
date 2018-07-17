pragma solidity ^0.4.21;

/// @dev Controlled
contract Controlled {

    // Controller address
    address public controller;

    /// @notice Checks if msg.sender is controller
    modifier onlyController { 
        require(msg.sender == controller); 
        _; 
    }

    /// @notice Constructor to initiate a Controlled contract
    function Controlled() public { 
        controller = msg.sender;
    }

    /// @notice Gives possibility to change the controller
    /// @param _newController Address representing new controller
    function changeController(address _newController) public onlyController {
        controller = _newController;
    }

}
