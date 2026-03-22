// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AgentRouter.sol";

/// @title VinchiCard
/// @author Vinchi Team — Hackathon
/// @notice La Tarjeta Agéntica de Vinchi. Cada usuario mintea un NFT-card
///         que representa su tarjeta. Al pagar, el contrato delega en
///         AgentRouter para encontrar el mejor banco/red automáticamente.
///
///         Implementa ERC-721 manualmente (sin dependencias externas)
///         para mantener el proyecto liviano en el hackathon.
///
///         Flujo de pago:
///           1. El usuario llama a pay() con el contexto del comercio y monto.
///           2. VinchiCard consulta AgentRouter.findBestPromotion().
///           3. Se aplica el descuento automáticamente.
///           4. El evento PaymentExecuted queda en la blockchain como recibo.
contract VinchiCard {

    // -------------------------------------------------------------------------
    // ERC-721 minimal (sin imports para hackathon standalone)
    // -------------------------------------------------------------------------

    string public name   = "Vinchi Agentic Card";
    string public symbol = "VAC";

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner_, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner_, address indexed operator, bool approved);

    // -------------------------------------------------------------------------
    // Card-specific state
    // -------------------------------------------------------------------------

    address public owner;
    AgentRouter public agentRouter;

    uint256 private _tokenCounter;

    /// @dev Perfil del usuario (preferences para el scoring)
    struct UserProfile {
        address user;
        uint256 tokenId;
        bool    preferCashback;      // Si prefiere cashback sobre descuento directo
        bool    preferInstallments;  // Si prefiere cuotas
        uint256 totalSaved;          // Ahorro acumulado lifetime
        uint256 totalTransactions;   // Cantidad de pagos realizados
        uint256 mintedAt;
    }

    /// @dev tokenId => UserProfile
    mapping(uint256 => UserProfile) public profiles;

    /// @dev user address => tokenId (una tarjeta por address)
    mapping(address => uint256) public cardOf;

    /// @dev Historial de pagos (últimas N transacciones por tokenId)
    struct PaymentRecord {
        bytes32 storeId;
        uint256 amount;
        uint256 discountedAmount;
        uint256 savedAmount;
        address bankUsed;
        string  promoDescription;
        uint256 timestamp;
    }

    mapping(uint256 => PaymentRecord[]) public paymentHistory;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event CardMinted(address indexed user, uint256 indexed tokenId);

    event PaymentExecuted(
        address indexed user,
        uint256 indexed tokenId,
        bytes32 indexed storeId,
        uint256 originalAmount,
        uint256 discountedAmount,
        uint256 savedAmount,
        address bankUsed,
        string  promoDescription
    );

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _agentRouter) {
        owner       = msg.sender;
        agentRouter = AgentRouter(_agentRouter);
    }

    // -------------------------------------------------------------------------
    // Mint
    // -------------------------------------------------------------------------

    /// @notice Crea una nueva tarjeta agéntica para el msg.sender.
    ///         Cada address solo puede tener una tarjeta activa.
    function mintCard(bool preferCashback, bool preferInstallments) external returns (uint256 tokenId) {
        require(cardOf[msg.sender] == 0, "VinchiCard: already has a card");

        tokenId = ++_tokenCounter;

        _owners[tokenId]   = msg.sender;
        _balances[msg.sender]++;
        cardOf[msg.sender] = tokenId;

        profiles[tokenId] = UserProfile({
            user:               msg.sender,
            tokenId:            tokenId,
            preferCashback:     preferCashback,
            preferInstallments: preferInstallments,
            totalSaved:         0,
            totalTransactions:  0,
            mintedAt:           block.timestamp
        });

        emit Transfer(address(0), msg.sender, tokenId);
        emit CardMinted(msg.sender, tokenId);
    }

    // -------------------------------------------------------------------------
    // Payment
    // -------------------------------------------------------------------------

    /// @notice Simula un pago con la tarjeta agéntica.
    ///         En producción, el monto se transfiere al comercio menos el descuento.
    ///         En esta demo, solo se registra on-chain y se emite el evento.
    /// @param storeId    keccak256(nombre del comercio)
    /// @param categoryId keccak256(categoría del comercio)
    /// @param amount     Monto total de la compra en wei
    /// @param dayOfWeek  Día de la semana 0=Lunes...6=Domingo
    function pay(
        bytes32 storeId,
        bytes32 categoryId,
        uint256 amount,
        uint8   dayOfWeek
    ) external returns (AgentRouter.RoutingResult memory result) {
        uint256 tokenId = cardOf[msg.sender];
        require(tokenId != 0, "VinchiCard: no card found");
        require(amount > 0, "VinchiCard: amount must be > 0");

        // Delegar en AgentRouter
        AgentRouter.PaymentContext memory ctx = AgentRouter.PaymentContext({
            storeId:    storeId,
            categoryId: categoryId,
            amount:     amount,
            dayOfWeek:  dayOfWeek
        });

        result = agentRouter.routePayment(msg.sender, ctx);

        // Actualizar perfil
        UserProfile storage profile = profiles[tokenId];
        profile.totalSaved        += result.savedAmount;
        profile.totalTransactions += 1;

        // Guardar en historial (max 50 entradas)
        PaymentRecord[] storage history = paymentHistory[tokenId];
        if (history.length >= 50) {
            // Shift (simple para hackathon)
            for (uint256 i = 0; i < history.length - 1; i++) {
                history[i] = history[i + 1];
            }
            history.pop();
        }

        history.push(PaymentRecord({
            storeId:          storeId,
            amount:           amount,
            discountedAmount: result.discountedAmount,
            savedAmount:      result.savedAmount,
            bankUsed:         result.bankOrNetwork,
            promoDescription: result.description,
            timestamp:        block.timestamp
        }));

        emit PaymentExecuted(
            msg.sender,
            tokenId,
            storeId,
            amount,
            result.discountedAmount,
            result.savedAmount,
            result.bankOrNetwork,
            result.description
        );
    }

    /// @notice Vista previa del pago sin ejecutarlo — útil para el frontend
    function previewPayment(
        bytes32 storeId,
        bytes32 categoryId,
        uint256 amount,
        uint8   dayOfWeek
    ) external view returns (AgentRouter.RoutingResult memory) {
        AgentRouter.PaymentContext memory ctx = AgentRouter.PaymentContext({
            storeId:    storeId,
            categoryId: categoryId,
            amount:     amount,
            dayOfWeek:  dayOfWeek
        });
        return agentRouter.findBestPromotion(ctx);
    }

    /// @notice Retorna el historial de pagos de una tarjeta
    function getPaymentHistory(uint256 tokenId) external view returns (PaymentRecord[] memory) {
        return paymentHistory[tokenId];
    }

    // -------------------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------------------

    function updateRouter(address newRouter) external {
        require(msg.sender == owner, "not owner");
        agentRouter = AgentRouter(newRouter);
    }

    // -------------------------------------------------------------------------
    // ERC-721 minimal
    // -------------------------------------------------------------------------

    function balanceOf(address addr) external view returns (uint256) { return _balances[addr]; }
    function ownerOf(uint256 tokenId) external view returns (address) { return _owners[tokenId]; }
    function totalSupply() external view returns (uint256) { return _tokenCounter; }

    function approve(address to, uint256 tokenId) external {
        require(_owners[tokenId] == msg.sender, "not owner");
        _tokenApprovals[tokenId] = to;
        emit Approval(msg.sender, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        require(_owners[tokenId] == from, "wrong owner");
        require(
            msg.sender == from ||
            msg.sender == _tokenApprovals[tokenId] ||
            _operatorApprovals[from][msg.sender],
            "not approved"
        );
        _owners[tokenId]   = to;
        _balances[from]--;
        _balances[to]++;
        cardOf[from] = 0;
        cardOf[to]   = tokenId;
        delete _tokenApprovals[tokenId];
        emit Transfer(from, to, tokenId);
    }
}
