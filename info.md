
# 🛡️ Smart Contract Vulnerability Report
**Alchemix V3**:

## 📛 Vulnerability Title 

Security mechanism imported but not applied

## 🗂 Report Type

Smart Contract


## 🎯 Target

https://github.com/alchemix-finance/v3-poc/blob/immunefi_audit/src/utils/ZeroXSwapVerifier.sol



## 🗒️Asset

ZeroXSwapVerifier.sol



## 🚨 Rating

Severity : Insight




## 📄 Description


---

The `ZeroXSwapVerifier` library imports the `ReentrancyGuard` module but does not use it in any of its functions.
Since the library has no storage and performs no external calls, including `ReentrancyGuard` has **no security effect** and only increases the bytecode size.

If the developer's goal was to prevent reentrancy attacks during swaps, the `nonReentrant` modifier should be applied in the **consumer contract** that uses the library, not in the library itself.



## 🧨 Impact

Only increases the bytecode size. It has no effect on security since the library does not hold state or make external calls.


## 🔍 Vulnerability Details

```solidity
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

```

## 🧪 Proof of Concept (PoC)

There is no exploit possible because this is not a functional vulnerability. The PoC simply demonstrates the unused import:

``` solidity

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

library ZeroXSwapVerifier {
    // ReentrancyGuard is imported but never applied to any function
}


```



## 🔗 References

-https://github.com/alchemix-finance/v3-poc/blob/immunefi_audit/src/utils/ZeroXSwapVerifier.sol





