// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {DAOGovernanceToken} from "../src/DaoGovernanceToken.sol";
import {DAO} from "../src/DAO.sol";
import {DAOTreasury} from "../src/DAOTreasury.sol";
// import {DaoScript} from "../script/DaoScript.s.sol";

contract DaoTest is Test {
    
     // Test addresses
    address public owner = makeAddr("owner");
    address public user1 = address(2);
    address public user2 = address(3);
    address public user3 = address(4);
    address public delegate = address(5);
    
    // Contracts
    DAOGovernanceToken public governanceToken;
    DAO public dao;
    DAOTreasury public treasury;
    
    // Test parameters
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18; // 1M tokens
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18; // 1K tokens
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant QUORUM_VOTES = 10000 * 10**18; // 10K tokens

    // Events of DAOGovernanceToken
    event VotingPowerDelegated(address indexed delegator, address indexed delegate, uint256 amount);
    event VotingPowerUndelegated(address indexed delegator, address indexed delegate, uint256 amount);
    // Events of DAOTreasury
    event ProposalApproved(uint256 indexed proposalId);
    event FundsSpend(uint256 indexed proposalId, address indexed recipient, uint256 amount, address token);
    event TreasuryFunded(address indexed sender, uint256 amount);
    event DAOSet(address indexed dao);
    // Events of DAO
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description, address recipient, uint256 amount, address token, uint256 startTime, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event ConfigurationUpdated(uint256 proposalThreshold, uint256 votingPeriod, uint256 quorumVotes);

    function setUp() public {
        vm.startPrank(owner);
        governanceToken = new DAOGovernanceToken("DAO Token", "DAO", owner, INITIAL_SUPPLY);
        treasury = new DAOTreasury(owner, address(0));
        dao = new DAO(owner, address(governanceToken), address(treasury), PROPOSAL_THRESHOLD, VOTING_PERIOD, QUORUM_VOTES);
        treasury.setDAO(address(dao));
        

        // Distribute tokens to test users
        governanceToken.mint(user1, 50000 * 10**18);
        governanceToken.mint(user2, 30000 * 10**18);
        governanceToken.mint(user3, 20000 * 10**18);

        vm.stopPrank();
    }

    // Helper functions
    
    /**
     * @dev Helper function to create a proposal with default values
     * @param description Description of the proposal
     * @return proposalId The ID of the created proposal
     */
    function createTestProposalETH(string memory description, address user) internal returns (uint256 proposalId) {
        return dao.createProposal(
            description,
            user, // recipient
            1 ether, // amount: 1 ETH
            address(0) // token: ETH
        );
    }

    ////////// DAO Governance Token Tests //////////

    function testConstructor() external view {
        uint256 mintedTokensByOwner = governanceToken.balanceOf(owner);
        uint256 totalSupplyTokens = governanceToken.totalSupply();

        assertEq(owner, governanceToken.owner(), "Incorrect amount of tokens");
        assertEq(mintedTokensByOwner, INITIAL_SUPPLY, "Incorrect amount of tokens");
        assertEq(totalSupplyTokens,INITIAL_SUPPLY + 100_000e18, "Incorrect amount of tokens");
    }

    function testMintRevertsIfNotOwnerOfContract() external {
        address to = user2;
        uint256 amount = 4000e18;
        vm.prank(user1);
        vm.expectRevert();
        governanceToken.mint(to, amount);
    }

    function testMint() external {
        address to = user2;
        uint256 tokensUser2BeforeMint = governanceToken.balanceOf(to);
        uint256 amount = 4000e18;
        vm.prank(owner);
        governanceToken.mint(to, amount);

        uint256 tokensUser2AfterMint = governanceToken.balanceOf(to);

        assert(tokensUser2BeforeMint + amount == tokensUser2AfterMint);
        assertNotEq(tokensUser2BeforeMint, tokensUser2AfterMint);
    }

    function testBurnRevertsIfAddressZero() external {
        uint256 amount = 5000e18;
        vm.prank(address(0));
        vm.expectRevert();
        governanceToken.burn(amount);
    }

    function testBurn() external {
        uint256 tokenBalanceUser1BeforeBurn = governanceToken.balanceOf(user1);
        uint256 totalSupplyBeforeBurn = governanceToken.totalSupply();
        uint256 amount = 5000e18;
        vm.prank(user1);
        governanceToken.burn(amount);

        uint256 tokenBalanceUser1AfterBurn = governanceToken.balanceOf(user1);
        uint256 totalSupplyAfterBurn = governanceToken.totalSupply();

        assert(tokenBalanceUser1BeforeBurn - amount == tokenBalanceUser1AfterBurn);
        assertNotEq(tokenBalanceUser1BeforeBurn, tokenBalanceUser1AfterBurn);
        assertNotEq(totalSupplyBeforeBurn, totalSupplyAfterBurn);
    }

    function testDelegateVotingPower() external {
        // User1 will delegate 50% of voting power to address delegate
        uint256 user1TokenBalance = governanceToken.balanceOf(user1);
        uint256 amountToDelegate = user1TokenBalance * 50 / 100;
        console2.log("Token Balance user1: ", user1TokenBalance);
        console2.log("amount to delegate by user1: ", amountToDelegate);

        uint256 delegateTokenBalance = governanceToken.balanceOf(delegate);

        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit VotingPowerDelegated(user1, delegate, amountToDelegate);
        governanceToken.delegateVotingPower(delegate, amountToDelegate);
        vm.stopPrank();

        uint256 user1TokenBalanceAfterDelegate = governanceToken.balanceOf(user1);
        uint256 delegateTokenBalanceAfterDelegation = governanceToken.balanceOf(delegate);
        
        uint256 votingPowerUser1 = governanceToken.getVotingPower(user1); 
        uint256 votingPowerDelegate = governanceToken.getVotingPower(delegate); 

        bool hasDelegatedStatus = governanceToken.getHasDelegatedStatus(user1);
        address newDelegate = governanceToken.getDelegates(user1);
        uint256 delegatedVotes = governanceToken.getDelegatedVotes(delegate);

        assertNotEq(user1TokenBalance, user1TokenBalanceAfterDelegate);
        assertNotEq(delegateTokenBalance, delegateTokenBalanceAfterDelegation);
        assert(delegateTokenBalanceAfterDelegation == amountToDelegate);
        assert(user1TokenBalance - amountToDelegate == user1TokenBalanceAfterDelegate);
        assertTrue(hasDelegatedStatus);
        assertEq(newDelegate, delegate);
        assertEq(delegatedVotes, amountToDelegate);

        assertEq(votingPowerUser1, user1TokenBalanceAfterDelegate);
        assertEq(votingPowerDelegate, delegateTokenBalanceAfterDelegation);
    }

    function testDelegateVotingPowerRevertsDelegateIsAddressZero() external {
        // User1 will delegate 50% of voting power to address delegate
        uint256 user1TokenBalance = governanceToken.balanceOf(user1);
        uint256 amountToDelegate = user1TokenBalance * 50 / 100;
        console2.log("Token Balance user1: ", user1TokenBalance);
        console2.log("amount to delegate by user1: ", amountToDelegate);


        vm.prank(user1);
        vm.expectRevert("Cannot delegate to zero address");
        governanceToken.delegateVotingPower(address(0), amountToDelegate);   
    }

    function testDelegateVotingPowerRevertsCannotDelegateToSelf() external {
        // User1 will delegate 50% of voting power to address delegate
        uint256 user1TokenBalance = governanceToken.balanceOf(user1);
        uint256 amountToDelegate = user1TokenBalance * 50 / 100;
        console2.log("Token Balance user1: ", user1TokenBalance);
        console2.log("amount to delegate by user1: ", amountToDelegate);


        vm.prank(user1);
        vm.expectRevert("Cannot delegate to self");
        governanceToken.delegateVotingPower(user1, amountToDelegate);   
    }

    function testDelegateVotingPowerRevertsAmountCannotBeZero() external {
        // User1 will delegate 50% of voting power to address delegate
        uint256 user1TokenBalance = governanceToken.balanceOf(user1);
        uint256 amountToDelegate = 0;
        console2.log("Token Balance user1: ", user1TokenBalance);
        console2.log("amount to delegate by user1: ", amountToDelegate);


        vm.prank(user1);
        vm.expectRevert("Amount must be greater than 0");
        governanceToken.delegateVotingPower(delegate, amountToDelegate);   
    }

    function testDelegateVotingPowerRevertsInsufficientBalance() external {
        // User1 will delegate 50% of voting power to address delegate
        uint256 user1TokenBalance = governanceToken.balanceOf(user1);
        uint256 amountToDelegate = user1TokenBalance * 2;
        console2.log("Token Balance user1: ", user1TokenBalance);
        console2.log("amount to delegate by user1: ", amountToDelegate);


        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        governanceToken.delegateVotingPower(delegate, amountToDelegate);   
    }

    function testUndelegateVotingPowerWholeVotingPower() external {
        // User1 will delegate 50% of voting power to address delegate
        uint256 user1TokenBalance = governanceToken.balanceOf(user1);
        uint256 amountToDelegate = user1TokenBalance * 50 / 100;
        console2.log("Token Balance user1: ", user1TokenBalance);
        console2.log("amount to delegate by user1: ", amountToDelegate);

        uint256 delegateTokenBalance = governanceToken.balanceOf(delegate);

        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit VotingPowerDelegated(user1, delegate, amountToDelegate);
        governanceToken.delegateVotingPower(delegate, amountToDelegate);
        vm.stopPrank();

        uint256 user1TokenBalanceAfterDelegate = governanceToken.balanceOf(user1);
        uint256 delegateTokenBalanceAfterDelegation = governanceToken.balanceOf(delegate);
        
        uint256 votingPowerUser1 = governanceToken.getVotingPower(user1); 
        uint256 votingPowerDelegate = governanceToken.getVotingPower(delegate); 

        bool hasDelegatedStatus = governanceToken.getHasDelegatedStatus(user1);
        address newDelegate = governanceToken.getDelegates(user1);
        uint256 delegatedVotes = governanceToken.getDelegatedVotes(delegate);

        assertNotEq(user1TokenBalance, user1TokenBalanceAfterDelegate);
        assertNotEq(delegateTokenBalance, delegateTokenBalanceAfterDelegation);
        assert(delegateTokenBalanceAfterDelegation == amountToDelegate);
        assert(user1TokenBalance - amountToDelegate == user1TokenBalanceAfterDelegate);
        assertTrue(hasDelegatedStatus);
        assertEq(newDelegate, delegate);
        assertEq(delegatedVotes, amountToDelegate);

        assertEq(votingPowerUser1, user1TokenBalanceAfterDelegate);
        assertEq(votingPowerDelegate, delegateTokenBalanceAfterDelegation);

        // User1 will undelegate the voting power to the delegate
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit VotingPowerUndelegated(user1, delegate, amountToDelegate);
        governanceToken.undelegateVotingPower(amountToDelegate);
        vm.stopPrank();

        bool user1HasDelegatedStatus = governanceToken.getHasDelegatedStatus(user1);
        uint256 delegateVotingPower = governanceToken.getVotingPower(delegate);
        uint256 user1VotingPower = governanceToken.getVotingPower(user1);
        address user1Delegate = governanceToken.getDelegates(user1);

        assertFalse(user1HasDelegatedStatus);
        assert(delegateVotingPower == 0);
        assertEq(user1VotingPower, user1TokenBalance);
        assert(user1Delegate == address(0));

    }

    function testUndelegateVotingPowerHalfVotingPower() external {
        // User1 will delegate 50% of voting power to address delegate
        uint256 user1TokenBalance = governanceToken.balanceOf(user1);
        uint256 amountToDelegate = user1TokenBalance * 50 / 100;
        console2.log("Token Balance user1: ", user1TokenBalance);
        console2.log("amount to delegate by user1: ", amountToDelegate);

        uint256 delegateTokenBalance = governanceToken.balanceOf(delegate);

        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit VotingPowerDelegated(user1, delegate, amountToDelegate);
        governanceToken.delegateVotingPower(delegate, amountToDelegate);
        vm.stopPrank();

        uint256 user1TokenBalanceAfterDelegate = governanceToken.balanceOf(user1);
        uint256 delegateTokenBalanceAfterDelegation = governanceToken.balanceOf(delegate);
        
        uint256 votingPowerUser1 = governanceToken.getVotingPower(user1); 
        uint256 votingPowerDelegate = governanceToken.getVotingPower(delegate); 

        bool hasDelegatedStatus = governanceToken.getHasDelegatedStatus(user1);
        address newDelegate = governanceToken.getDelegates(user1);
        uint256 delegatedVotes = governanceToken.getDelegatedVotes(delegate);

        assertNotEq(user1TokenBalance, user1TokenBalanceAfterDelegate);
        assertNotEq(delegateTokenBalance, delegateTokenBalanceAfterDelegation);
        assert(delegateTokenBalanceAfterDelegation == amountToDelegate);
        assert(user1TokenBalance - amountToDelegate == user1TokenBalanceAfterDelegate);
        assertTrue(hasDelegatedStatus);
        assertEq(newDelegate, delegate);
        assertEq(delegatedVotes, amountToDelegate);

        assertEq(votingPowerUser1, user1TokenBalanceAfterDelegate);
        assertEq(votingPowerDelegate, delegateTokenBalanceAfterDelegation);

        // User1 will undelegate the voting power to the delegate
        uint256 undelegateAmount = amountToDelegate * 50 / 100;

        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit VotingPowerUndelegated(user1, delegate, undelegateAmount);
        governanceToken.undelegateVotingPower(undelegateAmount);
        vm.stopPrank();

        bool user1HasDelegatedStatus = governanceToken.getHasDelegatedStatus(user1);
        uint256 delegateVotingPower = governanceToken.getVotingPower(delegate);
        uint256 user1VotingPower = governanceToken.getVotingPower(user1);
        address user1Delegate = governanceToken.getDelegates(user1);

        assertTrue(user1HasDelegatedStatus);
        assert(delegateVotingPower == votingPowerDelegate - undelegateAmount);
        assertEq(votingPowerUser1 + undelegateAmount, user1VotingPower);
        assert(user1Delegate == delegate);

    }

    function testUndelegateVotingPowerRevertsNoDelegationFound() external {
        // User1 will delegate 50% of voting power to address delegate
        uint256 user1TokenBalance = governanceToken.balanceOf(user1);
        uint256 amountToDelegate = user1TokenBalance * 50 / 100;

        // User1 will undelegate the voting power to the delegate
        uint256 undelegateAmount = amountToDelegate * 50 / 100;

        vm.startPrank(user1);
        vm.expectRevert("No delegation found");
        governanceToken.undelegateVotingPower(undelegateAmount);
        vm.stopPrank();

    }

    function testUndelegateVotingPowerRevertsAmountZero() external {
        // User1 will delegate 50% of voting power to address delegate
        uint256 user1TokenBalance = governanceToken.balanceOf(user1);
        uint256 amountToDelegate = user1TokenBalance * 50 / 100;
        console2.log("Token Balance user1: ", user1TokenBalance);
        console2.log("amount to delegate by user1: ", amountToDelegate);

        uint256 delegateTokenBalance = governanceToken.balanceOf(delegate);

        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit VotingPowerDelegated(user1, delegate, amountToDelegate);
        governanceToken.delegateVotingPower(delegate, amountToDelegate);
        vm.stopPrank();

        uint256 user1TokenBalanceAfterDelegate = governanceToken.balanceOf(user1);
        uint256 delegateTokenBalanceAfterDelegation = governanceToken.balanceOf(delegate);
        
        uint256 votingPowerUser1 = governanceToken.getVotingPower(user1); 
        uint256 votingPowerDelegate = governanceToken.getVotingPower(delegate); 

        bool hasDelegatedStatus = governanceToken.getHasDelegatedStatus(user1);
        address newDelegate = governanceToken.getDelegates(user1);
        uint256 delegatedVotes = governanceToken.getDelegatedVotes(delegate);

        assertNotEq(user1TokenBalance, user1TokenBalanceAfterDelegate);
        assertNotEq(delegateTokenBalance, delegateTokenBalanceAfterDelegation);
        assert(delegateTokenBalanceAfterDelegation == amountToDelegate);
        assert(user1TokenBalance - amountToDelegate == user1TokenBalanceAfterDelegate);
        assertTrue(hasDelegatedStatus);
        assertEq(newDelegate, delegate);
        assertEq(delegatedVotes, amountToDelegate);

        assertEq(votingPowerUser1, user1TokenBalanceAfterDelegate);
        assertEq(votingPowerDelegate, delegateTokenBalanceAfterDelegation);

        // User1 will undelegate the voting power to the delegate
        uint256 undelegateAmount = amountToDelegate * 50 / 100;

        vm.startPrank(user1);
        vm.expectRevert("Amount must be greater than 0");
        governanceToken.undelegateVotingPower(undelegateAmount * 0);
        vm.stopPrank();

    }

    function testUndelegateVotingPowerRevertsInsufficientDelegateAmount() external {
        // User1 will delegate 50% of voting power to address delegate
        uint256 user1TokenBalance = governanceToken.balanceOf(user1);
        uint256 amountToDelegate = user1TokenBalance * 50 / 100;
        console2.log("Token Balance user1: ", user1TokenBalance);
        console2.log("amount to delegate by user1: ", amountToDelegate);

        uint256 delegateTokenBalance = governanceToken.balanceOf(delegate);

        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit VotingPowerDelegated(user1, delegate, amountToDelegate);
        governanceToken.delegateVotingPower(delegate, amountToDelegate);
        vm.stopPrank();

        uint256 user1TokenBalanceAfterDelegate = governanceToken.balanceOf(user1);
        uint256 delegateTokenBalanceAfterDelegation = governanceToken.balanceOf(delegate);
        
        uint256 votingPowerUser1 = governanceToken.getVotingPower(user1); 
        uint256 votingPowerDelegate = governanceToken.getVotingPower(delegate); 

        bool hasDelegatedStatus = governanceToken.getHasDelegatedStatus(user1);
        address newDelegate = governanceToken.getDelegates(user1);
        uint256 delegatedVotes = governanceToken.getDelegatedVotes(delegate);

        assertNotEq(user1TokenBalance, user1TokenBalanceAfterDelegate);
        assertNotEq(delegateTokenBalance, delegateTokenBalanceAfterDelegation);
        assert(delegateTokenBalanceAfterDelegation == amountToDelegate);
        assert(user1TokenBalance - amountToDelegate == user1TokenBalanceAfterDelegate);
        assertTrue(hasDelegatedStatus);
        assertEq(newDelegate, delegate);
        assertEq(delegatedVotes, amountToDelegate);

        assertEq(votingPowerUser1, user1TokenBalanceAfterDelegate);
        assertEq(votingPowerDelegate, delegateTokenBalanceAfterDelegation);

        // User1 will undelegate the voting power to the delegate

        vm.startPrank(user1);
        vm.expectRevert("Insufficient delegated amount");
        governanceToken.undelegateVotingPower(amountToDelegate * 2);
        vm.stopPrank();
    }

    ////////// DAO Treasury Tests //////////

    function testSetDAO() external {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit DAOSet(user1);
        treasury.setDAO(user1);
        
        assertEq(address(treasury.dao()), user1, "DAO address not updated correctly");
    }

    function testSetDAORevertsIfZeroAddress() external {
        vm.prank(owner);
        vm.expectRevert("Invalid DAO address");
        treasury.setDAO(address(0));
    }

    function testFundTreasuryETH() external {
        uint256 fundAmount = 5 ether;
        vm.deal(user1, fundAmount);
        
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit TreasuryFunded(user1, fundAmount);
        treasury.fundTreasury{value: fundAmount}();

        assertEq(address(treasury).balance, fundAmount, "Treasury ETH balance incorrect");
    }

    function testTreasuryApproveProposalRevertsIfNotDAO() external {
        vm.prank(user1);
        vm.expectRevert("Only DAO can approve proposals");
        treasury.approveProposal(1);
    }

    function testTreasurySpendFundsRevertsIfNotDAO() external {
        vm.prank(user1);
        vm.expectRevert("Only DAO can spend funds");
        treasury.spendFunds(1, user2, 1 ether, address(0));
    }

    function testEmergencyWithdrawETH() external {
        uint256 fundAmount = 10 ether;
        vm.deal(address(treasury), fundAmount);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        treasury.emergencyWithdraw(address(0), fundAmount, owner);

        assertEq(owner.balance, ownerBalanceBefore + fundAmount, "Emergency withdraw failed");
        assertEq(address(treasury).balance, 0, "Treasury should be empty");
    }

    function testReceiveFallback() external {
        uint256 fundAmount = 2 ether;
        vm.deal(user1, fundAmount);
        
        vm.prank(user1);
        (bool success, ) = address(treasury).call{value: fundAmount}("");
        assertTrue(success, "Receive ETH failed");
        assertEq(address(treasury).balance, fundAmount, "Treasury balance incorrect");
    }

    function testFundTreasuryWithToken() external {
        uint256 fundAmount = 5000 * 10**18;
        
        // Prank as user1 to fund the treasury with Governance Tokens
        vm.startPrank(user1);
        governanceToken.approve(address(treasury), fundAmount);
        
        vm.expectEmit(true, false, false, true);
        emit TreasuryFunded(user1, fundAmount);
        treasury.fundTreasuryWithToken(address(governanceToken), fundAmount);
        vm.stopPrank();

        assertEq(governanceToken.balanceOf(address(treasury)), fundAmount, "Token funding failed");
    }

    function testFundTreasuryWithTokenReverts() external {
        vm.startPrank(user1);
        vm.expectRevert("Invalid token address");
        treasury.fundTreasuryWithToken(address(0), 100);

        vm.expectRevert("Amount must be greater than 0");
        treasury.fundTreasuryWithToken(address(governanceToken), 0);
        vm.stopPrank();
    }

    function testTreasuryApproveRevertsAlreadyApproved() external {
        vm.startPrank(address(dao));
        treasury.approveProposal(1);
        
        vm.expectRevert("Proposal already approved");
        treasury.approveProposal(1);
        vm.stopPrank();
    }

    function testTreasurySpendFundsReverts() external {
        vm.startPrank(address(dao));
        
        // 1. Not approved
        vm.expectRevert("Proposal not approved");
        treasury.spendFunds(2, user2, 1 ether, address(0));

        // 2. Invalid recipient and zero amount
        treasury.approveProposal(2);
        vm.expectRevert("Invalid recipient");
        treasury.spendFunds(2, address(0), 1 ether, address(0));
        
        vm.expectRevert("Amount must be greater than 0");
        treasury.spendFunds(2, user2, 0, address(0));

        // 3. Insufficient ETH
        vm.expectRevert("Insufficient ETH balance");
        treasury.spendFunds(2, user2, 1 ether, address(0));
        vm.stopPrank();
    }

    function testTreasurySpendFundsERC20() external {
        uint256 amount = 1000 * 10**18;
        
        // Fund Treasury
        vm.prank(user1);
        governanceToken.transfer(address(treasury), amount);

        uint256 user2TokenBalanceBefore = governanceToken.balanceOf(user2);

        // Prank as DAO to approve and spend
        vm.startPrank(address(dao));
        treasury.approveProposal(99);
        treasury.spendFunds(99, user2, amount, address(governanceToken));
        vm.stopPrank();

        assertEq(governanceToken.balanceOf(user2), user2TokenBalanceBefore + amount, "ERC20 spend failed");

        // Attempting to spend again should revert
        vm.prank(address(dao));
        vm.expectRevert("Proposal already executed");
        treasury.spendFunds(99, user2, amount, address(governanceToken));
    }

    function testEmergencyWithdrawERC20() external {
        uint256 amount = 5000 * 10**18;
        
        // Fund Treasury
        vm.prank(user1);
        governanceToken.transfer(address(treasury), amount);

        uint256 ownerTokenBalanceBefore = governanceToken.balanceOf(owner);

        vm.prank(owner);
        treasury.emergencyWithdraw(address(governanceToken), amount, owner);

        assertEq(governanceToken.balanceOf(owner), ownerTokenBalanceBefore + amount, "Emergency ERC20 withdraw failed");
        assertEq(governanceToken.balanceOf(address(treasury)), 0, "Treasury token balance should be empty");
    }

    function testEmergencyWithdrawReverts() external {
        vm.startPrank(owner);
        
        vm.expectRevert("Invalid recipient");
        treasury.emergencyWithdraw(address(0), 1 ether, address(0));

        vm.expectRevert("Amount must be greater than 0");
        treasury.emergencyWithdraw(address(0), 0, owner);
        
        vm.stopPrank();
    }

    ////////// DAO Tests //////////

    function testCreateProposal() external {
        vm.startPrank(user1);
        
        uint256 expectedId = dao.s_proposalCount();
        
        vm.expectEmit(true, true, false, false);
        // Only checking indexed params and assuming timestamp match
        emit ProposalCreated(expectedId, user1, "Fund Marketing", user2, 1 ether, address(0), block.timestamp, block.timestamp + VOTING_PERIOD);
        
        uint256 proposalId = dao.createProposal("Fund Marketing", user2, 1 ether, address(0));
        vm.stopPrank();

        assertEq(proposalId, expectedId, "Proposal ID mismatch");
        assertEq(dao.s_proposalCount(), expectedId + 1, "Proposal count not incremented");
        
        (address proposer, string memory desc, , , , , bool executed, bool canceled, address recipient, uint256 amount, ) = dao.getProposal(proposalId);
        
        assertEq(proposer, user1, "Proposer mismatch");
        assertEq(desc, "Fund Marketing", "Description mismatch");
        assertEq(recipient, user2, "Recipient mismatch");
        assertEq(amount, 1 ether, "Amount mismatch");
        assertFalse(executed, "Should not be executed");
        assertFalse(canceled, "Should not be canceled");
    }

    function testCreateProposalRevertsInsufficientVotingPower() external {
        // User3 has 20,000e18 tokens in setup, so let's use an account with 0 tokens
        address noTokenUser = address(6);
        
        vm.prank(noTokenUser);
        vm.expectRevert("Insufficient voting power to create proposal");
        dao.createProposal("Fund Marketing", user2, 1 ether, address(0));
    }

    function testVote() external {
        vm.prank(user1);
        uint256 proposalId = createTestProposalETH("Test Vote", user2);

        // Cache the balance BEFORE the prank or expectEmit to avoid consuming it
        uint256 user2Votes = governanceToken.balanceOf(user2);

        // Use startPrank to ensure all subsequent calls belong to user2
        vm.startPrank(user2);
        
        vm.expectEmit(true, true, false, true);
        emit Voted(proposalId, user2, true, user2Votes);
        dao.vote(proposalId, true);
        
        vm.stopPrank();

        (bool hasVoted, bool votedFor) = dao.getVoteInfo(proposalId, user2);
        assertTrue(hasVoted, "User2 should have voted status");
        assertTrue(votedFor, "User2 should have voted FOR");

        (,, uint256 forVotes, uint256 againstVotes,,,,,,,) = dao.getProposal(proposalId);
        assertEq(forVotes, user2Votes, "For votes not tallied correctly");
        assertEq(againstVotes, 0, "Against votes should be 0");
    }

    function testVoteRevertsIfVotingEnded() external {
        vm.prank(user1);
        uint256 proposalId = createTestProposalETH("Test End Vote", user2);

        // Fast forward past the voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.prank(user2);
        vm.expectRevert("Voting ended");
        dao.vote(proposalId, true);
    }

    function testCancelProposal() external {
        vm.prank(user1);
        uint256 proposalId = createTestProposalETH("Test Cancel", user2);

        vm.prank(user1);
        vm.expectEmit(true, false, false, false);
        emit ProposalCanceled(proposalId);
        dao.cancelProposal(proposalId);

        (,,,,,,, bool canceled,,,) = dao.getProposal(proposalId);
        assertTrue(canceled, "Proposal should be canceled");
    }

    function testExecuteProposalSuccessfully() external {
        // 1. Fund the Treasury
        vm.deal(address(treasury), 10 ether);

        // 2. Create Proposal (User1)
        vm.prank(user1);
        uint256 proposalId = createTestProposalETH("Fund Devs", user2);

        // 3. Vote (User1 & User2 pass it)
        vm.prank(user1);
        dao.vote(proposalId, true);
        
        vm.prank(user2);
        dao.vote(proposalId, true);

        // 4. Fast forward time so voting ends
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        uint256 user2BalanceBefore = user2.balance;

        // 5. Execute
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit ProposalExecuted(proposalId);
        dao.executeProposal(proposalId);

        // 6. Verify state
        (,,,,,, bool executed,,,,) = dao.getProposal(proposalId);
        assertTrue(executed, "Proposal should be marked as executed");
        assertEq(user2.balance, user2BalanceBefore + 1 ether, "Recipient did not receive funds");
    }
    
    function testExecuteProposalRevertsQuorumNotReached() external {
        vm.prank(user1);
        uint256 proposalId = createTestProposalETH("Fund Devs", user2);

        // User3 votes, but User3 only has 20,000 tokens. Wait, QUORUM is 10,000e18. 
        // We need someone with less than Quorum. Let's mint exactly 1000e18 to a new user.
        address tinyHolder = address(7);
        vm.prank(owner);
        governanceToken.mint(tinyHolder, 1000 * 10**18);

        vm.prank(tinyHolder);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.prank(owner);
        vm.expectRevert("Quorum not reached");
        dao.executeProposal(proposalId);
    }

    function testUpdateConfiguration() external {
        uint256 newThreshold = 2000 * 10**18;
        uint256 newPeriod = 14 days;
        uint256 newQuorum = 20000 * 10**18;

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit ConfigurationUpdated(newThreshold, newPeriod, newQuorum);
        dao.updateConfiguration(newThreshold, newPeriod, newQuorum);
    }

    function testCreateProposalReverts() external {
        vm.startPrank(user1);
        
        vm.expectRevert("Description cannot be empty");
        dao.createProposal("", user2, 1 ether, address(0));

        vm.expectRevert("Invalid recipient address");
        dao.createProposal("Desc", address(0), 1 ether, address(0));

        vm.expectRevert("Amount must be greater than 0");
        dao.createProposal("Desc", user2, 0, address(0));
        
        vm.stopPrank();
    }

    function testSetTreasury() external {
        vm.prank(owner);
        dao.setTreasury(address(0x123));
        assertEq(address(dao.s_treasury()), address(0x123), "Treasury not set");

        vm.prank(owner);
        vm.expectRevert("Invalid treasury address");
        dao.setTreasury(address(0));
    }

    function testVoteAgainst() external {
        vm.prank(user1);
        uint256 proposalId = createTestProposalETH("Desc", user2);
        
        uint256 user2Votes = governanceToken.balanceOf(user2);
        
        vm.prank(user2);
        dao.vote(proposalId, false); // Support = false

        (,, uint256 forVotes, uint256 againstVotes,,,,,,,) = dao.getProposal(proposalId);
        assertEq(forVotes, 0, "For votes should be 0");
        assertEq(againstVotes, user2Votes, "Against votes incorrect");
    }

    function testVoteReverts() external {
        vm.prank(user1);
        uint256 proposalId = createTestProposalETH("Desc", user2);

        // 1. Proposal does not exist
        vm.prank(user2);
        vm.expectRevert("Proposal does not exists");
        dao.vote(999, true);

        // 2. Already Voted
        vm.startPrank(user2);
        dao.vote(proposalId, true);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, true);
        vm.stopPrank();

        // 3. Canceled Proposal
        vm.prank(user1);
        uint256 proposalId2 = createTestProposalETH("Desc 2", user2);
        vm.prank(user1);
        dao.cancelProposal(proposalId2);
        
        vm.prank(user2);
        vm.expectRevert("Proposal has been canceled");
        dao.vote(proposalId2, true);
    }

    function testCancelProposalReverts() external {
        vm.prank(user1);
        uint256 proposalId = createTestProposalETH("Desc", user2);

        // 1. Does not exist
        vm.prank(user1);
        vm.expectRevert("Proposal does not exists");
        dao.cancelProposal(999);

        // 2. Not authorized (user2 is not proposer or owner)
        vm.prank(user2);
        vm.expectRevert("Not authorized to cancel");
        dao.cancelProposal(proposalId);

        // 3. Already canceled
        vm.prank(user1);
        dao.cancelProposal(proposalId);
        vm.prank(user1);
        vm.expectRevert("Proposal already canceled");
        dao.cancelProposal(proposalId);
    }

    function testExecuteProposalReverts() external {
        vm.prank(user1);
        uint256 proposalId = createTestProposalETH("Desc", user2);

        // 1. Does not exist
        vm.expectRevert("Proposal does not exists");
        dao.executeProposal(999);

        // 2. Voting not ended
        vm.expectRevert("Voting not ended");
        dao.executeProposal(proposalId);

        // 3. Proposal Canceled
        vm.prank(user1);
        dao.cancelProposal(proposalId);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.expectRevert("Proposal is canceled");
        dao.executeProposal(proposalId);
        
        // 4. Proposal Not Passed (More against than for)
        vm.prank(user1);
        uint256 proposalId2 = createTestProposalETH("Desc 2", user2);
        
        vm.prank(user1);
        dao.vote(proposalId2, false); // Vote Against
        vm.prank(user2);
        dao.vote(proposalId2, false); // Vote Against
        
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.expectRevert("Proposal not passed");
        dao.executeProposal(proposalId2);
    }

    function testProposalPassedView() external {
        vm.prank(user1);
        uint256 proposalId = createTestProposalETH("Desc", user2);

        assertFalse(dao.proposalPassed(999), "Non-existent proposal should be false");
        assertFalse(dao.proposalPassed(proposalId), "Voting not ended should return false");

        // Fast forward with no votes (No Quorum)
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        assertFalse(dao.proposalPassed(proposalId), "Quorum not reached should return false");

        // Passed successfully
        vm.prank(user1);
        uint256 proposalId2 = createTestProposalETH("Desc 2", user2);
        vm.prank(user1);
        dao.vote(proposalId2, true);
        vm.prank(user2);
        dao.vote(proposalId2, true);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        assertTrue(dao.proposalPassed(proposalId2), "Should return true when passed");
        
        // Execute and check again
        vm.deal(address(treasury), 10 ether);
        dao.executeProposal(proposalId2);
        assertFalse(dao.proposalPassed(proposalId2), "Already executed should return false");
    }

}
