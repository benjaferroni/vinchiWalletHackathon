// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPromotionRegistry {

    enum PromoType {
        CASHBACK,
        DISCOUNT,
        INSTALLMENTS,
        POINTS,
        TWOXONE
    }

    enum DayOfWeek {
        MONDAY,
        TUESDAY,
        WEDNESDAY,
        THURSDAY,
        FRIDAY,
        SATURDAY,
        SUNDAY,
        EVERYDAY
    }

    struct Promotion {
        uint256 id;
        address bankOrNetwork;
        bytes32 storeId;
        bytes32 categoryId;
        uint256 discountBps;
        PromoType promoType;
        DayOfWeek dayOfWeek;
        uint256 maxDiscountAmount;
        uint256 minPurchaseAmount;
        uint256 validUntil;
        bool active;
        string description;
    }

    event PromotionRegistered(
        uint256 indexed promoId,
        address indexed bankOrNetwork,
        bytes32 indexed storeId,
        uint256 discountBps,
        PromoType promoType
    );

    event PromotionDeactivated(uint256 indexed promoId);

    event BankAuthorized(address indexed bank, string name);

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
    ) external returns (uint256 promoId);

    function deactivatePromotion(uint256 promoId) external;

    function getPromotionsForStore(
        bytes32 storeId,
        uint8 dayOfWeek
    ) external view returns (Promotion[] memory);

    function getPromotionsByCategory(
        bytes32 categoryId,
        uint8 dayOfWeek
    ) external view returns (Promotion[] memory);

    function isAuthorizedBank(address bank) external view returns (bool);

    function getPromotion(uint256 promoId) external view returns (Promotion memory);

    function totalPromotions() external view returns (uint256);

    /// @notice Retorna el nombre del banco registrado en el registry
    function bankNames(address bank) external view returns (string memory);
}
