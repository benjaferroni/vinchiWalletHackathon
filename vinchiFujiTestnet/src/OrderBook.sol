// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OrderBook {

  enum OrderType { SELL_USDM_FOR_USDV, SELL_USDV_FOR_USDM }
  enum OrderStatus { OPEN, FILLED, CANCELLED }

  struct Order {
    uint256   id;
    address   creator;
    OrderType orderType;
    uint256   amountOffered;   // tokens que ofrece el creador
    uint256   amountWanted;    // tokens que quiere recibir
    OrderStatus status;
    uint256   createdAt;
  }

  IERC20 public immutable usdm;
  IERC20 public immutable usdv;

  uint256 private _orderCounter;
  mapping(uint256 => Order) public orders;
  uint256[] public openOrderIds;

  event OrderCreated(
    uint256 indexed orderId,
    address indexed creator,
    OrderType orderType,
    uint256 amountOffered,
    uint256 amountWanted
  );

  event OrderFilled(
    uint256 indexed orderId,
    address indexed taker
  );

  event OrderCancelled(uint256 indexed orderId);

  constructor(address _usdm, address _usdv) {
    usdm = IERC20(_usdm);
    usdv = IERC20(_usdv);
  }

  // Crear una nueva orden
  // El creador aprueba el contrato antes de llamar esta función
  function createOrder(
    OrderType orderType,
    uint256 amountOffered,
    uint256 amountWanted
  ) external returns (uint256 orderId) {
    require(amountOffered > 0, "Amount offered must be > 0");
    require(amountWanted > 0, "Amount wanted must be > 0");

    // Transferir los tokens ofrecidos al contrato (quedan bloqueados)
    if (orderType == OrderType.SELL_USDM_FOR_USDV) {
      require(
        usdm.transferFrom(msg.sender, address(this), amountOffered),
        "USDm transfer failed"
      );
    } else {
      require(
        usdv.transferFrom(msg.sender, address(this), amountOffered),
        "USDv transfer failed"
      );
    }

    orderId = ++_orderCounter;
    orders[orderId] = Order({
      id:             orderId,
      creator:        msg.sender,
      orderType:      orderType,
      amountOffered:  amountOffered,
      amountWanted:   amountWanted,
      status:         OrderStatus.OPEN,
      createdAt:      block.timestamp
    });
    openOrderIds.push(orderId);

    emit OrderCreated(orderId, msg.sender, orderType, amountOffered, amountWanted);
  }

  // Aceptar una orden abierta
  // El taker aprueba el contrato antes de llamar esta función
  function fillOrder(uint256 orderId) external {
    Order storage order = orders[orderId];
    require(order.status == OrderStatus.OPEN, "Order not open");
    require(order.creator != msg.sender, "Cannot fill own order");

    order.status = OrderStatus.FILLED;
    _removeFromOpenOrders(orderId);

    if (order.orderType == OrderType.SELL_USDM_FOR_USDV) {
      // Taker paga USDv, recibe USDm
      require(
        usdv.transferFrom(msg.sender, order.creator, order.amountWanted),
        "USDv payment failed"
      );
      require(
        usdm.transfer(msg.sender, order.amountOffered),
        "USDm delivery failed"
      );
    } else {
      // Taker paga USDm, recibe USDv
      require(
        usdm.transferFrom(msg.sender, order.creator, order.amountWanted),
        "USDm payment failed"
      );
      require(
        usdv.transfer(msg.sender, order.amountOffered),
        "USDv delivery failed"
      );
    }

    emit OrderFilled(orderId, msg.sender);
  }

  // Cancelar una orden — solo el creador puede cancelar
  function cancelOrder(uint256 orderId) external {
    Order storage order = orders[orderId];
    require(order.creator == msg.sender, "Not order creator");
    require(order.status == OrderStatus.OPEN, "Order not open");

    order.status = OrderStatus.CANCELLED;
    _removeFromOpenOrders(orderId);

    // Devolver los tokens bloqueados al creador
    if (order.orderType == OrderType.SELL_USDM_FOR_USDV) {
      require(usdm.transfer(msg.sender, order.amountOffered), "USDm return failed");
    } else {
      require(usdv.transfer(msg.sender, order.amountOffered), "USDv return failed");
    }

    emit OrderCancelled(orderId);
  }

  // Retorna todas las órdenes abiertas
  function getOpenOrders() external view returns (Order[] memory) {
    Order[] memory result = new Order[](openOrderIds.length);
    for (uint256 i = 0; i < openOrderIds.length; i++) {
      result[i] = orders[openOrderIds[i]];
    }
    return result;
  }

  function _removeFromOpenOrders(uint256 orderId) internal {
    for (uint256 i = 0; i < openOrderIds.length; i++) {
      if (openOrderIds[i] == orderId) {
        openOrderIds[i] = openOrderIds[openOrderIds.length - 1];
        openOrderIds.pop();
        break;
      }
    }
  }
}
