// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


/** @title Shojiru Token
    @author Shojiru Team
**/
contract Shojiru is ERC20("Test", "TEST"), AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev The constructor sets the creator of the contract as admin
    constructor() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
    @notice Change the admin of the contract. 
    @dev You should set it to a timelock after  
    @dev Revokes the old admin (there can be only one admin at a time)
    @dev You need to be admin to execute it
    @param newAdmin Address that will be used to set the new admin
    **/
    function changeAdmin(address newAdmin) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
    @notice Give the minting rights to a new address
    @dev You need to be admin to execute it
    @param newMinter Address that will be used to set the new minter
    **/
    function grantMinterRole(address newMinter) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        grantRole(MINTER_ROLE, newMinter);
    }

    /**
    @notice Remove the minting rights of a minter address
    @dev You need to be admin to execute it
    @param oldMinter Address that will be used to revoke the rights
    **/
    function revokeMinterRole(address oldMinter) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        revokeRole(MINTER_ROLE, oldMinter);
    }

    /**
    @notice Mint a specified amount of tokens
    @dev You need to be minter to execute it
    @param _to Address that will be get the tokens
    @param _amount Amount of tokens minted
    **/
    function mint(address _to, uint256 _amount) public {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _mint(_to, _amount);
    }
}