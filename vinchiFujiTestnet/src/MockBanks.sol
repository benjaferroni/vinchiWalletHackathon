// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IPromotionRegistry.sol";

/// @title MockBanks
/// @author Vinchi Team — Hackathon
/// @notice Contratos de bancos y redes de pago FICTICIOS para el hackathon.
///         Cada banco registra sus promociones en el PromotionRegistry
///         al momento del deploy, simulando el comportamiento real.
///
///         Bancos ficticios:
///           1. BancoRío DeFi    — Cashback 15% en supermercados los jueves
///           2. BancoPcia DeFi   — Reintegro 20% en farmacias todos los días
///           3. VisaDeFi         — 10% off en electrónica los fines de semana
///           4. MaestroNet       — 3 cuotas sin interés en ropa cualquier día
///
///         En un sistema real, cada banco sería una entidad separada con
///         su propio contrato y lógica de negocio. Aquí los agrupamos
///         en un solo archivo para simplicidad del hackathon.

// =============================================================================
// BancoRío DeFi
// =============================================================================
contract BancoRioDefi {
    string public constant BANK_NAME = "BancoRio DeFi";

    address public owner;
    IPromotionRegistry public registry;

    constructor(address _registry) {
        owner    = msg.sender;
        registry = IPromotionRegistry(_registry);
    }

    /// @notice Registra todas las promos de BancoRío en el registry.
    ///         Llamar después de authorizeBank() en PromotionRegistry.
    function registerPromotions() external {
        require(msg.sender == owner, "not owner");

        // Promo 1: Cashback 15% en supermercados los JUEVES
        registry.registerPromotion(
            keccak256(""),                              // storeId: cualquier tienda
            keccak256("supermercado"),                  // categoryId
            1500,                                       // 15.00% en bps
            IPromotionRegistry.PromoType.CASHBACK,
            IPromotionRegistry.DayOfWeek.THURSDAY,
            5 ether,                                    // tope: 5 AVAX de descuento
            10 ether,                                   // compra mínima: 10 AVAX
            block.timestamp + 180 days,
            "BancoRio DeFi: 15% cashback en supermercados todos los jueves. Tope $5 AVAX"
        );

        // Promo 2: Cashback 10% en combustible todos los días
        registry.registerPromotion(
            keccak256(""),
            keccak256("combustible"),
            1000,                                       // 10%
            IPromotionRegistry.PromoType.CASHBACK,
            IPromotionRegistry.DayOfWeek.EVERYDAY,
            3 ether,
            0,
            block.timestamp + 90 days,
            "BancoRio DeFi: 10% cashback en combustible, sin monto minimo"
        );
    }
}

// =============================================================================
// BancoPcia DeFi (inspirado en Banco Provincia)
// =============================================================================
contract BancoProvinciaDefi {
    string public constant BANK_NAME = "BancoPcia DeFi";

    address public owner;
    IPromotionRegistry public registry;

    constructor(address _registry) {
        owner    = msg.sender;
        registry = IPromotionRegistry(_registry);
    }

    function registerPromotions() external {
        require(msg.sender == owner, "not owner");

        // Promo 1: 20% reintegro en farmacias TODOS LOS DÍAS
        registry.registerPromotion(
            keccak256(""),
            keccak256("farmacia"),
            2000,                                       // 20%
            IPromotionRegistry.PromoType.CASHBACK,
            IPromotionRegistry.DayOfWeek.EVERYDAY,
            8 ether,
            5 ether,
            block.timestamp + 120 days,
            "BancoPcia DeFi: 20% reintegro en farmacias todos los dias. Tope $8 AVAX"
        );

        // Promo 2: 25% off en restaurantes los MIÉRCOLES
        registry.registerPromotion(
            keccak256(""),
            keccak256("restaurante"),
            2500,                                       // 25%
            IPromotionRegistry.PromoType.DISCOUNT,
            IPromotionRegistry.DayOfWeek.WEDNESDAY,
            10 ether,
            0,
            block.timestamp + 180 days,
            "BancoPcia DeFi: 25% descuento en restaurantes los miercoles"
        );

        // Promo 3: 15% cashback en supermercados los MARTES y MIÉRCOLES
        // (registramos martes; los miércoles los cubre otra promo)
        registry.registerPromotion(
            keccak256(""),
            keccak256("supermercado"),
            1500,
            IPromotionRegistry.PromoType.CASHBACK,
            IPromotionRegistry.DayOfWeek.TUESDAY,
            6 ether,
            8 ether,
            block.timestamp + 180 days,
            "BancoPcia DeFi: 15% cashback en supermercados los martes. Tope $6 AVAX"
        );
    }
}

