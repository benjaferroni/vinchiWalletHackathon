const fs = require('fs');

const path = 'C:/Users/bferr/vinchi-hackathon/vinchiFujiTestnet/broadcast/DeployAll.s.sol/43113/run-latest.json';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));

const nameMap = {
    'USDm': 'USDM_ADDRESS',
    'USDmY': 'USDMY_ADDRESS',
    'USDv': 'USDV_ADDRESS',
    'USDManager': 'USDMANAGER_ADDRESS',
    'PromotionRegistry': 'PROMOTION_REGISTRY_ADDRESS',
    'AgentRouter': 'AGENT_ROUTER_ADDRESS',
    'VinchiCard': 'VINCHI_CARD_ADDRESS',
    'PaymentSettlement': 'PAYMENT_SETTLEMENT_ADDRESS',
    'VinchiMerchant': 'VINCHI_MERCHANT_ADDRESS'
};

const results = {};

for (const tx of data.transactions) {
    if (tx.transactionType === 'CREATE' && tx.contractName) {
        if (nameMap[tx.contractName]) {
            results[nameMap[tx.contractName]] = tx.contractAddress;
        }
    }
    
    // Also check additionalContracts for things created via factory (like USDv)
    if (tx.additionalContracts) {
        for (const additional of tx.additionalContracts) {
            if (additional.transactionType === 'CREATE' && nameMap[additional.contractName]) {
                results[nameMap[additional.contractName]] = additional.address;
            }
        }
    }
}

console.log("Copia estas líneas y pégalas en tu archivo bridge/.env:");
console.log("-----------------------------------------");
for (const envName of Object.values(nameMap)) {
    if (results[envName]) {
        console.log(`${envName}=${results[envName]}`);
    }
}
console.log("-----------------------------------------");
