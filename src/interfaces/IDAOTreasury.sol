// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IDAOTreasury {
    
    function approveProposal(uint256 proposalId) external;

    function spendFunds(uint256 proposalId, address recipient, uint256 amount, address token) external;

}