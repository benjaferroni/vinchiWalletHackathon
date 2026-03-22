// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract StoreRegistry {
  struct Store {
    bytes32 storeId;
    string  name;
    string  color;
    address creator;    // quien creó la tienda (msg.sender)
    address recipient;  // wallet que RECIBE los pagos (ingresada manualmente)
    bool    active;
  }

  mapping(bytes32 => Store) public stores;
  bytes32[] public allStoreIds;

  event StoreCreated(
    bytes32 indexed storeId,
    string  name,
    string  color,
    address indexed creator,
    address indexed recipient
  );

  function createStore(
    string  calldata name,
    string  calldata color,
    address          recipient
  ) external returns (bytes32 storeId) {
    require(recipient != address(0), "Recipient cannot be zero address");
    storeId = keccak256(abi.encodePacked(name, msg.sender));
    require(stores[storeId].creator == address(0), "Store already exists");
    stores[storeId] = Store(storeId, name, color, msg.sender, recipient, true);
    allStoreIds.push(storeId);
    emit StoreCreated(storeId, name, color, msg.sender, recipient);
  }

  function getAllStores() external view returns (Store[] memory) {
    Store[] memory result = new Store[](allStoreIds.length);
    for (uint i = 0; i < allStoreIds.length; i++) {
      result[i] = stores[allStoreIds[i]];
    }
    return result;
  }

  function getStore(bytes32 storeId)
    external view returns (Store memory) {
    return stores[storeId];
  }
}
