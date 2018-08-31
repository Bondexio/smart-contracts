pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "../libs/SafeMath.sol";
import "../interfaces/ERC20Interface.sol";
import "../ownership/Ownable.sol";
import "../interfaces/EURTokenInterface.sol";
import "../interfaces/BWLInterface.sol";
import "../interfaces/BFTInterface.sol";
import "../interfaces/BFTFactoryInterface.sol";

/// @dev Bond Funds Controller
contract BondFundsController is Ownable {
    using SafeMath for uint256;

    /// @dev `FundTokenIndex` is the structure that represents 
    ///  fund token index in fundTokens array
    struct FundTokenIndex {
        // `index` where fund token is in fundTokens array
        uint256 index;
        // `exists` checks if fund exists on specified index, because of zero index
        bool exists;
    }

    // Mapping from hashed symbol to index in fund token array
    mapping(bytes32 => FundTokenIndex) public indexes;

    // Array representing the fund tokens
    BFTInterface[] public fundTokens;
    
    // EUR token reference
    EURTokenInterface public eurToken;

    // Whitelist reference
    BWLInterface public whitelist;

    // Factory reference
    BFTFactoryInterface public factory;

////////////////
// Constructor
////////////////

    /// @notice Constructor to create a controller
    constructor(address _whitelist, address _eurToken, address _factory) public {
        require(_whitelist != address(0));
        require(_eurToken != address(0));
        require(_factory != address(0));
        whitelist = BWLInterface(_whitelist);
        eurToken = EURTokenInterface(_eurToken);
        factory = BFTFactoryInterface(_factory);
    }

////////////////
// Helper functions
////////////////

    /// @notice Gets fund by `_symbol`
    /// @param _symbol The symbol or acronym fund is identified with
    /// @return Fund token contract through BFTInterface
    function getFundBySymbol(string _symbol) public view returns (BFTInterface) {
        bytes32 symbolHash = keccak256(abi.encodePacked(_symbol));
        FundTokenIndex memory indexStruct = indexes[symbolHash];
        require(indexStruct.exists && indexStruct.index < fundTokens.length);
        BFTInterface fundToken = fundTokens[indexStruct.index];
        return fundToken;
    }

//////////
// Bond Fund Token proxy functions
//////////

    /// @notice Creates new bond fund token contract
    /// @param _name The name of the fund
    /// @param _symbol The symbol or acronym fund is identified with
    /// @param _mintCap Maximum amount of fund tokens in circulation
    /// @param _startDate Start date of fund
    /// @param _maturityDate Maturity date of fund
    /// @param _documentURL IPFS URL
    /// @param _documentHash Integrity check of IPFS stored JSON doc
    /// @return Deployed fund token contract address
    function createBondFundToken(
        string _name,
        string _symbol,
        uint256 _mintCap,
        uint256 _startDate,
        uint256 _maturityDate,
        string _documentURL,
        uint256 _documentHash
    ) public onlyOwner returns (address) {
        bytes32 symbolHash = keccak256(abi.encodePacked(_symbol));
        require(!indexes[symbolHash].exists);
        address tokenAddress = factory.createBondFundToken (
            _name, 
            _symbol, 
            _mintCap,
            _startDate, 
            _maturityDate, 
            whitelist, 
            _documentURL, 
            _documentHash
        );
        indexes[symbolHash] = FundTokenIndex(fundTokens.length, true);
        fundTokens.push(BFTInterface(tokenAddress));
        return tokenAddress;
    }

    /// @notice Enables or disables fund token transfers
    /// @param _symbol The symbol or acronym fund is identified with
    /// @param _transfersEnabled True if transfers should be enabled
    function enableBondFundTokenTransfers(string _symbol, bool _transfersEnabled) public onlyOwner {
        BFTInterface fundToken = getFundBySymbol(_symbol);
        fundToken.enableTransfers(_transfersEnabled);
    }

    /// @notice Mints fund tokens
    /// @param _symbol The symbol or acronym fund is identified with
    /// @param _owner Address on which tokens are minted
    /// @param _amount Amount of minted tokens
    function mintBondFundToken(string _symbol, address _owner, uint256 _amount) public onlyOwner {
        require(_owner != address(0));
        BFTInterface fundToken = getFundBySymbol(_symbol);
        if (!whitelist.isWhitelisted(_owner)){
            whitelist.add(_owner);
        }
        fundToken.mint(_amount, _owner);
    }

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _symbol The symbol or acronym fund is identified with
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function transferFromBondFundToken(string _symbol, address _from, address _to, uint256 _amount) public onlyOwner returns (bool success) {
        BFTInterface fundToken = getFundBySymbol(_symbol);
        return fundToken.transferFrom(_from, _to, _amount);
    }

    /// @notice Close the fund, can be called only once when fund matures
    /// @param _symbol The symbol or acronym fund is identified with
    function closeBondFundToken(string _symbol) public onlyOwner {
        BFTInterface fundToken = getFundBySymbol(_symbol);
        fundToken.close();
    }

    /// @notice This method can be used to deposit dividends
    /// @param _symbol The symbol or acronym fund is identified with
    /// @param _amount The amount that is going to be created as new dividend
    function depositDividendBondFundToken(string _symbol, uint256 _amount) public onlyOwner {
        BFTInterface fundToken = getFundBySymbol(_symbol);
        fundToken.depositDividend(_amount);
    }

    /// @notice This method can be used to deposit multiple dividends at once
    /// @param _symbols Symbols or acronyms funds are identified with
    /// @param _amounts Amounts which are going to be used as base for new dividends
    function bulkDepositDividendBondFundToken(string[] _symbols, uint256[] _amounts) public onlyOwner {
        require(_symbols.length == _amounts.length && _symbols.length > 0);
        for (uint256 i = 0; i < _symbols.length; i++) {
            BFTInterface fundToken = getFundBySymbol(_symbols[i]);
            if (fundToken.isActive()) {
                fundToken.depositDividend(_amounts[i]);
            }
        }
    }

    /// @notice Calculates available dividends for all funds for `_fundWallets` addresses
    /// @param _fundWallets Addresses having fund tokens
    /// @return The total amount of available EUR tokens for claim
    function unclaimedDividends(address[] _fundWallets) public view returns (uint256) {
        uint256 sumOfDividends = 0;
        for (uint256 i = 0; i < fundTokens.length; i++) {
            if (fundTokens[i].isActive()) {
                for (uint256 j = 0; j < _fundWallets.length; j++) {
                    uint256 dividends = fundTokens[i].unclaimedDividends(_fundWallets[j]);
                    sumOfDividends = sumOfDividends.add(dividends);
                }
            }
        }
        return sumOfDividends;
    }

    /// @notice Claims available dividends for `_fundWallets` addresses
    /// @param _fundWallets Fund wallets holding the tokens used to claim dividends
    /// @param _dividendWallet Wallet on which dividends are claimed on
    function claimDividendBondFundTokens(address[] _fundWallets, address _dividendWallet) public onlyOwner {
        require(_dividendWallet != address(0));
        uint256 sumOfDividends = 0;
        for (uint256 i = 0; i < _fundWallets.length; i++) {
            uint256 dividends = claimDividendsActiveBondFundTokens(_fundWallets[i]);
            sumOfDividends = sumOfDividends.add(dividends);
        }
        if (sumOfDividends > 0) {
            addControllerToWhitelist();
            eurToken.transfer(_dividendWallet, sumOfDividends);
        }
    }

    /// @dev Internal claim of dividends for active fund token contracts
    /// @param _to Fund wallet used as a base for calculation
    /// @return The total amount of available EUR tokens for claim
    function claimDividendsActiveBondFundTokens(address _to) internal returns (uint256) {
        require(_to != address(0));
        uint256 sumOfDividends = 0;
        for (uint256 i = 0; i < fundTokens.length; i++) {
            if (fundTokens[i].isActive()) {
                uint256 dividends = fundTokens[i].claimAllDividends(_to);
                sumOfDividends = sumOfDividends.add(dividends);
            }
        }
        return sumOfDividends;
    }
    

    /// @notice This method can be used to extract mistakenly sent tokens to fund
    ///  token contract identified with _symbol.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokensBondFund(string _symbol, address _token) public onlyOwner {
        BFTInterface fundToken = getFundBySymbol(_symbol);
        fundToken.claimTokens(_token);
    }

