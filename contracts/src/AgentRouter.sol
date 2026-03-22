// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IPromotionRegistry.sol";

/// @title AgentRouter
/// @author Vinchi Team — Hackathon
/// @notice El cerebro de la Tarjeta Agéntica.
///
///         Dado el contexto de un pago (tienda, categoría, monto, día),
///         consulta el PromotionRegistry, puntúa cada promoción con un
///         algoritmo de scoring y selecciona la más conveniente.
///
///         Score = discountBps × typeWeight × dayBonus
///           typeWeight : cashback(15) > discount(14) > 2x1(13) > cuotas(12) > puntos(10)
///           dayBonus   : promo de día específico × 1.2 (más escasa = más valiosa)
contract AgentRouter {

    // -------------------------------------------------------------------------
    // Types
    // -------------------------------------------------------------------------

    struct PaymentContext {
        bytes32 storeId;       // keccak256(nombre del comercio)
        bytes32 categoryId;    // keccak256("supermercado" | "farmacia" | "electronica" ...)
        uint256 amount;        // Monto en wei
        uint8   dayOfWeek;     // 0=Lunes ... 6=Domingo
    }

    struct RoutingResult {
        uint256 promoId;
        address bankOrNetwork;
        string  bankName;
        uint256 discountBps;
        uint256 originalAmount;
        uint256 discountedAmount;
        uint256 savedAmount;
        string  description;
        uint256 score;
    }

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    address public owner;
    IPromotionRegistry public registry;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event PaymentRouted(
        address indexed user,
        bytes32 indexed storeId,
        uint256 promoId,
        uint256 originalAmount,
        uint256 discountedAmount,
        address bankOrNetwork
    );

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _registry) {
        owner    = msg.sender;
        registry = IPromotionRegistry(_registry);
    }

    // -------------------------------------------------------------------------
    // Core
    // -------------------------------------------------------------------------

    /// @notice Vista pura: dado un contexto de pago, retorna la mejor promo.
    ///         Sin gas cost, ideal para que el frontend pre-simule el resultado.
    function findBestPromotion(
        PaymentContext calldata ctx
    ) external view returns (RoutingResult memory result) {
        IPromotionRegistry.Promotion[] memory storePromos =
            registry.getPromotionsForStore(ctx.storeId, ctx.dayOfWeek);
        IPromotionRegistry.Promotion[] memory catPromos =
            registry.getPromotionsByCategory(ctx.categoryId, ctx.dayOfWeek);

        IPromotionRegistry.Promotion[] memory all = _merge(storePromos, catPromos);

        uint256 bestScore;
        IPromotionRegistry.Promotion memory best;
        bool found;

        for (uint256 i; i < all.length; i++) {
            IPromotionRegistry.Promotion memory p = all[i];

            if (p.categoryId != bytes32(0) && p.categoryId != ctx.categoryId) {
                continue;
            }

            if (p.minPurchaseAmount > 0 && ctx.amount < p.minPurchaseAmount) continue;
            uint256 s = _score(p);
            if (s > bestScore) { bestScore = s; best = p; found = true; }
        }

        result.originalAmount = ctx.amount;

        if (!found) {
            result.discountedAmount = ctx.amount;
            result.description = "Sin promociones disponibles";
            return result;
        }

        uint256 rawDiscount = (ctx.amount * best.discountBps) / 10_000;
        uint256 actualDiscount = (best.maxDiscountAmount > 0 && rawDiscount > best.maxDiscountAmount)
            ? best.maxDiscountAmount
            : rawDiscount;

        result.promoId          = best.id;
        result.bankOrNetwork    = best.bankOrNetwork;
        result.bankName         = registry.bankNames(best.bankOrNetwork);
        result.discountBps      = best.discountBps;
        result.discountedAmount = ctx.amount - actualDiscount;
        result.savedAmount      = actualDiscount;
        result.description      = best.description;
        result.score            = bestScore;
    }

    /// @notice Ejecuta el pago y emite el evento de auditoría on-chain.
    ///         Llamado desde VinchiCard.sol
    function routePayment(
        address user,
        PaymentContext calldata ctx
    ) external returns (RoutingResult memory result) {
        result = this.findBestPromotion(ctx);
        emit PaymentRouted(
            user, ctx.storeId, result.promoId,
            result.originalAmount, result.discountedAmount, result.bankOrNetwork
        );
    }

    /// @notice Actualiza el registry
    function updateRegistry(address newRegistry) external {
        require(msg.sender == owner, "not owner");
        registry = IPromotionRegistry(newRegistry);
    }

    // -------------------------------------------------------------------------
    // Internal: scoring
    // -------------------------------------------------------------------------

    function _score(IPromotionRegistry.Promotion memory p) internal pure returns (uint256) {
        uint256 tw;
        if      (p.promoType == IPromotionRegistry.PromoType.CASHBACK)     tw = 15;
        else if (p.promoType == IPromotionRegistry.PromoType.DISCOUNT)     tw = 14;
        else if (p.promoType == IPromotionRegistry.PromoType.TWOXONE)      tw = 13;
        else if (p.promoType == IPromotionRegistry.PromoType.INSTALLMENTS) tw = 12;
        else tw = 10;

        uint256 db = (p.dayOfWeek == IPromotionRegistry.DayOfWeek.EVERYDAY) ? 10 : 12;
        return (p.discountBps * tw * db) / 100;
    }

    function _merge(
        IPromotionRegistry.Promotion[] memory a,
        IPromotionRegistry.Promotion[] memory b
    ) internal pure returns (IPromotionRegistry.Promotion[] memory out) {
        out = new IPromotionRegistry.Promotion[](a.length + b.length);
        uint256 idx;
        for (uint256 i; i < a.length; i++) out[idx++] = a[i];
        for (uint256 j; j < b.length; j++) {
            bool dup;
            for (uint256 i; i < a.length; i++) { if (a[i].id == b[j].id) { dup = true; break; } }
            if (!dup) out[idx++] = b[j];
        }
        assembly { mstore(out, idx) }
    }
}
