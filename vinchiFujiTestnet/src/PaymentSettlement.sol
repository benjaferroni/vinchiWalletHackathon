// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./VinchiMerchant.sol";

contract PaymentSettlement {
    IERC20 public usdv;
    address public operator;
    VinchiMerchant public merchant;

    event PaymentSettled(
        bytes32 storeId,
        address payer,
        uint256 grossAmount,
        uint256 netAmount,
        uint256 discountBps,
        uint256 promoId,
        address bankUsed
    );

    constructor(address _usdv, address _merchant) {
        usdv = IERC20(_usdv);
        operator = msg.sender;
        merchant = VinchiMerchant(_merchant);
    }

    function setMerchant(address _merchant) external {
        require(msg.sender == operator, "not operator");
        merchant = VinchiMerchant(_merchant);
    }

    /// @notice Ejecuta el cobro final deduciendo 'netAmount' del user y enviándolo a la wallet de la tienda.
    ///         Requiere que el payer haya dado 'approve' previo a PaymentSettlement.
    function settlePayment(
        bytes32 storeId,
        address merchantAddress,
        address payer,
        uint256 grossAmount,
        uint256 netAmount,
        uint256 discountBps,
        uint256 promoId,
        address bankUsed
    ) external {
        require(msg.sender == operator, "not operator");
        require(merchantAddress != address(0), "merchant address not set");

        // Transfiere los fondos desde el usuario directamente a la wallet de la tienda configurada
        usdv.transferFrom(payer, merchantAddress, netAmount);

        emit PaymentSettled(
            storeId,
            payer,
            grossAmount,
            netAmount,
            discountBps,
            promoId,
            bankUsed
        );
    }
}
