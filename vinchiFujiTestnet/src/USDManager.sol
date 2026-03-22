// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {USDv} from "./USDv.sol";
import {USDmY} from "./USDmY.sol";
import {USDm} from "./USDm.sol";

/**
 * @title USDManager
 * @dev Orquestador principal que permite depositar USDm y obtener el recibo USDv.
 */
contract USDManager {
    using SafeERC20 for IERC20;

    USDm public immutable usdm;
    USDmY public immutable vault;
    // Single USDv receipt token earning 3% monthly
    USDv public immutable usdv;

    event Deposited(
        address indexed user,
        uint256 amountDeposited,
        uint256 sharesObtained,
        uint256 usdvMinted
    );
    event Claimed(
        address indexed user,
        uint256 usdvBurned,
        uint256 sharesRedeemed,
        uint256 usdmReturned
    );

    constructor(address _usdm, address _vault) {
        usdm = USDm(_usdm);
        vault = USDmY(_vault);
        // Deploy the single receipt token
        usdv = new USDv("USDv Receipt", "USDv", address(this));

        // Approve vault to spend Manager's USDm limitlessly
        usdm.approve(address(vault), type(uint256).max);
    }

    /**
     * @dev User deposits USDm and gets USDv representing the FUTURE nominal value (Principal + 1 month Yield).
     * The Manager deposits USDm into the USDmY vault.
     * Yield is fixed at 3% (300 bps).
     */
    function depositUSDm(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");

        // 1. Take USDm from the user
        IERC20(address(usdm)).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        // 2. Deposit USDm into the vault (USDmY) under THIS contract's name
        uint256 sharesMinted = vault.deposit(amount, address(this));

        // 3. Calculate 1-month future nominal value.
        // yield is fixed at 3% = 300 bps.
        // futureValue = shares + (shares * 300 / 10000)
        uint256 yieldRateBps = 300;
        uint256 futureValue = sharesMinted +
            ((sharesMinted * yieldRateBps) / 10000);

        // 4. Mint the USDv.
        usdv.mint(msg.sender, futureValue);

        emit Deposited(msg.sender, amount, sharesMinted, futureValue);
    }

    /**
     * @dev User brings USDv back to claim USDm.
     * Because 1 USDv was minted as "future value", we need to burn exactly that USDv
     * and redeem the underlying vault shares.
     * NOTE: In a production "credit" model, if they claim early, there would be a penalty
     * or a complex debt reconciliation. For this prototype, we allow burning the nominal USDv.
     */ function claimYield(uint256 amountUSDv) external {
        require(amountUSDv > 0, "Amount must be greater than zero");

        // 1. The user must burn the future nominal USDv they hold
        usdv.burn(msg.sender, amountUSDv);

        // 2. Reverse the math to figure out how many actual vault *shares* this nominal amount represents
        // shares = futureValue / (1 + yieldRateBps/10000)
        // shares = (futureValue * 10000) / (10000 + yieldRateBps)
        uint256 yieldRateBps = 300;
        uint256 sharesToRedeem = (amountUSDv * 10000) / (10000 + yieldRateBps);

        // 3. Redeem vault shares to return the underlying assets to the user
        uint256 assetsReturned = vault.redeem(
            sharesToRedeem,
            msg.sender,
            address(this)
        );

        emit Claimed(msg.sender, amountUSDv, sharesToRedeem, assetsReturned);
    }
}
