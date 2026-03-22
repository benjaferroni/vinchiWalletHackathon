// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract VinchiMerchant {
    IERC20 public usdv;

    constructor(address _usdv) {
        usdv = IERC20(_usdv);
    }

    /// @notice Permite al merchant retirar sus USDv (para la demo)
    function withdraw(uint256 amount) external {
        usdv.transfer(msg.sender, amount);
    }
}
