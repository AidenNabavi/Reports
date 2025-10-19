
#  Smart Contract Vulnerability Report
**Alchemix V3**:

##  Vulnerability Title 

Missing length validation before abi.decode may cause unexpected revert (DoS)
and 
Unused variable declaration (dead code)

##  Report Type

Smart Contract


##  Target

https://github.com/alchemix-finance/v3-poc/blob/immunefi_audit/src/MYTStrategy.sol



## Asset

MYTStrategy.sol



##  Rating

Severity: Insight
Impact: Low
Likelihood: Low


##  Description

Within the allocate() function of MYTStrategy.sol, the contract decodes the incoming data parameter using abi.decode without verifying its length.
If the input data is shorter than expected, the abi.decode call will revert unexpectedly, potentially leading to a denial of service (DoS) in specific allocation flows.

This is a best practice issue that could cause transaction reverts if upstream validation is not guaranteed by the calling contract (Vault).
A simple length check using require(data.length >= 32, "Invalid data") would ensure safe decoding.


In addition, the variable in line 60 :
``IDeployerTiny constant ZERO_EX_DEPLOYER = IDeployerTiny(0x00000000000004533Fe15556B1E086BB1A72cEae);``
is declared but never used anywhere in the contract, which makes it redundant and could be removed for cleaner, safer code.


##  Impact

Unexpected reverts if malformed or empty data is passed to allocate().

 just Redundant constant variable increases bytecode size



##  Vulnerability Details

this function  ---> allocate()


```solidity 

function allocate(bytes memory data, uint256 assets, bytes4 selector, address sender)
    external
    onlyVault
    returns (bytes32[] memory strategyIds, int256 change)
{
    if (killSwitch) {
        return (ids(), int256(0));
    }
    require(assets > 0, "Zero amount");

    // here we have to add   ----->      require(data.length >= 32, "Invalid data");
    
    uint256 oldAllocation = abi.decode(data, (uint256)); 
    uint256 amountAllocated = _allocate(assets);
    uint256 newAllocation = oldAllocation + amountAllocated;
    emit Allocate(amountAllocated, address(this));
    return (ids(), int256(newAllocation) - int256(oldAllocation));
}

```


##  Proof of Concept (PoC)

Step by Step  to POC :

Copy and run this :


```solidity 
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

//  Mock contract simulating the behavior of MYTStrategy
//This mock focuses on demonstrating how the `allocate` function behaves

contract Mock_MYTStrategy {
    bool public killSwitch;

    event Allocate(uint256 amountAllocated, address strategy);

    function ids() public view returns (bytes32[] memory) {
        bytes32[] memory ids_ = new bytes32[](1);
        ids_[0] =keccak256("mock_id");
        return ids_;
    }

    function _allocate(uint256 assets) internal pure returns (uint256) {
        return assets / 2;
    }

    function allocate(bytes memory data, uint256 assets, bytes4 selector, address sender)
        external
        returns (bytes32[] memory strategyIds, int256 change)
    {
        if (killSwitch) {
            return (ids(), int256(0));
        }

        require(assets > 0, "Zero amount");

        //  If `data` is shorter than 32 bytes, abi.decode will cause a revert
        uint256 oldAllocation = abi.decode(data, (uint256));

        uint256 amountAllocated = _allocate(assets);
        uint256 newAllocation = oldAllocation + amountAllocated;

        emit Allocate(amountAllocated, address(this));
        return (ids(), int256(newAllocation) - int256(oldAllocation));
    }
}

/// Test contract verifying behavior of allocate()
contract MYTStrategyTest is Test {
    Mock_MYTStrategy strategy;

    function setUp() public {
        strategy = new Mock_MYTStrategy();
    }

    ///  This test demonstrates that if input data is empty, the call reverts
    function testAllocateRevertsOnEmptyData() public {
        bytes memory emptyData = "";
        uint256 assets = 1000;

        vm.expectRevert();
        strategy.allocate(emptyData, assets, bytes4(0), address(this));
    }

    ///  This test shows that if input data is shorter than 32 bytes, it also reverts
    function test_AllocateErrorWithLesserDataThan32bytes() public {
        // Create a fake data payload with only 10 bytes (less than 32 bytes)
        bytes memory shortData = new bytes(10);
        uint256 assets = 1000;

        vm.expectRevert(); // Passing means revert occurs 

        strategy.allocate(shortData, assets, bytes4(0), address(this));
    }

}

```



## How to fix it (Recommended)

```solidity


//Add an explicit length check before decoding:

require(data.length >= 32, "Invalid data");




//And remove the unused variable for cleaner and optimized code:

IDeployerTiny constant ZERO_EX_DEPLOYER = IDeployerTiny(0x00000000000004533Fe15556B1E086BB1A72cEae);


```


## 🔗 References

- https://github.com/alchemix-finance/v3-poc/blob/immunefi_audit/src/MYTStrategy.sol






