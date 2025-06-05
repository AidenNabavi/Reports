
# 🔐 yieldnest


## Vulnerability Name
 Lack of Input Validation 


##  Target
https://vscode.blockscan.com/ethereum/0x87e2a51d3b88fc2f5917a7ab793ea595b243710a



##  Report Type
Smart Contract



##  Severity
low ~ Medium




## Description
The function responsible for adding or removing addresses from the whitelist lacks proper validation checks. It does not prevent invalid addresses, such as the zero address (address(0)), from being added or removed. Additionally, there is no mechanism to detect or block duplicate addresses, which means the same address can be added to the whitelist multiple times. This can lead to unnecessary storage usage and potential confusion in whitelist management. Implementing input validation and duplicate checks would improve the contract’s robustness and efficiency.



##  Vulnerability Details

```solidity 

    function addToPauseWhitelist(address[] memory whitelistedForTransfers) external onlyRole {
        _updatePauseWhitelist(whitelistedForTransfers, true);
    }

    function removeFromPauseWhitelist(address[] memory unlisted) external onlyRole {
        _updatePauseWhitelist(unlisted, false);
    }

    function _updatePauseWhitelist(address[] memory whitelistedForTransfers, bool whitelisted) internal {
        ynBaseStorage storage $ = _getYnBaseStorage();
        for (uint256 i = 0; i < whitelistedForTransfers.length; i++) {
            address targetAddress = whitelistedForTransfers[i];
            $.pauseWhiteList[targetAddress] = whitelisted;
            emit PauseWhitelistUpdated(targetAddress, whitelisted);
        }
    }
```



##  Proof of Concept (PoC)

foundry test
```solidity 


//Here's a simple mock contract in Solidity for the three functions 

pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";


contract ynBase_mock{
    event TransfersUnpaused();
    event PauseWhitelistUpdated(address indexed addr, bool whitelisted);

    struct ynBaseStorage {
        mapping (address => bool) pauseWhiteList;
        bool transfersPaused;
    }


    ynBaseStorage private store;

    modifier onlyRole() {
        _;
    }

    bytes32 private constant ynBaseStorageLocation = 0x7e7ba5b20f89141f0255e9704ce6ce6e55f5f28e4fc0d626fc76bedba3053200;

    function _getYnBaseStorage() private pure returns (ynBaseStorage storage $) {
        assembly {
            $.slot := ynBaseStorageLocation
        }
    }


// adding this  function for read Whitelisted
    function isWhitelisted(address addr) external view returns (bool) {
        ynBaseStorage storage $ = _getYnBaseStorage();
        return $.pauseWhiteList[addr];
    }


    function addToPauseWhitelist(address[] memory whitelistedForTransfers) external onlyRole {
        _updatePauseWhitelist(whitelistedForTransfers, true);
    }

    function removeFromPauseWhitelist(address[] memory unlisted) external onlyRole {
        _updatePauseWhitelist(unlisted, false);
    }

    function _updatePauseWhitelist(address[] memory whitelistedForTransfers, bool whitelisted) internal {
        ynBaseStorage storage $ = _getYnBaseStorage();
        for (uint256 i = 0; i < whitelistedForTransfers.length; i++) {
            address targetAddress = whitelistedForTransfers[i];
            $.pauseWhiteList[targetAddress] = whitelisted;
            emit PauseWhitelistUpdated(targetAddress, whitelisted);
        }
    }


}

/*
Is restricting a function to users with a specific role sufficient? No — this is a misconception.
Even if access is limited to certain roles, input validation is still necessary.

So far, based on the current mechanism, it is possible to add invalid addresses — or even the same address multiple times — to the list without any input validation.
*/
contract Test_ynBase is  Test {
    ynBase_mock ynBase ;
    address[] public input;

    function setUp() public {
        ynBase = new ynBase_mock();

    }

//same address
    function test_AddingSameAddress() public {
        input.push(address(0x02222222));
        input.push(address(0x02222222));
        input.push(address(0x02222222));
        input.push(address(0x02222222));

        ynBase.addToPauseWhitelist(input);

        for (uint256 i = 0; i < input.length; i++) {
            address target = input[i];
            bool isInWhitelist = ynBase.isWhitelisted(target);
            console.log("isWhitelisted:", isInWhitelist);
        }
    }

//invalid address
    function test_AddInvalidAddress () public {
        input.push(address(0x0000000));
        ynBase.addToPauseWhitelist(input);
        bool isInWhitelist = ynBase.isWhitelisted(address(0x0000000));
        console.log("Address at index 0 isWhitelisted:", isInWhitelist);
    }


}

```










## How to fix it (Recommended)

```solidity

// you can use this function for that
function _updatePauseWhitelist(address[] memory whitelistedForTransfers, bool whitelisted) internal {
    ynBaseStorage storage $ = _getYnBaseStorage();
    for (uint256 i = 0; i < whitelistedForTransfers.length; i++) {
        address targetAddress = whitelistedForTransfers[i];

        if (targetAddress == address(0)) {
            revert("Invalid address: zero address is not allowed");
        }
        if ($.pauseWhiteList[targetAddress] == whitelisted) {
            continue; 
        }
        $.pauseWhiteList[targetAddress] = whitelisted;
        emit PauseWhitelistUpdated(targetAddress, whitelisted);
    }
}

```






## 🔗 References

https://etherscan.io/address/0x87e2a51d3b88fc2f5917a7ab793ea595b243710a#code