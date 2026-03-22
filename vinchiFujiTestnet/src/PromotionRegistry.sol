// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IPromotionRegistry.sol";

/// @title PromotionRegistry
/// @author Vinchi Team — Hackathon
/// @notice Base de datos on-chain de promociones para la Tarjeta Agéntica.
///         Los bancos y redes de pago ficticios registran aquí sus promos.
///         El AgentRouter consulta este contrato para encontrar la mejor opción
///         para el usuario al momento del pago.
contract PromotionRegistry is IPromotionRegistry {

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    address public owner;

    uint256 private _promoCounter;

    /// @dev promoId => Promotion
    mapping(uint256 => Promotion) private _promotions;

    /// @dev bank address => authorized
    mapping(address => bool) private _authorizedBanks;

    /// @dev bank address => display name
    mapping(address => string) public bankNames;

    /// @dev storeId => list of promoIds
    mapping(bytes32 => uint256[]) private _promosByStore;

    /// @dev categoryId => list of promoIds
    mapping(bytes32 => uint256[]) private _promosByCategory;

    /// @dev bank => list of promoIds
    mapping(address => uint256[]) private _promosByBank;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() {
        owner = msg.sender;
    }

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "PromotionRegistry: not owner");
        _;
    }

    modifier onlyAuthorizedBank() {
        require(_authorizedBanks[msg.sender], "PromotionRegistry: not authorized bank");
        _;
    }

    // -------------------------------------------------------------------------
    // Owner functions
    // -------------------------------------------------------------------------

    /// @notice Autoriza un banco o red de pago para registrar promociones
    function authorizeBank(address bank, string calldata name) external onlyOwner {
        _authorizedBanks[bank] = true;
        bankNames[bank] = name;
        emit BankAuthorized(bank, name);
    }

    /// @notice Revoca la autorización de un banco
    function revokeBank(address bank) external onlyOwner {
        _authorizedBanks[bank] = false;
    }

    // -------------------------------------------------------------------------
    // Bank functions
    // -------------------------------------------------------------------------

    /// @inheritdoc IPromotionRegistry
    function registerPromotion(
        bytes32 storeId,
        bytes32 categoryId,
        uint256 discountBps,
        PromoType promoType,
        DayOfWeek dayOfWeek,
        uint256 maxDiscountAmount,
        uint256 minPurchaseAmount,
        uint256 validUntil,
        string calldata description
    ) external onlyAuthorizedBank returns (uint256 promoId) {
        // INSTALLMENTS puede tener discountBps = 0 (cuotas sin interes, sin descuento en precio)
        bool isInstallments = (promoType == PromoType.INSTALLMENTS);
        require(
            (isInstallments || discountBps > 0) && discountBps <= 10_000,
            "PromotionRegistry: invalid discount"
        );
        require(validUntil > block.timestamp, "PromotionRegistry: already expired");

        promoId = ++_promoCounter;

        _promotions[promoId] = Promotion({
            id:                promoId,
            bankOrNetwork:     msg.sender,
            storeId:           storeId,
            categoryId:        categoryId,
            discountBps:       discountBps,
            promoType:         promoType,
            dayOfWeek:         dayOfWeek,
            maxDiscountAmount: maxDiscountAmount,
            minPurchaseAmount: minPurchaseAmount,
            validUntil:        validUntil,
            active:            true,
            description:       description
        });

        _promosByStore[storeId].push(promoId);
        _promosByCategory[categoryId].push(promoId);
        _promosByBank[msg.sender].push(promoId);

        emit PromotionRegistered(promoId, msg.sender, storeId, discountBps, promoType);
    }

    /// @inheritdoc IPromotionRegistry
    function deactivatePromotion(uint256 promoId) external {
        Promotion storage promo = _promotions[promoId];
        require(
            msg.sender == promo.bankOrNetwork || msg.sender == owner,
            "PromotionRegistry: unauthorized"
        );
        promo.active = false;
        emit PromotionDeactivated(promoId);
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------

    /// @inheritdoc IPromotionRegistry
    function getPromotionsForStore(
        bytes32 storeId,
        uint8 dayOfWeek
    ) external view returns (Promotion[] memory) {
        return _filterPromos(_promosByStore[storeId], dayOfWeek);
    }

    /// @inheritdoc IPromotionRegistry
    function getPromotionsByCategory(
        bytes32 categoryId,
        uint8 dayOfWeek
    ) external view returns (Promotion[] memory) {
        return _filterPromos(_promosByCategory[categoryId], dayOfWeek);
    }

    /// @inheritdoc IPromotionRegistry
    function getPromotion(uint256 promoId) external view returns (Promotion memory) {
        return _promotions[promoId];
    }

    /// @inheritdoc IPromotionRegistry
    function isAuthorizedBank(address bank) external view returns (bool) {
        return _authorizedBanks[bank];
    }

    /// @inheritdoc IPromotionRegistry
    function totalPromotions() external view returns (uint256) {
        return _promoCounter;
    }

    /// @notice Retorna todas las promos registradas por un banco
    function getPromotionsByBank(address bank) external view returns (Promotion[] memory) {
        uint256[] memory ids = _promosByBank[bank];
        Promotion[] memory result = new Promotion[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = _promotions[ids[i]];
        }
        return result;
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    /// @dev Filtra promociones activas para un día dado y monto mínimo
    function _filterPromos(
        uint256[] memory ids,
        uint8 dayOfWeek
    ) internal view returns (Promotion[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            if (_isValidPromo(_promotions[ids[i]], dayOfWeek)) count++;
        }

        Promotion[] memory result = new Promotion[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            Promotion storage p = _promotions[ids[i]];
            if (_isValidPromo(p, dayOfWeek)) {
                result[idx] = p;
                idx++;
            }
        }
        return result;
    }

    /// @dev Verifica si una promo es válida hoy
    function _isValidPromo(Promotion storage p, uint8 dayOfWeek) internal view returns (bool) {
        if (!p.active) return false;
        if (block.timestamp > p.validUntil) return false;
        if (p.dayOfWeek == DayOfWeek.EVERYDAY) return true;
        return uint8(p.dayOfWeek) == dayOfWeek;
    }
}
