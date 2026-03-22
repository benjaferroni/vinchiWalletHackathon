// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {USDm} from "../src/USDm.sol";
import {USDmY} from "../src/USDmY.sol";
import {USDv} from "../src/USDv.sol";
import {USDManager} from "../src/USDManager.sol";

contract DeployUSDProtocol is Script {
    function run() external {
        // Obtenemos la PK de la primera cuenta de Anvil por defecto (Account #0)
        // Puedes cambiar esto si estas usando otra.
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );

        // Iniciamos el broadcast de transacciones usando la cuenta del deployer
        vm.startBroadcast(deployerPrivateKey);

        // 1. Desplegamos USDm (Nuestra moneda base MOCK)
        USDm usdm = new USDm();
        console.log("USDm deployed at:", address(usdm));

        // 2. Desplegamos la Boveda USDmY, pasandole la direccion de USDm
        USDmY vault = new USDmY(usdm);
        console.log("USDmY Vault deployed at:", address(vault));

        // 3. Desplegamos el Orquestador Manager que conecta ambos mundos
        USDManager manager = new USDManager(address(usdm), address(vault));
        console.log("USDManager deployed at:", address(manager));
        // 4. Obtenemos la direccion del recibo USDv que despliega automaticamente el Manager
        USDv usdv = USDv(manager.usdv());
        console.log("USDv (Receipt) deployed at:", address(usdv));

        // Opcional: Minteamos algunos tokens iniciales para la cuenta del deployer
        // asumiendo que es la misma cuenta con la que haremos pruebas en MetaMask
        address deployerAddress = vm.addr(deployerPrivateKey);
        usdm.mint(deployerAddress, 100000 ether);
        console.log("Minted 100,000 USDm for deployer:", deployerAddress);

        vm.stopBroadcast();
    }
}
