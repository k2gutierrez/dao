// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "../lib/forge-std/src/Script.sol";
import {DAOGovernanceToken} from "../src/DAOGovernanceToken.sol";
import {DAO} from "../src/DAO.sol";
import {DAOTreasury} from "../src/DAOTreasury.sol";

contract DaoScript is Script {
    DAOGovernanceToken public daoToken;
    DAO public dao;
    DAOTreasury public treasury;

    address owner = makeAddr("owner");

    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18; // 1M tokens
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18; // 1K tokens
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant QUORUM_VOTES = 10000 * 10**18; // 10K tokens

    // function setUp() public {}

    function run() public returns(DAOGovernanceToken, DAO, DAOTreasury) {
        vm.startBroadcast();

        daoToken = new DAOGovernanceToken("DAO Token", "DAO", owner, INITIAL_SUPPLY);

        treasury = new DAOTreasury(owner, address(0));

        dao = new DAO(owner, address(daoToken), address(treasury), PROPOSAL_THRESHOLD, VOTING_PERIOD, QUORUM_VOTES);

        vm.stopBroadcast();

        vm.prank(owner);
        // Set DAO address in treasury
        treasury.setDAO(address(dao));

        return (daoToken, dao, treasury);
    }
}
