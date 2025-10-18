
# 🛡️ Smart Contract Vulnerability Report
**Alchemix V3**:

## 📛 Vulnerability Title 
Improper Ownership Transfer Pattern Leading to Permanent Admin Lock

## 🗂 Report Type

Smart Contract


## 🎯 Target

https://github.com/alchemix-finance/v3-poc/blob/immunefi_audit/src/AlchemistCurator.sol
https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol

## 🗒️Asset

AlchemistCurator.sol



## 🚨 Rating

Severity:Medium
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




