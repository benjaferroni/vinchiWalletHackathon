require("dotenv").config();
const express    = require("express");
const cors       = require("cors");
const { ethers } = require("ethers");

const app = express();
app.use(express.json());
app.use(cors({ origin: "*", methods: ["GET", "POST"] }));

// ── Config ───────────────────────────────────────────────────
const PORT      = process.env.PORT || 3001;
const DEMO_MODE = process.env.DEMO_MODE === "true";

const RPC_URL         = process.env.FUJI_RPC_URL || "https://api.avax-test.network/ext/bc/C/rpc";
const ROUTER_ADDR     = process.env.AGENT_ROUTER_ADDRESS;
const SETTLEMENT_ADDR = process.env.PAYMENT_SETTLEMENT_ADDRESS;
const USDV_ADDR       = process.env.USDV_ADDRESS;
const STORE_REGISTRY_ADDR = process.env.STORE_REGISTRY_ADDRESS;
const ORDER_BOOK_ADDR = process.env.ORDER_BOOK_ADDRESS;
const OPERATOR_PK     = process.env.OPERATOR_PRIVATE_KEY;

// ── ABI mínimo de AgentRouter, Settlement y USDv ─────────────
const AGENT_ROUTER_ABI = [
  {
    inputs: [{
      components: [
        { name: "storeId",    type: "bytes32" },
        { name: "categoryId", type: "bytes32" },
        { name: "amount",     type: "uint256" },
        { name: "dayOfWeek",  type: "uint8"   },
      ],
      name: "ctx", type: "tuple",
    }],
    name: "findBestPromotion",
    outputs: [{
      components: [
        { name: "promoId",          type: "uint256" },
        { name: "bankOrNetwork",    type: "address" },
        { name: "bankName",         type: "string"  },
        { name: "discountBps",      type: "uint256" },
        { name: "originalAmount",   type: "uint256" },
        { name: "discountedAmount", type: "uint256" },
        { name: "savedAmount",      type: "uint256" },
        { name: "description",      type: "string"  },
        { name: "score",            type: "uint256" },
      ],
      name: "result", type: "tuple",
    }],
    stateMutability: "view",
    type: "function",
  }
];

const SETTLEMENT_ABI = [
  "function settlePayment(bytes32 storeId, address merchantAddress, address payer, uint256 grossAmount, uint256 netAmount, uint256 discountBps, uint256 promoId, address bankUsed) external"
];

const USDV_ABI = [
  "function balanceOf(address account) external view returns (uint256)"
];

const STORE_REGISTRY_ABI = [
  "function getAllStores() external view returns (tuple(bytes32 storeId, string name, string color, address creator, address recipient, bool active)[])",
  "function getStore(bytes32 storeId) external view returns (tuple(bytes32 storeId, string name, string color, address creator, address recipient, bool active))"
];

const ORDER_BOOK_ABI = [
  "function getOpenOrders() view returns (tuple(uint256 id, address creator, uint8 orderType, uint256 amountOffered, uint256 amountWanted, uint8 status, uint256 createdAt)[])",
  "function getOrder(uint256 orderId) view returns (tuple(uint256 id, address creator, uint8 orderType, uint256 amountOffered, uint256 amountWanted, uint8 status, uint256 createdAt))"
];

// ── Inicializar conexión al contrato ─────────────────────────
let provider;
let routerContract;
let settlementContract;
let usdvContract;
let storeRegistryContract;
let orderBookContract;

if (!DEMO_MODE) {
  provider       = new ethers.JsonRpcProvider(RPC_URL);
  
  if (ROUTER_ADDR && ROUTER_ADDR.startsWith("0x")) {
    routerContract = new ethers.Contract(ROUTER_ADDR, AGENT_ROUTER_ABI, provider);
  }
  
  if (OPERATOR_PK && SETTLEMENT_ADDR && SETTLEMENT_ADDR.startsWith("0x")) {
    const operatorWallet = new ethers.Wallet(OPERATOR_PK, provider);
    settlementContract = new ethers.Contract(SETTLEMENT_ADDR, SETTLEMENT_ABI, operatorWallet);
  }

  if (USDV_ADDR && USDV_ADDR.startsWith("0x")) {
    usdvContract = new ethers.Contract(USDV_ADDR, USDV_ABI, provider);
  }

  if (STORE_REGISTRY_ADDR && STORE_REGISTRY_ADDR.startsWith("0x")) {
    storeRegistryContract = new ethers.Contract(STORE_REGISTRY_ADDR, STORE_REGISTRY_ABI, provider);
  }

  if (ORDER_BOOK_ADDR && ORDER_BOOK_ADDR.startsWith("0x")) {
    orderBookContract = new ethers.Contract(ORDER_BOOK_ADDR, ORDER_BOOK_ABI, provider);
  }

  console.log("[vinchi] Conectado a Fuji Testnet:", RPC_URL);
}

// ── Scoring local (fallback / DEMO_MODE) ─────────────────────
const PROMO_TYPE   = { CASHBACK:0, DISCOUNT:1, INSTALLMENTS:2, POINTS:3, TWOXONE:4 };
const DAY_EVERYDAY = 7;
const TYPE_WEIGHT  = { 0:15, 1:14, 4:13, 2:12, 3:10 };

const MOCK_PROMOS = [
  { id:1,  bankName:"BancoRío DeFi",    category:"supermercado",   discountBps:1500, type:0, day:3, maxDiscount:5000,  minPurchase:1000, desc:"BancoRío DeFi: 15% cashback en supermercados los jueves. Tope $5.000" },
  { id:2,  bankName:"BancoRío DeFi",    category:"combustible",    discountBps:1000, type:0, day:7, maxDiscount:3000,  minPurchase:0,    desc:"BancoRío DeFi: 10% cashback en combustible, sin monto mínimo" },
  { id:3,  bankName:"BancoPcia DeFi",   category:"farmacia",       discountBps:2000, type:0, day:7, maxDiscount:8000,  minPurchase:500,  desc:"BancoPcia DeFi: 20% reintegro en farmacias todos los días. Tope $8.000" },
  { id:4,  bankName:"BancoPcia DeFi",   category:"restaurante",    discountBps:2500, type:1, day:2, maxDiscount:10000, minPurchase:0,    desc:"BancoPcia DeFi: 25% off en restaurantes los miércoles" },
  { id:5,  bankName:"BancoPcia DeFi",   category:"supermercado",   discountBps:1500, type:0, day:1, maxDiscount:6000,  minPurchase:800,  desc:"BancoPcia DeFi: 15% cashback en supermercados los martes. Tope $6.000" },
  { id:6,  bankName:"VisaDeFi Network", category:"electronica",    discountBps:1000, type:1, day:5, maxDiscount:20000, minPurchase:1500, desc:"VisaDeFi: 10% off en electrónica los sábados. Tope $20.000" },
  { id:7,  bankName:"VisaDeFi Network", category:"electronica",    discountBps:1000, type:1, day:6, maxDiscount:20000, minPurchase:1500, desc:"VisaDeFi: 10% off en electrónica los domingos. Tope $20.000" },
  { id:8,  bankName:"VisaDeFi Network", category:"viajes",         discountBps:0,    type:2, day:7, maxDiscount:0,     minPurchase:5000, desc:"VisaDeFi: 3 cuotas sin interés en agencias de viaje. Mínimo $5.000" },
  { id:9,  bankName:"MaestroNet",       category:"indumentaria",   discountBps:0,    type:2, day:7, maxDiscount:0,     minPurchase:2000, desc:"MaestroNet: 6 cuotas sin interés en indumentaria. Mínimo $2.000" },
  { id:10, bankName:"MaestroNet",       category:"entretenimiento",discountBps:5000, type:4, day:0, maxDiscount:0,     minPurchase:0,    desc:"MaestroNet: 2x1 en cines y entretenimiento los lunes" },
  { id:11, bankName:"MaestroNet",       category:"delivery",       discountBps:1200, type:0, day:4, maxDiscount:4000,  minPurchase:0,    desc:"MaestroNet: 12% cashback en delivery los viernes. Tope $4.000" },
  { id:12, bankName:"MaestroNet",       category:"delivery",       discountBps:1200, type:0, day:5, maxDiscount:4000,  minPurchase:0,    desc:"MaestroNet: 12% cashback en delivery los sábados. Tope $4.000" },
];

function localScore(p) {
  if (!p.discountBps) return 0;
  return (p.discountBps * (TYPE_WEIGHT[p.type] || 10) * (p.day === DAY_EVERYDAY ? 10 : 12)) / 100;
}

function localFindBest(category, amount, day) {
  const candidates = MOCK_PROMOS
    .filter(p =>
      p.category === category &&
      (p.day === DAY_EVERYDAY || p.day === day) &&
      (p.minPurchase === 0 || amount >= p.minPurchase)
    )
    .map(p => ({ ...p, score: localScore(p) }))
    .sort((a, b) => b.score - a.score);

  if (!candidates.length) {
    return {
      promoId: 0, bankOrNetwork: null, bankName: null, discountBps: 0,
      originalAmount: amount, discountedAmount: amount, savedAmount: 0,
      description: "Sin promociones disponibles", score: 0,
    };
  }

  const best = candidates[0];
  let disc = Math.round((amount * best.discountBps) / 10000);
  if (best.maxDiscount > 0 && disc > best.maxDiscount) disc = best.maxDiscount;

  return {
    promoId:          best.id,
    bankOrNetwork:    "0xLOCAL",
    bankName:         best.bankName,
    discountBps:      best.discountBps,
    originalAmount:   amount,
    discountedAmount: amount - disc,
    savedAmount:      disc,
    description:      best.desc,
    score:            best.score,
    source:           "local-demo",
  };
}

// ── Routes ───────────────────────────────────────────────────

app.get("/health", async (_req, res) => {
  let chainInfo = null;
  if (!DEMO_MODE && provider) {
    try {
      const network = await provider.getNetwork();
      chainInfo = { chainId: network.chainId.toString(), name: network.name };
    } catch {}
  }
  res.json({
    status:      "ok",
    mode:        DEMO_MODE ? "demo" : "blockchain",
    rpc:         DEMO_MODE ? null : RPC_URL,
    chain:       chainInfo,
    timestamp:   new Date().toISOString(),
  });
});