// =============================================================================
// VisaDeFi
// =============================================================================
contract VisaDeFiNetwork {
    string public constant BANK_NAME = "VisaDeFi Network";

    address public owner;
    IPromotionRegistry public registry;

    constructor(address _registry) {
        owner    = msg.sender;
        registry = IPromotionRegistry(_registry);
    }

    function registerPromotions() external {
        require(msg.sender == owner, "not owner");

        // Promo 1: 10% off electrónica los FINES DE SEMANA
        registry.registerPromotion(
            keccak256(""),
            keccak256("electronica"),
            1000,
            IPromotionRegistry.PromoType.DISCOUNT,
            IPromotionRegistry.DayOfWeek.SATURDAY,
            20 ether,
            15 ether,
            block.timestamp + 90 days,
            "VisaDeFi: 10% off en electronica los sabados. Tope $20 AVAX"
        );

        registry.registerPromotion(
            keccak256(""),
            keccak256("electronica"),
            1000,
            IPromotionRegistry.PromoType.DISCOUNT,
            IPromotionRegistry.DayOfWeek.SUNDAY,
            20 ether,
            15 ether,
            block.timestamp + 90 days,
            "VisaDeFi: 10% off en electronica los domingos. Tope $20 AVAX"
        );

        // Promo 2: 3 cuotas sin interés en viajes TODOS LOS DÍAS
        registry.registerPromotion(
            keccak256(""),
            keccak256("viajes"),
            0,                                          // No hay descuento, son cuotas
            IPromotionRegistry.PromoType.INSTALLMENTS,
            IPromotionRegistry.DayOfWeek.EVERYDAY,
            0,
            50 ether,
            block.timestamp + 365 days,
            "VisaDeFi: 3 cuotas sin interes en agencias de viaje. Minimo $50 AVAX"
        );
    }
}

// =============================================================================
// MaestroNet
// =============================================================================
contract MaestroNet {
    string public constant BANK_NAME = "MaestroNet";

    address public owner;
    IPromotionRegistry public registry;

    constructor(address _registry) {
        owner    = msg.sender;
        registry = IPromotionRegistry(_registry);
    }

    function registerPromotions() external {
        require(msg.sender == owner, "not owner");

        // Promo 1: 6 cuotas sin interés en ropa TODOS LOS DÍAS
        registry.registerPromotion(
            keccak256(""),
            keccak256("indumentaria"),
            0,
            IPromotionRegistry.PromoType.INSTALLMENTS,
            IPromotionRegistry.DayOfWeek.EVERYDAY,
            0,
            20 ether,
            block.timestamp + 180 days,
            "MaestroNet: 6 cuotas sin interes en indumentaria. Minimo $20 AVAX"
        );

        // Promo 2: 2x1 en cines los LUNES
        registry.registerPromotion(
            keccak256(""),
            keccak256("entretenimiento"),
            5000,                                       // 50% (equivalente al 2x1 en tickets individuales)
            IPromotionRegistry.PromoType.TWOXONE,
            IPromotionRegistry.DayOfWeek.MONDAY,
            0,
            0,
            block.timestamp + 180 days,
            "MaestroNet: 2x1 en cines y entretenimiento los lunes"
        );

        // Promo 3: 12% cashback en delivery VIERNES Y SÁBADO
        registry.registerPromotion(
            keccak256(""),
            keccak256("delivery"),
            1200,
            IPromotionRegistry.PromoType.CASHBACK,
            IPromotionRegistry.DayOfWeek.FRIDAY,
            4 ether,
            0,
            block.timestamp + 90 days,
            "MaestroNet: 12% cashback en delivery los viernes. Tope $4 AVAX"
        );

        registry.registerPromotion(
            keccak256(""),
            keccak256("delivery"),
            1200,
            IPromotionRegistry.PromoType.CASHBACK,
            IPromotionRegistry.DayOfWeek.SATURDAY,
            4 ether,
            0,
            block.timestamp + 90 days,
            "MaestroNet: 12% cashback en delivery los sabados. Tope $4 AVAX"
        );
    }
}
