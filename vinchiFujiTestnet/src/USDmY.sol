// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract USDmY is ERC4626 {
    constructor(IERC20 asset_) ERC4626(asset_) ERC20("USDm Yield Vault", "USDmY") {}

    /**
     * @dev Simple function to inject yield into the vault.
     * Anyone can transfer USDm to this contract and then call this function
     * to officially inject it as yield, avoiding donation attacks or just keeping it clean.
     * Note: Standard ERC4626 naturally incorporates token balances that exceed totalSupply of shares,
     * so transferring standard tokens directly to the contract address usually counts as yield.
     * We add this as a straightforward helper.
     */
    function injectYield(uint256 amount) external {
        IERC20(asset()).transferFrom(msg.sender, address(this), amount);
    }
}
