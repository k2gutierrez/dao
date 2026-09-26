// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Dao Governance Token
 * @author Carlos Gutiérrez
 * @notice ERC20 token used for DAO governance voting
 * This token represents voting power in the DAO
 */
contract DAOGovernanceToken is ERC20, Ownable {
    // True if if msg.sender has delegated voting power, false if not
    mapping(address => bool) private s_hasDelegated;

    // Address you delegate voting power
    mapping(address => address) private s_delegates;

    // Amount of voting power you delegate
    mapping(address => uint256) private s_delegatedVotes;

    event VotingPowerDelegated(address indexed delegator, address indexed delegate, uint256 amount);
    event VotingPowerUndelegated(address indexed delegator, address indexed delegate, uint256 amount);

    /**
     * @dev Constructor gives owner all the initial tokens
     * @param name Token name
     * @param symbol Token symbol
     * @param owner Owner of this smart contract
     * @param initialSupply Initial token supply
     */
    constructor(string memory name, string memory symbol, address owner, uint256 initialSupply)
        ERC20(name, symbol)
        Ownable(owner)
    {
        _mint(owner, initialSupply);
    }

    /**
     * @dev Mint function
     * @param to Address that will receive ERC20 tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Burn function
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Delegate voting power to another address
     * @param delegate Address to delegate voting power
     * @param amount Amount of tokens to delegate
     */
    function delegateVotingPower(address delegate, uint256 amount) external {
        require(delegate != address(0), "Cannot delegate to zero address");
        require(delegate != msg.sender, "Cannot delegate to self");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        _transfer(msg.sender, delegate, amount);

        s_delegates[msg.sender] = delegate;
        s_delegatedVotes[delegate] += amount;
        s_hasDelegated[msg.sender] = true;

        emit VotingPowerDelegated(msg.sender, delegate, amount);
    }

    /**
     * @dev Undelegate voting power from delegate
     * @param amount Amount of tokens to undelegate
     */
    function undelegateVotingPower(uint256 amount) external {
        require(s_hasDelegated[msg.sender], "No delegation found");
        require(amount > 0, "Amount must be greater than 0");
        require(s_delegatedVotes[s_delegates[msg.sender]] >= amount, "Insufficient delegated amount");

        address delegate = s_delegates[msg.sender];
        _transfer(delegate, msg.sender, amount);

        s_delegatedVotes[delegate] -= amount;

        if (s_delegatedVotes[delegate] == 0) {
            s_hasDelegated[msg.sender] = false;
            delete s_delegates[msg.sender];
        }

        emit VotingPowerUndelegated(msg.sender, delegate, amount);
    }

    // Getter functions
    /**
     * @dev Get the voting power of an address (including delegated votes)
     * @param account Address to check voting power
     * @return Total voting power
     */
    function getVotingPower(address account) external view returns (uint256) {
        return balanceOf(account);
    }

    /**
     * @dev Getter function to check if the address has delegated voting power
     * @param user address to check if has delegated voting power
     * @return bool true if has delegated voting power, false if not
     */
    function getHasDelegatedStatus(address user) external view returns (bool) {
        return s_hasDelegated[user];
    }

    /**
     * @dev Get the address delegated by user address
     * @param user address of the delegator to get the address that has been delegated voting power
     * @return address user that receives voting power
     */
    function getDelegates(address user) external view returns (address) {
        return s_delegates[user];
    }

    /**
     * @dev Returns the amount of delegated votes
     * @param user address that has receive voting power
     * @return uint256 Amount of tokens / voting power received
     */
    function getDelegatedVotes(address user) external view returns (uint256) {
        return s_delegatedVotes[user];
    }
}
