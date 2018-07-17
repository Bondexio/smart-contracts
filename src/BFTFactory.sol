pragma solidity ^0.4.21;

import "./BFT.sol";
import "./Controlled.sol";
import "./ERC20Interface.sol";

/// @dev Briq Fund Token Factory
contract BFTFactory is Controlled {

    /// @notice Creation or deployment of fund token contracts
    /// @param _name Name of the fund token contract
    /// @param _symbol Symbol, acronym or code of the fund token
    /// @param _mintCap Maximum amount of fund tokens in circulation
    /// @param _startDate Fund start date
    /// @param _maturityDate Fund end or maturity date
    /// @param _whitelist Whitelist contract address
    /// @param _documentURL IPFS URL
    /// @param _documentHash Integrity check of IPFS stored JSON doc
    /// @return The address of the fund token
    function createBriqFundToken(
        string _name, 
        string _symbol, 
        uint256 _mintCap, 
        uint256 _startDate, 
        uint256 _maturityDate, 
        address _whitelist, 
        string _documentURL, 
        uint256 _documentHash
    ) public onlyController returns (address) {
        BriqFundToken token = new BriqFundToken(
            _name, 
            _symbol, 
            _mintCap,
            _startDate, 
            _maturityDate, 
            _whitelist, 
            _documentURL, 
            _documentHash
        );
        token.changeController(controller);
        return address(token);
    }

    /// @dev fallback function which prohibits payment
    function () public payable {
        revert();
    }

    /// @notice This method can be used by the controller to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(address _token) public onlyController {
        if (_token == address(0)) {
            controller.transfer(address(this).balance);
            return;
        }

        ERC20Interface token = ERC20Interface(_token);
        uint balance = token.balanceOf(this);
        token.transfer(controller, balance);
        emit ClaimedTokens(_token, controller, balance);
    }

    event ClaimedTokens(address indexed _token, address indexed _owner, uint256 _amount);  

}



