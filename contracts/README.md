# Vinchi Smart Promotions & Web3 Wallet

Welcome to the **Vinchi** ecosystem! This project integrates a Web3 Wallet with a Smart Promotions Point of Sale (POS) system. It allows users to generate yield on their stablecoins and seamlessly spend them at physical or online merchants while automatically applying the best available bank discounts and promotions.

**Important:** All smart contracts in this repository are **live on the Avalanche Fuji Testnet**.

## 🚀 Live on Avalanche Fuji Testnet
The entire architecture is deployed and fully functional on the Avalanche Fuji C-Chain. Transactions, yield generation, P2P order settlements, and payment routing occur on-chain in real time. 

Key Contracts:
- `USDm` (Mock USD Token)
- `USDv` (Vinchi Spendable Token)
- `USDManager` (Yield Strategy Manager)
- `PaymentSettlement` (Payment Routing & Settlement)
- `StoreRegistry` (Merchant On-chain Registry)
- `OrderBook` (P2P Exchange)

## 📌 Project Architecture & Flow

### 1. The Vinchi Wallet (User Journey)
- **Faucet:** Users mint mock `USDm` tokens on the Fuji Testnet to simulate having stablecoin funds.
- **Deposit & Yield:** Users deposit their `USDm` into the **Vinchi Wallet**. The tokens are locked into a strategy that generates yield over time.
- **Spendable Balance (`USDv`):** Upon depositing `USDm`, users are credited with `USDv`, which represents their max spendable limit including projected future yield.
- **P2P Orderbook:** Users can trade `USDm` for `USDv` (or vice-versa) directly with other users on an on-chain, decentralized order book.

### 2. Merchant Store Registry
- **On-chain Stores:** Merchants can connect their wallets and use the "Store Management" view (Merchant Mode) to register their business on the `StoreRegistry` smart contract.
- This links a real-world store name and category to an Avalanche wallet address that will act as the settlement destination.

### 3. Smart Promotions POS (Clover Integration)
- **POS Simulator:** Cashiers use the Clover POS Interface (simulated locally) to ring up sales. They enter the amount and the business category (e.g., Supermarket, Pharmacy, Electronics).
- **AgentRouter (Backend):** When the cashier confirms the sale, the app pings the Vinchi backend. The `AgentRouter` dynamically analyzes the current day, amount, and category to find the absolute best bank promotion or discount available for that specific transaction.
- **Payment Settlement:** Once the optimal promotion is selected, the user signs the transaction via MetaMask. The `PaymentSettlement` smart contract executes the payment on the Fuji Testnet, transferring the exact discounted amount in `USDv` to the merchant's registered wallet.

## 🛠 Setup & Installation

To run the frontend and backend bridge locally:

1. **Clone the repository:**
   ```bash
   git clone <YOUR_GITHUB_REPO_URL>
   cd vinchiFujiTestnet
   ```

2. **Frontend:**
   You can serve the `frontend/` directory using any local HTTP server. For example:
   ```bash
   cd frontend
   npx serve .
   # or with python
   python -m http.server 8000
   ```
   Open `http://localhost:8000` in your browser.

3. **Backend Bridge (AgentRouter):**
   Navigate to the backend or bridge directory (if applicable), install dependencies, and run:
   ```bash
   npm install
   npm start
   ```
   By default, the frontend expects the bridge API to be running at `http://localhost:3001`.

## ⚙️ Testing the Flow
1. Open the Vinchi Wallet and connect MetaMask (make sure you are on the **Avalanche Fuji Testnet**).
2. Go to the **Faucet** tab and mint `USDm`.
3. Go back to the **Dashboard** and Deposit your `USDm`. Notice how your `USDv` balance increases.
4. Open the **Clover POS** (click the green button floating on the right edge).
5. Select a category, enter an amount, and process a payment.
6. Confirm the MetaMask transaction to settle the payment on the Fuji blockchain.

## 📄 License
MIT License
