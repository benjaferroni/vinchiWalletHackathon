// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import Yield Protocol (Nacho)
import "../src/USDm.sol";
import "../src/USDmY.sol";
import "../src/USDManager.sol";
import "../src/USDv.sol";

// Import Clover POS (Agéntico)
import "../src/PromotionRegistry.sol";
import "../src/AgentRouter.sol";
import "../src/VinchiCard.sol";
import "../src/PaymentSettlement.sol";
import "../src/VinchiMerchant.sol";
import "../src/StoreRegistry.sol";
import "../src/OrderBook.sol";
// Import and Mock Banks
import "../src/MockBanks.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DeployAll is Script {
    // Definimos las variables a nivel de estado para evitar Stack Too Deep
    USDm public usdm;
    USDmY public usdmy;
    USDManager public usdManager;
    USDv public usdv;
    PromotionRegistry public promotionRegistry;
    AgentRouter public agentRouter;
    VinchiCard public vinchiCard;
    VinchiMerchant public vinchiMerchant;
    PaymentSettlement public paymentSettlement;
    StoreRegistry public storeRegistry;
    OrderBook public orderBook;
    BancoRioDefi public bancoRio;
    BancoProvinciaDefi public bancoProvincia;
    VisaDeFiNetwork public visaDeFi;
    MaestroNet public maestroNet;

    function run() external {
        vm.startBroadcast();

        // 1. USDm
        usdm = new USDm();
        
        // 2. USDmY
        usdmy = new USDmY(IERC20(address(usdm)));
        
        // 3 & 4. USDManager (deploya USDv internamente)
        usdManager = new USDManager(address(usdm), address(usdmy));
        usdv = usdManager.usdv(); // Recuperar la dirección del USDv interno
        
        // 5. PromotionRegistry
        promotionRegistry = new PromotionRegistry();
        
        // 6. AgentRouter
        agentRouter = new AgentRouter(address(promotionRegistry));
        
        // 7. VinchiCard
        vinchiCard = new VinchiCard(address(agentRouter));
        
        // 9. VinchiMerchant
        vinchiMerchant = new VinchiMerchant(address(usdv));

        // 8. PaymentSettlement
        paymentSettlement = new PaymentSettlement(address(usdv), address(vinchiMerchant));
        
        // 9.5. StoreRegistry
        storeRegistry = new StoreRegistry();

        // 9.6. OrderBook
        orderBook = new OrderBook(address(usdm), address(usdv));
        // 10. Banks
        bancoRio = new BancoRioDefi(address(promotionRegistry));
        bancoProvincia = new BancoProvinciaDefi(address(promotionRegistry));
        visaDeFi = new VisaDeFiNetwork(address(promotionRegistry));
        maestroNet = new MaestroNet(address(promotionRegistry));

        // 11. authorizeBank()
        promotionRegistry.authorizeBank(address(bancoRio), "BancoRio DeFi");
        promotionRegistry.authorizeBank(address(bancoProvincia), "BancoProvincia DeFi");
        promotionRegistry.authorizeBank(address(visaDeFi), "VisaDeFi Network");
        promotionRegistry.authorizeBank(address(maestroNet), "MaestroNet");

        // 12. registerPromotions()
        bancoRio.registerPromotions();
        bancoProvincia.registerPromotions();
        visaDeFi.registerPromotions();
        maestroNet.registerPromotions();

        vm.stopBroadcast();

        // Salida de consola para el .env
        console.log("-----------------------------------------");
        console.log("USDM_ADDRESS=%s", address(usdm));
        console.log("USDMY_ADDRESS=%s", address(usdmy));
        console.log("USDV_ADDRESS=%s", address(usdv));
        console.log("USDMANAGER_ADDRESS=%s", address(usdManager));
        console.log("PROMOTION_REGISTRY_ADDRESS=%s", address(promotionRegistry));
        console.log("AGENT_ROUTER_ADDRESS=%s", address(agentRouter));
        console.log("VINCHI_CARD_ADDRESS=%s", address(vinchiCard));
        console.log("PAYMENT_SETTLEMENT_ADDRESS=%s", address(paymentSettlement));
        console.log("VINCHI_MERCHANT_ADDRESS=%s", address(vinchiMerchant));
        console.log("STORE_REGISTRY_ADDRESS=%s", address(storeRegistry));
        console.log("ORDER_BOOK_ADDRESS=%s", address(orderBook));
        console.log("-----------------------------------------");
    }
}