//////////
// Bond EUR Token proxy functions
//////////

    /// @notice Transfer EUR tokens from one address to another
    /// @param _from address The address which you want to send tokens from
    /// @param _to address The address which you want to transfer to
    /// @param _value uint256 the amount of tokens to be transferred
    /// @return True if transfer successful
    function transferFromEURToken(address _from, address _to, uint256 _value) public onlyOwner returns (bool) {
        return eurToken.transferFrom(_from, _to, _value);
    }

    /// @notice Function to mint EUR tokens
    /// @param _value The amount of tokens to mint.
    /// @param _to The address that will receive the minted tokens.
    /// @return A boolean that indicates if the operation was successful.
    function mintEURToken(uint256 _value, address _to) public onlyOwner returns (bool) {
        return eurToken.mint(_value, _to);
    }

    /// @notice Burns a specific amount of EUR tokens from specified address
    /// @param _value The amount of token to be burned.
    /// @param _from The address from which tokens are burned.
    /// @return A boolean that indicates if the operation was successful.
    function burnEURToken(uint256 _value, address _from) public onlyOwner returns (bool) {
        return eurToken.burn(_value, _from);
    }
    
    /// @notice Enables or disables EUR token transfers
    /// @param _transfersEnabled True if transfers should be enabled
    function enableEURTokenTransfers(bool _transfersEnabled) public onlyOwner {
        eurToken.enableTransfers(_transfersEnabled);
    }

    /// @notice This method can be used to extract mistakenly sent tokens to EUR
    ///  token contract
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether
    function claimTokensEURToken(address _token) public onlyOwner {
        eurToken.claimTokens(_token);
    }

