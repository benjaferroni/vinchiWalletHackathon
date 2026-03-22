// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract USDm is ERC20, Ownable {
    constructor() ERC20("USDm Stablecoin", "USDm") Ownable(msg.sender) {}

    // Faucet for testing purposes or governed minting
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
