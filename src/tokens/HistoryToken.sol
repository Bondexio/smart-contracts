pragma solidity ^0.4.24;

import "../libs/SafeMath.sol";
import "../ownership/Controlled.sol";
import "../interfaces//WhitelistInterface.sol";

/// @dev History Token
contract HistoryToken is Controlled {
    using SafeMath for uint256;

    // Token identifier or code, usually acronym 
    string public symbol; 

    // Number of decimals of the smallest unit                
    uint8 public decimals;

    // Timestamp representing start of token validity, inclusive              
    uint256 public startDate;
    
    // Timestamp representing start of token validity, inclusive
    uint256 public maturityDate;

    // Reference to whitelist contract
    WhitelistInterface public whitelist;
    
    /// @dev `Checkpoint` is the structure that attaches a block number to a
    ///  given value, the block number attached is the one that last changed the value
    struct  Checkpoint {
        // `fromBlock` is the block number that the value was generated from
        uint128 fromBlock;
        // `value` is the amount of tokens at a specific block number
        uint128 value;
    }

    // `balances` is the map that tracks the balance of each address, in this
    //  contract when the balance changes the block number that the change
    //  occurred is also included in the map
    mapping (address => Checkpoint[]) balances;

    // `allowed` tracks any extra transfer rights as in all ERC20 tokens
    mapping (address => mapping (address => uint256)) allowed;

    // Tracks the history of the `totalSupply` of the token
    Checkpoint[] totalSupplyHistory;

    // Flag that determines if the token is transferable or not.
    bool public transfersEnabled;

    // Maximum amount of tokens which can exist
    uint256 public mintCap;

    // Defines if fund is active or not
    bool public active;

////////////////
// Constructor
////////////////

    /// @notice Constructor to create a HistoryToken
    /// @param _symbol The address of the recipient
    constructor(string _symbol, uint8 _decimals, uint256 _mintCap, uint256 _startDate, uint256 _maturityDate, address _whitelist) public {
        require(_whitelist != address(0));
        symbol = _symbol;
        decimals = _decimals;
        mintCap = _mintCap;
        startDate = _startDate;
        maturityDate = _maturityDate;
        whitelist = WhitelistInterface(_whitelist);                        
        transfersEnabled = true;
        active = true;
    }

///////////////////
// ERC20 Methods
///////////////////

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount) public onlyValid returns (bool success) {
        require(transfersEnabled);
        doTransfer(msg.sender, _to, _amount);
        return true;
    }

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function transferFrom(address _from, address _to, uint256 _amount) public onlyValid returns (bool success) {
        // The controller of this contract can move tokens around at will,
        //  this is important to recognize! Confirm that you trust the
        //  controller of this contract, which in most situations should be
        //  another open source smart contract or 0x0
        if (msg.sender != controller) {
            require(transfersEnabled);

            // The standard ERC 20 transferFrom functionality
            require(allowed[_from][msg.sender] >= _amount);
            allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
        }
        doTransfer(_from, _to, _amount);
        return true;
    }

    /// @dev This is the actual transfer function in the token contract, it can only be called by other functions in this contract.
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function doTransfer(address _from, address _to, uint256 _amount) internal {
        // Check if both _from and _to are whitelisted
        require(whitelist.isWhitelisted(_from) && whitelist.isWhitelisted(_to));

        if (_amount == 0) {
            emit Transfer(_from, _to, _amount);    // Follow the spec to louch the event when transfer 0
            return;
        }

        // Do not allow transfer to 0x0 or the token contract itself
        require((_to != address(0)) && (_to != address(this)));

        // If the amount being transfered is more than the balance of the
        //  account the transfer throws
        uint256 previousBalanceFrom = balanceOfAt(_from, block.number);
        require(previousBalanceFrom >= _amount);

        // First update the balance array with the new value for the address
        //  sending the tokens
        updateValueAtNow(balances[_from], previousBalanceFrom.sub(_amount));

        // Then update the balance array with the new value for the address
        //  receiving the tokens
        uint256 previousBalanceTo = balanceOfAt(_to, block.number);
        require(previousBalanceTo + _amount >= previousBalanceTo); // Check for overflow
        updateValueAtNow(balances[_to], previousBalanceTo.add(_amount));

        // An event to make the transfer easy to find on the blockchain
        emit Transfer(_from, _to, _amount);
    }

    /// @param _owner The address that's balance is being requested
    /// @return The balance of `_owner` at the current block
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balanceOfAt(_owner, block.number);
    }

    /// @notice `msg.sender` approves `_spender` to spend `_amount` tokens on
    ///  its behalf. This is a modified version of the ERC20 approve function
    ///  to be a little bit safer
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return True if the approval was successful
    function approve(address _spender, uint256 _amount) public onlyValid returns (bool success) {
        require(transfersEnabled);

        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender,0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require((_amount == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /// @dev This function makes it easy to read the `allowed[]` map
    /// @param _owner The address of the account that owns the token
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens of _owner that _spender is allowed
    ///  to spend
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /// @dev This function makes it easy to get the total number of tokens
    /// @return The total number of tokens
    function totalSupply() public view returns (uint256) {
        return totalSupplyAt(block.number);
    }


////////////////
// Query balance and totalSupply in History
////////////////

    /// @dev Queries the balance of `_owner` at a specific `_blockNumber`
    /// @param _owner The address from which the balance will be retrieved
    /// @param _blockNumber The block number when the balance is queried
    /// @return The balance at `_blockNumber`
    function balanceOfAt(address _owner, uint256 _blockNumber) public view returns (uint256) {
        // These next few lines are used when the balance of the token is
        //  requested before a check point was ever created for this token, it
        //  requires that the `parentToken.balanceOfAt` be queried at the
        //  genesis block for that token as this contains initial balance of
        //  this token
        if ((balances[_owner].length == 0) || (balances[_owner][0].fromBlock > _blockNumber)) {
            return 0;
        } else {
            // This will return the expected balance during normal situations
            return getValueAt(balances[_owner], _blockNumber);
        }
    }

    /// @notice Total amount of tokens at a specific `_blockNumber`.
    /// @param _blockNumber The block number when the totalSupply is queried
    /// @return The total amount of tokens at `_blockNumber`
    function totalSupplyAt(uint256 _blockNumber) public view returns(uint256) {
        // These next few lines are used when the totalSupply of the token is
        //  requested before a check point was ever created for this token, it
        //  requires that the `parentToken.totalSupplyAt` be queried at the
        //  genesis block for this token as that contains totalSupply of this
        //  token at this block number.
        if ((totalSupplyHistory.length == 0) || (totalSupplyHistory[0].fromBlock > _blockNumber)) {
            return 0;
        } else {
            // This will return the expected totalSupply during normal situations
            return getValueAt(totalSupplyHistory, _blockNumber);
        }
    }

////////////////
// Mint tokens
////////////////

    /// @notice Mints `_amount` tokens that are assigned to `_owner`
    /// @param _amount The quantity of tokens minted
    /// @param _owner The address that will be assigned the new tokens
    /// @return True if the tokens are minted correctly
    function mint(uint256 _amount, address _owner) public onlyController onlyValid returns (bool) {
        uint256 curTotalSupply = totalSupply();
        require(curTotalSupply + _amount >= curTotalSupply); // Check for overflow
        require(curTotalSupply + _amount <= mintCap); // Check if max amount of tokens is reachedCheck if max amount of tokens is reached
        uint256 previousBalanceTo = balanceOf(_owner);
        require(previousBalanceTo + _amount >= previousBalanceTo); // Check for overflow
        updateValueAtNow(totalSupplyHistory, curTotalSupply.add(_amount));
        updateValueAtNow(balances[_owner], previousBalanceTo.add(_amount));
        emit Transfer(address(0), _owner, _amount);
        return true;
    }
    
////////////////
// Enable tokens transfers, closing and validity check
////////////////

    /// @notice Enables token holders to transfer their tokens freely if true
    /// @param _transfersEnabled True if transfers are allowed in the clone
    function enableTransfers(bool _transfersEnabled) public onlyController {
        transfersEnabled = _transfersEnabled;
    }

    /// @notice Close the fund, can be called only once when fund matures
    function close() public onlyController {
        require(maturityDate <= now && active);
        active = false;
    }

    /// @notice Returns if fund is active or not
    /// @return True if fund is active or not closed
    function isActive() public view returns (bool) {
        return active;
    }

    /// @notice Checks if fund is active
    modifier onlyActive() {
        require(isActive());
        _;
    }

    /// @notice Checks if fund is valid or current time inside time boundaries
    function isValid() public view returns (bool) {
        return startDate <= now && maturityDate >= now;
    }

    /// @notice Checks if fund is active
    modifier onlyValid() {
        require(isValid());
        _;
    }

////////////////
// Internal helper functions to query and set a value in a snapshot array
////////////////

    /// @dev `getValueAt` retrieves the number of tokens at a given block number
    /// @param checkpoints The history of values being queried
    /// @param _block The block number to retrieve the value at
    /// @return The number of tokens being queried
    function getValueAt(Checkpoint[] storage checkpoints, uint256 _block) view internal returns (uint256) {
        if (checkpoints.length == 0) 
            return 0;

        // Shortcut for the actual value
        if (_block >= checkpoints[checkpoints.length - 1].fromBlock)
            return checkpoints[checkpoints.length - 1].value;
        if (_block < checkpoints[0].fromBlock)
            return 0;

        // Binary search of the value in the array
        uint min = 0;
        uint max = checkpoints.length - 1;
        while (max > min) {
            uint mid = (max + min + 1) / 2;
            if (checkpoints[mid].fromBlock <= _block) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return checkpoints[min].value;
    }

    /// @dev `updateValueAtNow` used to update the `balances` map and the
    ///  `totalSupplyHistory`
    /// @param checkpoints The history of data being updated
    /// @param _value The new number of tokens
    function updateValueAtNow(Checkpoint[] storage checkpoints, uint256 _value) internal  {
        if ((checkpoints.length == 0) || (checkpoints[checkpoints.length - 1].fromBlock < block.number)) {
            Checkpoint storage newCheckPoint = checkpoints[checkpoints.length++];
            newCheckPoint.fromBlock =  uint128(block.number);
            newCheckPoint.value = uint128(_value);
        } else {
            Checkpoint storage oldCheckPoint = checkpoints[checkpoints.length - 1];
            oldCheckPoint.value = uint128(_value);
        }
    }

    /// @dev fallback function which prohibits payment
    function () public payable {
        revert();
    }

//////////
// Safety Methods
//////////

    /// @notice This method can be used by the controller to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(address _token) public onlyController {
        if (_token == address(0)) {
            controller.transfer(address(this).balance);
            return;
        }

        HistoryToken token = HistoryToken(_token);
        uint balance = token.balanceOf(this);
        token.transfer(controller, balance);
        emit ClaimedTokens(_token, controller, balance);
    }

////////////////
// Events
////////////////

    event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);
}
