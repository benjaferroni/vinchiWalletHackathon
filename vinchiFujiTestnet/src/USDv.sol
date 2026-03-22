// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title USDv
 * @dev Receipt token representing users' deposits into the yield vault.
 * Users transfer this token to transact value, capturing yield natively.
 * Minting and burning are strictly controlled by the Manager contract.
 */
contract USDv is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        address initialManager
    ) ERC20(name, symbol) Ownable(initialManager) {}

    /**
     * @dev Mint new USDv tokens (only Manager)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Burn USDv tokens (only Manager)
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
