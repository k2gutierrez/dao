// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable } from "@Openzeppelin/contracts/access/Ownable.sol";
import { DAOGovernanceToken } from "./DAOGovernanceToken.sol";
import { IDAOTreasury } from "./interfaces/IDAOTreasury.sol";

/**
 * @title DAO
 * @author Carlos Gutiérrez
 * @dev Decentralized Autonomous Organization Contract
 * Handles proposals creation, voting and execution
 */
contract DAO is Ownable {

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
        address recipient;
        uint256 amount;
        address token;
        mapping(address => bool) hasVoted;
        mapping(address => bool) votedFor;
    }

    DAOGovernanceToken public s_governanceToken;
    IDAOTreasury public s_treasury;

    // DAO configuration
    uint256 s_proposalThreshold;
    uint256 s_votingPeriod;
    uint256 s_quorumVotes;

    // Proposal tracking
    uint256 public s_proposalCount;
    mapping(uint256 => Proposal) public s_proposals;

    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description, address recipient, uint256 amount, address token, uint256 startTime, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event ConfigurationUpdated(uint256 proposalThreshold, uint256 votingPeriod, uint256 quorumVotes);

    /**
     * @dev Constructor
     * @param owner address to assing as owner
     * @param governanceToken Address of the governance token contract
     * @param treasury Address of the DAOTreasury
     * @param proposalThreshold Minimum tokens required to create a proposal
     * @param votingPeriod Duration of hte voting period in seconds
     * @param quorumVotes Minimum vores required for proposal to pass
     */
    constructor(
        address owner, 
        address governanceToken, 
        address treasury,
        uint256 proposalThreshold, 
        uint256 votingPeriod,
        uint256 quorumVotes
    ) Ownable(owner) {
        s_governanceToken = DAOGovernanceToken(governanceToken);
        s_treasury = IDAOTreasury(treasury);
        s_proposalThreshold = proposalThreshold;
        s_votingPeriod = votingPeriod;
        s_quorumVotes = quorumVotes;
    }

    /**
     * @dev Create a new proposal
     * @param description Description of the proposal
     * @param recipient Address to receive funds if proposal passes
     * @param amount Amounts of funds to spend
     * @param token Token address (address(0) for ETH)
     * @return proposalId The ID of the created proposal
     */
    function createProposal(string memory description, address recipient, uint256 amount, address token) external returns(uint256 proposalId) {
        require(s_governanceToken.getVotingPower(msg.sender) >= s_proposalThreshold, "Insufficient voting power to create proposal");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(recipient != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than 0");

        proposalId = s_proposalCount++;
        Proposal storage proposal = s_proposals[proposalId];

        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.recipient = recipient;
        proposal.amount = amount;
        proposal.token = token;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + s_votingPeriod;
        proposal.executed = false;
        proposal.canceled = false;

        emit ProposalCreated(proposalId, proposal.proposer, proposal.description, proposal.recipient, proposal.amount, proposal.token, proposal.startTime, proposal.endTime);
    }

    /**
     * @dev Vote for a proposal
     * @param proposalId Id of the proposal to vote for
     * @param support True if yes, false if no
     */
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = s_proposals[proposalId];
        require(proposal.proposer != address(0), "Proposal does not exists");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp < proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.canceled, "Proposal has been canceled");
        require(!proposal.executed, "Proposal already executed");

        uint256 votes = s_governanceToken.getVotingPower(msg.sender);
        require(votes > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.votedFor[msg.sender] = support;

        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        emit Voted(proposalId, msg.sender, support, votes);
    }

    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = s_proposals[proposalId];

        require(proposal.proposer != address(0), "Proposal does not exists");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.canceled, "Proposal already canceled");
        require(msg.sender == proposal.proposer || msg.sender == owner(), "Not authorized to cancel");

        proposal.canceled = true;

        emit ProposalCanceled(proposalId);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = s_proposals[proposalId];

        require(proposal.proposer != address(0), "Proposal does not exists");
        require(block.timestamp >= proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.canceled, "Proposal is canceled");
        require(proposal.forVotes + proposal.againstVotes >= s_quorumVotes, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal not passed");

        proposal.executed = true;

        s_treasury.approveProposal(proposalId);

        s_treasury.spendFunds(proposalId, proposal.recipient, proposal.amount, proposal.token);

        emit ProposalExecuted(proposalId);

    }

    /**
     * @dev Get proposal details
     * @param proposalId ID of the proposal
     * @return proposer Address of the proposer
     * @return description Description of the proposal
     * @return forVotes Number of votes for the proposal
     * @return againstVotes Number of votes against the proposal
     * @return startTime Start time of voting
     * @return endTime End time of voting
     * @return executed Whether the proposal has been executed
     * @return canceled Whether the proposal has been canceled
     * @return recipient Address to receive funds
     * @return amount Amount of funds to be spent
     * @return token Token address for the proposal
     */
    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        bool canceled,
        address recipient,
        uint256 amount,
        address token
    ) {
        Proposal storage proposal = s_proposals[proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.canceled,
            proposal.recipient,
            proposal.amount,
            proposal.token
        );
    }
    
    /**
     * @dev Check if an address has voted on a proposal
     * @param proposalId ID of the proposal
     * @param voter Address to check
     * @return hasVoted Whether the address has voted
     * @return votedFor Whether the address voted for the proposal (only meaningful if hasVoted is true)
     */
    function getVoteInfo(uint256 proposalId, address voter) external view returns (bool hasVoted, bool votedFor) {
        Proposal storage proposal = s_proposals[proposalId];
        return (proposal.hasVoted[voter], proposal.votedFor[voter]);
    }
    
    /**
     * @dev Update DAO configuration (only owner)
     * @param proposalThreshold New proposal threshold
     * @param votingPeriod New voting period
     * @param quorumVotes New quorum votes
     */
    function updateConfiguration(
        uint256 proposalThreshold,
        uint256 votingPeriod,
        uint256 quorumVotes
    ) external onlyOwner {
        s_proposalThreshold = proposalThreshold;
        s_votingPeriod = votingPeriod;
        s_quorumVotes = quorumVotes;
        
        emit ConfigurationUpdated(proposalThreshold, votingPeriod, quorumVotes);
    }
    
    /**
     * @dev Set the treasury contract address (only owner)
     * @param _treasury New treasury contract address
     */
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury address");
        s_treasury = IDAOTreasury(_treasury);
    }
    
    /**
     * @dev Check if a proposal has passed
     * @param proposalId ID of the proposal
     * @return passed Whether the proposal has passed
     */
    function proposalPassed(uint256 proposalId) external view returns (bool passed) {
        Proposal storage proposal = s_proposals[proposalId];
        
        if (proposal.proposer == address(0) || proposal.canceled || proposal.executed) {
            return false;
        }
        
        if (block.timestamp < proposal.endTime) {
            return false; // Voting not ended
        }
        
        if (proposal.forVotes + proposal.againstVotes < s_quorumVotes) {
            return false; // Quorum not reached
        }
        
        return proposal.forVotes > proposal.againstVotes;
    }

}