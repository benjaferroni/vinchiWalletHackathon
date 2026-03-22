// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PromotionRegistry.sol";
import "../src/AgentRouter.sol";
import "../src/VinchiCard.sol";
import "../src/MockBanks.sol";

contract DeployVinchi is Script {
    function run() external {
        // Clave privada de Anvil #0 - solo para desarrollo local
        uint256 deployerKey = vm.envOr(
            "DEPLOYER_PRIVATE_KEY",
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );

        vm.startBroadcast(deployerKey);

        // 1. Contratos core
        PromotionRegistry registry = new PromotionRegistry();
        AgentRouter       router   = new AgentRouter(address(registry));
        VinchiCard        card     = new VinchiCard(address(router));

        // 2. Bancos ficticios
        BancoRioDefi       bancoRio  = new BancoRioDefi(address(registry));
        BancoProvinciaDefi bancoPcia = new BancoProvinciaDefi(address(registry));
        VisaDeFiNetwork    visaDeFi  = new VisaDeFiNetwork(address(registry));
        MaestroNet         maestro   = new MaestroNet(address(registry));

        // 3. Autorizar bancos
        registry.authorizeBank(address(bancoRio),  "BancoRio DeFi");
        registry.authorizeBank(address(bancoPcia), "BancoPcia DeFi");
        registry.authorizeBank(address(visaDeFi),  "VisaDeFi Network");
        registry.authorizeBank(address(maestro),   "MaestroNet");

        // 4. Registrar promos on-chain
        bancoRio.registerPromotions();
        bancoPcia.registerPromotions();
        visaDeFi.registerPromotions();
        maestro.registerPromotions();

        vm.stopBroadcast();

        // 5. Output - copiar estas addresses al bridge/.env
        console.log("=== VINCHI DEPLOY EXITOSO ===");
        console.log("PromotionRegistry:", address(registry));
        console.log("AgentRouter:      ", address(router));
        console.log("VinchiCard:       ", address(card));
        console.log("BancoRioDefi:     ", address(bancoRio));
        console.log("BancoProvinciaDefi:", address(bancoPcia));
        console.log("VisaDeFiNetwork:  ", address(visaDeFi));
        console.log("MaestroNet:       ", address(maestro));
        console.log("");
        console.log("Copia estas 2 lines en bridge/.env:");
        console.log(string.concat("AGENT_ROUTER_ADDRESS=",       vm.toString(address(router))));
        console.log(string.concat("PROMOTION_REGISTRY_ADDRESS=", vm.toString(address(registry))));
    }
}
