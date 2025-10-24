
# 🛡️ Smart Contract Vulnerability Report
**Alchemix V3**:

## 📛 Vulnerability Title 
Admin Transfer Logic Flaw Causing Ownership Lock

## 🗂 Report Type

Smart Contract


## 🎯 Target

https://github.com/alchemix-finance/v3-poc/blob/immunefi_audit/src/AlchemistCurator.sol
https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol

## 🗒️Asset

AlchemistCurator.sol



## 🚨 Rating

Severity: Medium — Ownership Mechanism Lock Risk 
Impact: Medium
Likelihood: Low 


## 📄 Description

This misalignment with the OpenZeppelin pattern constitutes a logic bug with high operational risk . Because :
**OpenZeppelin Ownable2Step standard for this purpose:**
``https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol``

It **must be able to make itself the admin!**
The purpose of implementing such a mechanism is that if the primary admin becomes unavailable, the secondary admin should be able to take control and manage the contract.

If the current admin loses access to their private key , be unavailable , be offline ,becomes inactive or or intentionally refuses to call acceptAdminOwnership, then ownership can never be finalized.
This permanently locks critical admin-only functions (onlyAdmin) and prevents further protocol updates or emergency actions.

However, in the current implementation, besides conflicting with the OpenZeppelin standard, the ownership transfer carries a risk of permanent locking.


## 🧨 Impact


Permanent loss of admin control if the current admin becomes unreachable.

Effectively, the contract enters an Ownership Lock state.

Because this contract coordinates strategy management and vault configuration, this could block adding/removing strategies or updating caps — potentially halting protocol functionality.




## 🔍 Vulnerability Details

Expected (standard) behavior

OpenZeppelin Ownable2Step requires:

``require(msg.sender == pendingOwner, "caller is not the new owner");``

Only the pending owner can call acceptOwnership.

Actual behavior

In AlchemistCurator.sol, only the current admin can call acceptAdminOwnership.
Thus, pendingAdmin cannot claim ownership, and transfer completion depends entirely on the old admin.

This violates the OpenZeppelin pattern and introduces a logic-level single-point-of-failure.





## 🧪 Proof of Concept (PoC)

step by step 

Copy and run this code :👇🏽

```solidity 

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

/// @notice This mock simulates the AlchemistCurator contract.
/// Only the two relevant functions for this PoC are implemented:
/// - transferAdminOwnerShip(): sets a pending admin
/// - acceptAdminOwnership(): allows the current admin to finalize ownership transfer
contract Mock_AlchemistCurator {
    address public admin;
    address public operator;
    address public pendingAdmin;

    event AdminChanged(address indexed newAdmin);


    constructor(address _admin, address _operator) {
        admin = _admin;
        operator = _operator;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "ONLY_ADMIN");
        _;
    }


    function transferAdminOwnerShip(address _newAdmin) external onlyAdmin {
        pendingAdmin = _newAdmin;
    }


    function acceptAdminOwnership() external onlyAdmin {
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit AdminChanged(admin);
    }
}


/// @notice This is the PoC test demonstrating the vulnerability
/// @dev In the vulnerable contract, the pending admin cannot finalize ownership transfer
contract AlchemistCuratorPoC is Test {
    Mock_AlchemistCurator curator;

    // Test addresses
    address deployer = address(0xDeaD);
    address admin = address(0xA0);
    address operator = address(0xB0);
    address pendingAdmin = address(0xC0);

    function setUp() public {
        vm.prank(deployer);
        curator = new Mock_AlchemistCurator(admin, operator);
    }

    /// @notice PoC: pendingAdmin should be able to accept ownership per standard pattern (like OpenZeppelin)
    function testPendingCannotAccept() public {
        // First, the current admin sets the pendingAdmin
        vm.prank(admin);
        curator.transferAdminOwnerShip(pendingAdmin);

        // But in reality, the pendingAdmin cannot finalize ownership because the call reverts.
        // Notice that in OpenZeppelin's standard pattern, the pending admin CAN accept ownership themselves.

        // Imagine the current admin becomes unavailable, offline, or unreachable.
        // In that case, the contract becomes permanently locked because this mechanism is not standard.
        // Run with: forge test -vvv
        vm.prank(pendingAdmin);
        vm.expectRevert(bytes("ONLY_ADMIN"));
        curator.acceptAdminOwnership();
    }
}



//read this 
```

 this is the ownership transfer in the current contract.

```solidity 

function acceptAdminOwnership() external onlyAdmin {
    admin = pendingAdmin;
    pendingAdmin = address(0);
    emit AdminChanged(admin);
}
```

 this is the ownership transfer in the OpenZeppelin contract.
**OpenZeppelin Ownable2Step standard:**
```solidity 

function acceptOwnership() public virtual {
    address sender = _msgSender();
    require(sender == _pendingOwner, "Ownable2Step: caller is not the new owner");
    _transferOwnership(sender);
}


```



## How to fix it (Recommended)


Adopt the standard Ownable2Step pattern:

```solidity 

function acceptAdminOwnership() external {
    require(msg.sender == pendingAdmin, "NOT_PENDING_ADMIN");
    admin = pendingAdmin;
    pendingAdmin = address(0);
    emit AdminChanged(admin);
}


```


## 🔗 References

https://github.com/alchemix-finance/v3-poc/blob/immunefi_audit/src/AlchemistCurator.sol

https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol




