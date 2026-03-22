const CONTRACT_ADDRESSES = {
    USDm: '0x280872baF581e0e331d406611898C6d922f901a1',
    USDmY: '0xf08d9b9b5A4db67425dDe68996AC8bc058d53c89',
    USDManager: '0xe0394356154060b12bEaebcE70D1C626E190dE7D',
    USDv: '0xe326Ba63A57Aed0eE87f5D9935D718dCA15dfCB9',
    StoreRegistry: '0xc599916fa5F5E95B1cFA7707Ebb9c25669E677B0',
    PaymentSettlement: '0x2c6bfc656c79eFE0937C1093433E759C1eA04937',
    OrderBook: '0xb4aFF22Fa99eCA31De04e2fDa86e70e34AE24740'
};

const ABIS = {
    ERC20: [
        "function balanceOf(address owner) view returns (uint256)",
        "function decimals() view returns (uint8)",
        "function symbol() view returns (string)",
        "function approve(address spender, uint256 amount) returns (bool)",
        "function allowance(address owner, address spender) view returns (uint256)",
        "function transfer(address to, uint amount) returns (bool)"
    ],
    USDm: [
        "function mint(address to, uint256 amount) external"
    ],
    USDmY: [
        "function convertToAssets(uint256 shares) view returns (uint256)"
    ],
    USDv: [
        // USDv is a plain ERC20 — no extra functions beyond ABIS.ERC20
    ],
    USDManager: [
        "function depositUSDm(uint256 amount) external",
        "function claimYield(uint256 amountUSDv) external"
    ],
    StoreRegistry: [
        "function createStore(string name, string color, address recipient) returns (bytes32)",
        "function getAllStores() external view returns (tuple(bytes32 storeId, string name, string color, address creator, address recipient, bool active)[])",
        "function getStore(bytes32 storeId) external view returns (tuple(bytes32 storeId, string name, string color, address creator, address recipient, bool active))"
    ]
};