app.post("/api/route", async (req, res) => {
  const t0 = Date.now();
  try {
    const { category, amount, dayOfWeek } = req.body;

    if (!category) return res.status(400).json({ success:false, error:"category requerida" });
    if (!amount || amount <= 0) return res.status(400).json({ success:false, error:"amount debe ser positivo" });

    const day = typeof dayOfWeek === "number" ? dayOfWeek : (new Date().getDay() + 6) % 7;

    let result;

    if (!DEMO_MODE && routerContract) {
      const categoryId = ethers.keccak256(ethers.toUtf8Bytes(category));
      const storeId    = ethers.keccak256(ethers.toUtf8Bytes(req.body.storeId || "vinchi-comercio-1"));
      const amountBN = ethers.parseEther(amount.toString());

      const raw = await routerContract.findBestPromotion({
        storeId,
        categoryId,
        amount:    amountBN,
        dayOfWeek: day,
      });

      const savedRaw = Number(ethers.formatEther(raw.savedAmount));
      const discBps  = Number(raw.discountBps);

      result = {
        promoId:          Number(raw.promoId),
        bankOrNetwork:    raw.bankOrNetwork,
        bankName:         raw.bankName,
        discountBps:      discBps,
        originalAmount:   amount,
        discountedAmount: amount - savedRaw,
        savedAmount:      savedRaw,
        description:      raw.description,
        score:            Number(raw.score),
        source:           "blockchain",
      };
    } else {
      result = localFindBest(category, amount, day);
    }

    result.latencyMs = Date.now() - t0;
    res.json({ success: true, data: result });

  } catch (err) {
    console.error("[/api/route]", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post("/api/settle", async (req, res) => {
  try {
    const { storeId, merchantAddress, payer, grossAmount, netAmount, discountBps, promoId, bankUsed } = req.body;

    if (DEMO_MODE || !settlementContract) {
      return res.json({ success: true, txHash: "0xLOCAL_TX_HASH", mode: "demo" });
    }

    const _storeId = storeId.startsWith("0x")
      ? storeId
      : ethers.keccak256(ethers.toUtf8Bytes(storeId || "vinchi-comercio"));
    const _gross = ethers.parseEther(grossAmount.toString());
    const _net = ethers.parseEther(netAmount.toString());

    // Call Fuji PaymentSettlement
    const tx = await settlementContract.settlePayment(
      _storeId, 
      merchantAddress,
      payer, 
      _gross, 
      _net, 
      discountBps || 0, 
      promoId || 0, 
      bankUsed || ethers.ZeroAddress
    );
    
    // Wait for 1 confirmation
    const receipt = await tx.wait();

    res.json({ success: true, txHash: receipt.hash });
  } catch (err) {
    console.error("[/api/settle]", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// NUEVO: APIs de Stores
app.get("/api/stores", async (req, res) => {
  try {
    if (DEMO_MODE || !storeRegistryContract) {
      return res.json([{ storeId: "vinchi-comercio", name: "Vinchi Demo Store", color: "#00a651", creator: "0xLOCAL", recipient: "0xLOCAL", active: true }]);
    }
    const stores = await storeRegistryContract.getAllStores();
    const result = stores.map(s => ({
      storeId: s.storeId,
      name: s.name,
      color: s.color,
      creator: s.creator,
      recipient: s.recipient, // IMPORTANTE: retornar recipient
      active: s.active
    }));
    res.json(result);
  } catch (err) {
    console.error("[/api/stores]", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get("/api/stores/:storeId", async (req, res) => {
  try {
    if (DEMO_MODE || !storeRegistryContract) {
      return res.json({ storeId: req.params.storeId, name: "Vinchi Demo Store", color: "#00a651", creator: "0xLOCAL", recipient: "0xLOCAL", active: true });
    }
    const store = await storeRegistryContract.getStore(req.params.storeId);
    res.json({
      storeId: store.storeId,
      name: store.name,
      color: store.color,
      creator: store.creator,
      recipient: store.recipient,
      active: store.active
    });
  } catch (err) {
    console.error(`[/api/stores/${req.params.storeId}]`, err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post("/api/stores/create", async (req, res) => {
  try {
    const { name, color, recipient } = req.body;
    res.json({
      contractAddress: STORE_REGISTRY_ADDR || "0xLOCAL_STORE_REG",
      abi: STORE_REGISTRY_ABI,
      functionName: "createStore",
      args: [name, color, recipient]
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// NUEVO: APIs de OrderBook
app.get("/api/orderbook", async (req, res) => {
  try {
    if (DEMO_MODE || !orderBookContract) {
      return res.json([]);
    }
    const orders = await orderBookContract.getOpenOrders();
    const result = orders.map(o => ({
      id: o.id.toString(),
      creator: o.creator,
      orderType: Number(o.orderType),
      amountOffered: o.amountOffered.toString(),
      amountWanted: o.amountWanted.toString(),
      status: Number(o.status),
      createdAt: o.createdAt.toString()
    }));
    res.json(result);
  } catch (err) {
    console.error("[/api/orderbook]", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// NUEVO: Obtener Balance de USDv
app.get("/api/balance/:address", async (req, res) => {
  try {
    if (DEMO_MODE || !usdvContract) {
       return res.json({ balance: 0, mode: "demo" });
    }
    const balWei = await usdvContract.balanceOf(req.params.address);
    const balNum = Number(ethers.formatEther(balWei));
    res.json({ balance: balNum });
  } catch (err) {
    console.error(`[/api/balance/${req.params.address}]`, err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get("/api/stats", (_req, res) => {
  res.json({ success: true, data: { message: "Stats desde blockchain Fuji próximamente" } });
});

// ── Start ─────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`
╔══════════════════════════════════════════════╗
║   Vinchi Bridge API — Fuji C-Chain           ║
╚══════════════════════════════════════════════╝
  Puerto : ${PORT}
  Modo   : ${DEMO_MODE ? "DEMO (scoring JS local)" : "BLOCKCHAIN (Avalanche Fuji)"}
  RPC    : ${DEMO_MODE ? "—" : RPC_URL}
`);
});