//////////
// Bond Whitelist proxy functions
//////////

    /// @dev Automatic whitelisting of controller if not whitelisted
    function addControllerToWhitelist() internal {
        address controller = address(this);
        if (!whitelist.isWhitelisted(controller))
            whitelist.add(controller);
    }

    /// @notice Check if address is whitelisted
    /// @param _address Address as a parameter to check
    /// @return True if address is whitelisted
    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist.isWhitelisted(_address);
    }

    /// @notice Add address to whitelist
    /// @param _address Address to be whitelisted
    function addToWhitelist(address _address) public onlyOwner {
        whitelist.add(_address);
    }

    /// @notice Remove address from whitelist
    /// @param _address Address to be removed from whitelist
    function removeFromWhitelist(address _address) public onlyOwner {
        whitelist.remove(_address);
    }

    /// @notice Add multiple addresses to whitelist
    /// @param _addresses Addresses to be whitelisted
    function bulkAddToWhitelist(address[] _addresses) public onlyOwner {
        whitelist.bulkAdd(_addresses);
    }

    /// @notice Remove multiple addresses from whitelist
    /// @param _addresses Addresses to be removed from whitelist
    function bulkRemoveFromWhitelist(address[] _addresses) public onlyOwner {
        whitelist.bulkRemove(_addresses);
    }

    /// @notice This method can be used to extract mistakenly sent tokens to Whitelist
    ///  token contract
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether
    function claimTokensWhitelist(address _token) public onlyOwner {
        whitelist.claimTokens(_token);
    }

////////////////
// BFT Factory proxy functions
////////////////

    /// @notice This method can be used to extract mistakenly sent tokens to Factory
    ///  token contract
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether
    function claimTokensFactory(address _token) public onlyOwner {
        factory.claimTokens(_token);
    }

////////////////
// Safety functions
////////////////

    /// @dev fallback function which prohibits payment
    function () public payable {
        revert();
    }

    /// @notice This method can be used by the owner to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(address _token) public onlyOwner {
        if (_token == address(0)) {
            owner.transfer(address(this).balance);
            return;
        }

        ERC20Interface token = ERC20Interface(_token);
        uint balance = token.balanceOf(this);
        token.transfer(owner, balance);
        emit ClaimedTokens(_token, owner, balance);
    }

////////////////
// Events
////////////////

    event ClaimedTokens(address indexed _token, address indexed _owner, uint256 _amount);
}