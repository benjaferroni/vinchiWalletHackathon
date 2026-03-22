// Configuration
const CONFIG = {
    monthsElapsed: 1, // Simulate 1 month yield for visualization
    yieldRates: {
        standard: 0.03  // 3% monthly
    },
    network: {
        chainId: '0xa869', // 43113 = Avalanche Fuji Testnet
        chainName: 'Avalanche Fuji Testnet',
        rpcUrls: ['https://api.avax-test.network/ext/bc/C/rpc'],
        nativeCurrency: {
            name: 'Avalanche',
            symbol: 'AVAX',
            decimals: 18
        },
        blockExplorerUrls: ['https://subnets-test.avax.network/c-chain']
    }
};

// Gas overrides - allowing Ethers to auto-calculate EIP-1559 gas fees
const TX_OVERRIDES = {}; 

// Application State
let globalState = {
    walletConnected: false,
    walletAddress: '',
    lastProviderUuid: '',
    users: {} // Mapping of address -> { usdmDeposited, yieldRate, riskLevel, walletBalanceUSDm }
};

// Default user state template
const defaultUserState = () => ({
    usdmDeposited: 0,
    yieldRate: CONFIG.yieldRates.standard,
    walletBalanceUSDm: 0,
    role: 'personal'
});

// Helper to get current user state
const getCurrentUserState = () => {
    if (!globalState.walletAddress) return defaultUserState();
    const addrStr = globalState.walletAddress.toLowerCase();
    if (!globalState.users[addrStr]) {
        globalState.users[addrStr] = defaultUserState();
    }
    return globalState.users[addrStr];
};

// DOM Elements
const EL = {
    // Dashboard Top
    btnConnect: document.getElementById('btnConnect'),
    walletAddressDisplay: document.getElementById('walletAddressDisplay'),

    // Dashboard Balances
    usdmBalance: document.getElementById('usdmBalance'),
    yieldBalance: document.getElementById('yieldBalance'),
    totalBalance: document.getElementById('totalBalance'),
    usdmProgress: document.getElementById('usdmProgress'),
    yieldProgress: document.getElementById('yieldProgress'),
    dashboardWalletBalance: document.getElementById('dashboardWalletBalance'),
    balanceBreakdown: document.getElementById('balanceBreakdown'),
    progressContainer: document.getElementById('progressContainer'),

    // Role Toggle UI
    roleToggle: document.getElementById('roleToggle'),
    roleLabel: document.getElementById('roleLabel'),

    // Actions
    btnDepositAction: document.getElementById('btnDepositAction'),

    // Modals
    overlay: document.getElementById('overlay'),
    depositModal: document.getElementById('depositModal'),
    sendModal: document.getElementById('sendModal'),

    // Modal Inputs
    depositAmount: document.getElementById('depositAmount'),
    sendAmount: document.getElementById('sendAmount'),
    recipientAddress: document.getElementById('recipientAddress'),

    // Modal Preview
    projectedLimit: document.getElementById('projectedLimit'),
    previewRate: document.getElementById('previewRate'),

    // Faucet Elements
    mockWalletBalance: document.getElementById('mockWalletBalance'),
    btnMint: document.getElementById('btnMint'),
    faucetNote: document.getElementById('faucetNote'),

    // Toast
    toast: document.getElementById('toast')
};

// Load State from LocalStorage
const loadState = () => {
    const saved = localStorage.getItem('vinchiGlobalState');
    if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed.users) {
            globalState.users = parsed.users;
        }
        if (parsed.lastProviderUuid) {
            globalState.lastProviderUuid = parsed.lastProviderUuid;
        }
    }
};

const saveState = () => {
    const dataToSave = {
        users: globalState.users,
        lastProviderUuid: globalState.lastProviderUuid
    };
    localStorage.setItem('vinchiGlobalState', JSON.stringify(dataToSave));
};

// Utility: Currency Formatter
const formatCurrency = (value) => {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    }).format(value);
};

// Utility: Shorten Address
const shortenAddress = (addr) => {
    if (!addr) return '';
    return `${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}`;
};

// UI: Toast Notification
const showToast = (message) => {
    if (!EL.toast) return;
    EL.toast.textContent = message;
    EL.toast.classList.add('show');
    setTimeout(() => {
        EL.toast.classList.remove('show');
    }, 3000);
};

// --- EIP-6963 Multi-Wallet Integration ---

// --- Ethers Setup ---
const getContracts = async () => {
    if (!activeProvider && typeof window.ethereum === 'undefined') return null;

    // We must use activeProvider (which is from EIP-6963) or window.ethereum
    const provider = new ethers.BrowserProvider(activeProvider || window.ethereum);
    const signer = await provider.getSigner();

    return {
        usdm: new ethers.Contract(CONTRACT_ADDRESSES.USDm, ABIS.ERC20.concat(ABIS.USDm), signer),
        usdmY: new ethers.Contract(CONTRACT_ADDRESSES.USDmY, ABIS.USDmY, provider), // keep as provider if read-only, or make signer if needed
        usdv: new ethers.Contract(CONTRACT_ADDRESSES.USDv, ABIS.ERC20, signer),
        manager: new ethers.Contract(CONTRACT_ADDRESSES.USDManager, ABIS.USDManager, signer)
    };
};

let detectedProviders = [];
let activeProvider = null; // The selected provider object

const disconnectWallet = () => {
    globalState.walletConnected = false;
    globalState.walletAddress = '';
    globalState.lastProviderUuid = '';
    activeProvider = null;
    saveState();
    updateWalletUI();
    updateDashboard();
    showToast('Wallet Disconnected');
};

const checkAndSwitchNetwork = async () => {
    if (!activeProvider && typeof window.ethereum === 'undefined') return;
    const provider = activeProvider || window.ethereum;

    try {
        const chainId = await provider.request({ method: 'eth_chainId' });
        if (chainId.toLowerCase() !== CONFIG.network.chainId.toLowerCase()) {
            try {
                await provider.request({
                    method: 'wallet_switchEthereumChain',
                    params: [{ chainId: CONFIG.network.chainId }]
                });
            } catch (switchError) {
                if (switchError.code === 4902) {
                    try {
                        await provider.request({
                            method: 'wallet_addEthereumChain',
                            params: [CONFIG.network]
                        });
                    } catch (addError) {
                        console.error("Error adding network", addError);
                    }
                } else {
                    console.error("Error switching network", switchError);
                }
            }
        }
    } catch (e) {
        console.error("Error checking network", e);
    }
};

const handleAccountsChanged = (accounts) => {
    console.log("[Wallet] Accounts changed event:", accounts);
    if (!accounts || accounts.length === 0) {
        // User locked or disconnected their wallet from the extension
        disconnectWallet();
    } else {
        const newAddress = accounts[0].toLowerCase();
        const currentAddress = (globalState.walletAddress || '').toLowerCase();

        if (newAddress !== currentAddress) {
            console.log("[Wallet] Address switched:", currentAddress, "->", newAddress);
            globalState.walletConnected = true;
            globalState.walletAddress = newAddress;

            saveState();
            getCurrentUserState();

            updateWalletUI();
            updateDashboard();
            showToast(`Active Account: ${shortenAddress(newAddress)}`);
            closeModals();

            checkAndSwitchNetwork();
        }
    }
};

const setupProviderListeners = (provider) => {
    if (!provider) return;

    // ALWAYS bind to window.ethereum to ensure we catch generic MetaMask events
    if (window.ethereum && window.ethereum.on) {
        try { window.ethereum.removeListener('accountsChanged', handleAccountsChanged); } catch (e) { }
        window.ethereum.on('accountsChanged', handleAccountsChanged);
        
        try { window.ethereum.removeListener('chainChanged', handleChainChanged); } catch (e) { }
        window.ethereum.on('chainChanged', handleChainChanged);
    }

    // Bind event directly to the active provider (e.g. EIP-6963 provider) too
    if (provider.on && provider !== window.ethereum) {
        try { provider.removeListener('accountsChanged', handleAccountsChanged); } catch (e) { }
        provider.on('accountsChanged', handleAccountsChanged);

        try { provider.removeListener('chainChanged', handleChainChanged); } catch (e) { }
        provider.on('chainChanged', handleChainChanged);
    }

    // Fallback: Some wallet versions (especially MetaMask on localhost) don't fire events reliably.
    // Start a lightweight polling interval to guarantee detection.
    startAccountPolling();
};

let accountPollInterval = null;
const startAccountPolling = () => {
    if (accountPollInterval) clearInterval(accountPollInterval);

    // Reduced polling interval to 500ms for a more "immediate" feel if events fail
    accountPollInterval = setInterval(async () => {
        if (!activeProvider && typeof window.ethereum === 'undefined') return;

        const providerToPoll = activeProvider || window.ethereum;
        if (!providerToPoll) return;

        try {
            const accounts = await providerToPoll.request({ method: 'eth_accounts' });
            if (accounts && accounts.length > 0) {
                const currentStr = (globalState.walletAddress || '').toLowerCase();
                const newStr = accounts[0].toLowerCase();
                if (currentStr && newStr !== currentStr) {
                    console.log("[Wallet Polling] Detected account change!", currentStr, "->", newStr);
                    handleAccountsChanged(accounts);
                }
            } else if (globalState.walletConnected) {
                console.log("[Wallet Polling] Detected disconnect/lock");
                handleAccountsChanged([]);
            }
        } catch (e) { /* silent fail on polling */ }
    }, 500);
};

const handleChainChanged = () => {
    window.location.reload();
};

// EIP-6963 listener
window.addEventListener("eip6963:announceProvider", async (event) => {
    const detail = event.detail;
    if (!detectedProviders.find(p => p.info.uuid === detail.info.uuid)) {
        detectedProviders.push(detail);
        renderWalletList();

        // Auto-connect fallback via UUID
        if (globalState.lastProviderUuid === detail.info.uuid && !globalState.walletConnected) {
            try {
                const accounts = await detail.provider.request({ method: 'eth_accounts' });
                if (accounts && accounts.length > 0) {
                    activeProvider = detail.provider;
                    setupProviderListeners(activeProvider);
                    handleAccountsChanged(accounts);
                }
            } catch (e) {
                console.error("[Wallet] Auto-connect failed for EIP-6963 provider", detail.info.name, e);
            }
        }
    }
});

// Announce ourselves to wallets that load late
window.dispatchEvent(new Event("eip6963:requestProvider"));

const renderWalletList = () => {
    const walletListEl = document.getElementById('walletList');
    if (!walletListEl) return;

    walletListEl.innerHTML = '';

    if (detectedProviders.length === 0) {
        walletListEl.innerHTML = `
            <p style="color:var(--text-muted); text-align:center; padding: 20px;">
                No web3 wallets detected in your browser.<br>
                Please install a wallet extension like MetaMask, Rabby, or Brave.
            </p>
            <a href="https://metamask.io/download/" target="_blank" class="btn btn-primary" style="text-decoration:none; margin-top: 10px;">
                Install MetaMask
            </a>
        `;
        return;
    }

    detectedProviders.forEach(providerDetail => {
        const btn = document.createElement('button');
        btn.className = 'wallet-list-btn';
        btn.innerHTML = `
            <img src="${providerDetail.info.icon}" alt="${providerDetail.info.name}" class="wallet-icon">
            <span>${providerDetail.info.name}</span>
        `;

        btn.onclick = async () => {
            try {
                activeProvider = providerDetail.provider;

                // Force MetaMask to allow selecting different accounts:
                if (providerDetail.info.name.toLowerCase().includes('metamask')) {
                    try {
                        await activeProvider.request({
                            method: 'wallet_requestPermissions',
                            params: [{ eth_accounts: {} }]
                        });
                    } catch (e) {
                        console.log("User cancelled permission request or not supported", e);
                        // continue to normal request if they just cancelled the switch but still want to connect
                    }
                }

                const accounts = await activeProvider.request({ method: 'eth_requestAccounts' });

                globalState.lastProviderUuid = providerDetail.info.uuid;
                saveState();

                setupProviderListeners(activeProvider);
                handleAccountsChanged(accounts);
            } catch (error) {
                console.error("Connection error:", error);
                showToast(`Connection to ${providerDetail.info.name} failed.`);
            }
        };

        walletListEl.appendChild(btn);
    });
};

window.toggleWallet = () => {
    if (globalState.walletConnected) {
        disconnectWallet();
        return;
    }

    // Show selection modal
    renderWalletList();
    const overlay = document.getElementById('overlay');
    const modal = document.getElementById('walletSelectionModal');
    if (overlay && modal) {
        overlay.classList.add('active');
        modal.classList.add('active');
    }
};

// Check if already connected on load (Aggressive verification)
const checkConnection = async () => {
    // 1. Give window.ethereum EIP-1193 standard listeners immediately
    if (typeof window.ethereum !== 'undefined' && window.ethereum.on) {
        try { window.ethereum.removeListener('accountsChanged', handleAccountsChanged); } catch (e) { }
        window.ethereum.on('accountsChanged', handleAccountsChanged);
        console.log("[Wallet] Bound default window.ethereum listeners early");
    }

    // 2. Try standard window.ethereum immediately for the fastest response
    if (!globalState.walletConnected && typeof window.ethereum !== 'undefined') {
        try {
            const accounts = await window.ethereum.request({ method: 'eth_accounts' });
            if (accounts && accounts.length > 0) {
                activeProvider = window.ethereum;
                setupProviderListeners(activeProvider);
                handleAccountsChanged(accounts);
                return; // exit early if successful
            }
        } catch (e) {
            console.error("[Wallet] Fast window.ethereum check failed:", e);
        }
    }

    // 3. Secondary pass: Iterate over any detected providers after a small delay
    setTimeout(async () => {
        if (!globalState.walletConnected) {
            for (const p of detectedProviders) {
                try {
                    const accounts = await p.provider.request({ method: 'eth_accounts' });
                    if (accounts && accounts.length > 0) {
                        activeProvider = p.provider;
                        setupProviderListeners(activeProvider);
                        handleAccountsChanged(accounts);
                        break;
                    }
                } catch (e) { }
            }
        }
    }, 800);
};

// --- Full UI Update ---

const updateWalletUI = async () => {
    const user = getCurrentUserState();

    // Update Header
    if (EL.btnConnect && EL.walletAddressDisplay) {
        if (globalState.walletConnected) {
            EL.btnConnect.style.display = 'none';
            EL.walletAddressDisplay.style.display = 'block';
            EL.walletAddressDisplay.textContent = shortenAddress(globalState.walletAddress);
        } else {
            EL.btnConnect.style.display = 'block';
            EL.walletAddressDisplay.style.display = 'none';
        }
    }

    // Update Faucet Page if active
    if (globalState.walletConnected) {
        try {
            const contracts = await getContracts();
            if (contracts) {
                const balWei = await contracts.usdm.balanceOf(globalState.walletAddress);
                const bal = parseFloat(ethers.formatEther(balWei));
                user.walletBalanceUSDm = bal;
                if (EL.mockWalletBalance) {
                    EL.mockWalletBalance.textContent = formatCurrency(bal);
                }
                if (EL.dashboardWalletBalance) {
                    EL.dashboardWalletBalance.textContent = formatCurrency(bal);
                }
            }
        } catch (e) { console.error("Error fetching USDm balance:", e); }

        if (EL.btnMint) EL.btnMint.disabled = false;
        if (EL.faucetNote) EL.faucetNote.style.display = 'none';
    } else {
        if (EL.mockWalletBalance) EL.mockWalletBalance.textContent = formatCurrency(0);
        if (EL.dashboardWalletBalance) EL.dashboardWalletBalance.textContent = formatCurrency(0);
        if (EL.btnMint) EL.btnMint.disabled = true;
        if (EL.faucetNote) EL.faucetNote.style.display = 'block';
    }
};

// Faucet Interaction
window.mintTestUSDm = async () => {
    if (!globalState.walletConnected) return;

    try {
        const contracts = await getContracts();
        if (!contracts) {
            console.error("Could not get contracts");
            return;
        }

        console.log("Requesting Mint from:", globalState.walletAddress);
        const amountWei = ethers.parseEther("1000");

        showToast("Minting 1,000 USDm... Please confirm in your wallet.");

        // Make sure we get a fresh signer
        const tx = await contracts.usdm.mint(globalState.walletAddress, amountWei, TX_OVERRIDES);
        console.log("Tx sent:", tx.hash);

        await tx.wait();

        showToast(`Success! 1,000 USDm minted!`);

        try {
            const provider = activeProvider || window.ethereum;
            if (provider) {
                await provider.request({
                    method: 'wallet_watchAsset',
                    params: {
                        type: 'ERC20',
                        options: {
                            address: CONTRACT_ADDRESSES.USDm,
                            symbol: 'USDm',
                            decimals: 18,
                        },
                    },
                });
            }
        } catch (e) {
            console.log("Could not auto-add token to wallet", e);
        }

        await updateWalletUI();
        await updateDashboard();
    } catch (error) {
        console.error("Minting Error:", error);
        alert("Transaction failed! See console for details.");
    }
};

// Core Logic: Calculations
const calculateYield = (principal, rate, months) => {
    return principal * rate * months;
};

// Core Logic: Update Dashboard UI
const updateDashboard = async () => {
    if (!EL.usdmBalance) return; // Not on Dashboard page
    if (!globalState.walletConnected) return;

    const user = getCurrentUserState();
    const contracts = await getContracts();
    if (!contracts) return;

    try {
        const address = globalState.walletAddress;

        // Fetch balance for the single USDv tranche, AND the base USDm in wallet
        const totalWei = await contracts.usdv.balanceOf(address);
        const usdmWei = await contracts.usdm.balanceOf(address);

        const totalBalance = parseFloat(ethers.formatEther(totalWei));
        const usdmWalletBal = parseFloat(ethers.formatEther(usdmWei));

        // Update user's struct
        user.walletBalanceUSDm = usdmWalletBal;

        // Update dashboard label if it exists
        if (EL.dashboardWalletBalance) {
            EL.dashboardWalletBalance.textContent = formatCurrency(usdmWalletBal);
        }

        // Mathematically isolate the exact Principal
        const rate = 1 + (CONFIG.yieldRates.standard * CONFIG.monthsElapsed);    // 1.03
        let principal = totalBalance / rate;

        // Failsafe
        if (principal > totalBalance) principal = totalBalance;
        if (principal < 0) principal = 0;

        const yieldAmount = totalBalance - principal;

        user.usdmDeposited = principal;

        EL.usdmBalance.textContent = formatCurrency(principal); // Principal depositado
        EL.yieldBalance.textContent = `+${formatCurrency(yieldAmount)}`;
        EL.totalBalance.textContent = formatCurrency(totalBalance);

        // Actualizar nuevo span display (Dashboard) y Input del Send Modal ("Max" support)
        const usdvDisplay = document.getElementById('usdvBalance');
        if (usdvDisplay) usdvDisplay.textContent = `${totalBalance.toFixed(2)} USDv`;

        // Update green / blue visual breakdown
        if (totalBalance > 0) {
            const usdmPercentage = (principal / totalBalance) * 100;
            const yieldPercentage = (yieldAmount / totalBalance) * 100;

            EL.usdmProgress.style.width = `${usdmPercentage}%`;
            EL.yieldProgress.style.width = `${yieldPercentage}%`;
        } else {
            EL.usdmProgress.style.width = '0%';
            EL.yieldProgress.style.width = '0%';
        }

    } catch (e) {
        console.error("Error fetching balances from blockchain:", e);
    }

    // Update risk selector UI based on state
    const activeRiskEl = document.querySelector(`[data-risk="${user.riskLevel}"]`);
    if (activeRiskEl) {
        document.querySelectorAll('.risk-option').forEach(e => e.classList.remove('active'));
        activeRiskEl.classList.add('active');
    }

    // Apply role-based UI 
    applyRoleUI(user.role);
};

// Risk Selection completely removed. Left placeholder in case other functions call it.
window.selectRisk = (risk) => {
    console.log("Risk selection is disabled for fixed 3% yield.");
};

// Modals: Open/Close handlers
window.openDepositModal = () => {
    if (!globalState.walletConnected) {
        alert("Please connect your wallet first via MetaMask!");
        return;
    }
    const user = getCurrentUserState();
    EL.depositAmount.value = '';

    // Add info about available balance
    let subtitle = document.querySelector('#depositModal .modal-subtitle');
    if (subtitle) {
        subtitle.innerHTML = `Deposit USDm to start generating USDmY.<br><small style="color:var(--primary)">Available in Wallet: ${formatCurrency(user.walletBalanceUSDm)}</small>`;
    }

    updateDepositPreview();
    EL.overlay.classList.add('active');
    EL.depositModal.classList.add('active');
    setTimeout(() => EL.depositAmount.focus(), 100);
};

window.openSendModal = () => {
    if (!globalState.walletConnected) {
        alert("Please connect your wallet first via MetaMask!");
        return;
    }
    EL.sendAmount.value = '';
    EL.recipientAddress.value = '';
    EL.overlay.classList.add('active');
    EL.sendModal.classList.add('active');
    setTimeout(() => EL.recipientAddress.focus(), 100);
};

window.closeModals = () => {
    if (EL.overlay) EL.overlay.classList.remove('active');
    if (EL.depositModal) EL.depositModal.classList.remove('active');
    if (EL.sendModal) EL.sendModal.classList.remove('active');

    // Also explicitly close the new wallet selection modal
    const walletModal = document.getElementById('walletSelectionModal');
    if (walletModal) walletModal.classList.remove('active');

    // Explicitly close the create store modal
    const storeModal = document.getElementById('createStoreModal');
    if (storeModal) storeModal.classList.remove('active');
};

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeModals();
});

// Live Preview: Deposit Modal
const updateDepositPreview = () => {
    if (!EL.depositAmount) return;
    const user = getCurrentUserState();
    const amount = parseFloat(EL.depositAmount.value) || 0;
    const projectedYield = calculateYield(amount, CONFIG.yieldRates.standard, CONFIG.monthsElapsed);
    EL.projectedLimit.textContent = formatCurrency(amount + projectedYield);
};

if (EL.depositAmount) {
    EL.depositAmount.addEventListener('input', updateDepositPreview);
}

// Interaction: Set Max on Deposit
window.setMaxDeposit = async () => {
    if (!globalState.walletConnected) return;
    try {
        const contracts = await getContracts();
        if (!contracts) return;
        const usdmBalanceWei = await contracts.usdm.balanceOf(globalState.walletAddress);
        const usdmBalance = parseFloat(ethers.formatEther(usdmBalanceWei));
        EL.depositAmount.value = usdmBalance.toString();
        // Manually trigger the live preview update
        if (typeof updateDepositPreview === 'function') {
            updateDepositPreview();
        }
    } catch (e) {
        console.error(e);
    }
};

// Interaction: Set Max on Send
window.setMaxSend = async () => {
    if (!globalState.walletConnected) return;
    try {
        const contracts = await getContracts();
        if (!contracts) return;

        // Fetch single balance for max send functionality
        const totalWei = await contracts.usdv.balanceOf(globalState.walletAddress);
        const totalBalance = parseFloat(ethers.formatEther(totalWei));

        EL.sendAmount.value = totalBalance.toString();
    } catch (e) {
        console.error(e);
    }
};

// Action: Confirm Deposit
window.confirmDeposit = async () => {
    const amount = parseFloat(EL.depositAmount.value);
    if (isNaN(amount) || amount <= 0) {
        alert("Please enter a valid amount");
        return;
    }

    try {
        const contracts = await getContracts();
        if (!contracts) return;

        const amountWei = ethers.parseEther(amount.toString());

        // Paso 1: Approve USDm al USDManager
        showToast("Step 1/2: Approving USDm...");
        const approveTx = await contracts.usdm.approve(CONTRACT_ADDRESSES.USDManager, amountWei, TX_OVERRIDES);
        await approveTx.wait();

        // Paso 2: Depositar en USDManager
        showToast("Step 2/2: Depositing USDm into Strategy...");
        const depositTx = await contracts.manager.depositUSDm(amountWei, TX_OVERRIDES);
        await depositTx.wait();

        // Paso 3: Intentar agregar USDv a MetaMask
        try {
            const provider = window.ethereum;
            if (provider) {
                await provider.request({
                    method: 'wallet_watchAsset',
                    params: {
                        type: 'ERC20',
                        options: {
                            address: CONTRACT_ADDRESSES.USDv,
                            symbol: 'USDv',
                            decimals: 18,
                        },
                    },
                });
            }
        } catch (e) {
            console.log("Could not auto-add USDv token", e);
        }

        showToast(`Successfully deposited ${amount} USDm!`);
        closeModals();
        EL.depositAmount.value = '';
        await updateDashboard();
    } catch (error) {
        console.error(error);
        alert("Transaction failed! See console for details.");
        closeModals();
    }
};

// Action: Confirm Send
window.confirmSend = async () => {
    const address = EL.recipientAddress.value.trim();
    const amount = parseFloat(EL.sendAmount.value);

    if (!address) {
        alert("Please enter a recipient address.");
        return;
    }

    if (isNaN(amount) || amount <= 0) {
        alert("Please enter a valid amount to send.");
        return;
    }

    try {
        const contracts = await getContracts();
        if (!contracts) return;

        // Convert explicitly floating point string mathematically perfectly 
        let remainingToSendWei = ethers.parseEther(amount.toString());

        const availableWei = await contracts.usdv.balanceOf(globalState.walletAddress);

        if (remainingToSendWei > availableWei) {
            alert("Insufficient total USDv balance.");
            return;
        }

        showToast(`Approving Transfer from USDv...`);
        // Let metamask popup the first tx
        const tx = await contracts.usdv.transfer(address, remainingToSendWei, TX_OVERRIDES);
        await tx.wait(); // wait for confirmation 

        showToast(`Sent total of ${amount} USDv to ${shortenAddress(address)}`);
        closeModals();
        await updateDashboard();
    } catch (error) {
        console.error(error);
        alert("Transaction failed! Make sure you have enough balance.");
        closeModals();
    }
};

// Initialization on load
document.addEventListener('DOMContentLoaded', () => {
    loadState();
    updateWalletUI();    // Will show default (disconnected)

    // Attempt role UI initialization early in case wallet is not connected
    const user = getCurrentUserState();
    if (typeof applyRoleUI === 'function') {
        applyRoleUI(user.role || 'personal');
    }

    updateDashboard();   // Will show 0 for default

    // Auto-connect if MetaMask previously connected this site
    checkConnection();
});

// --- Role Toggle Logic ---
window.toggleRole = () => {
    const user = getCurrentUserState();
    user.role = EL.roleToggle.checked ? 'merchant' : 'personal';
    saveState();
    applyRoleUI(user.role);
};

const applyRoleUI = (role) => {
    if (!EL.roleToggle) return;

    // Prevent UI desync
    EL.roleToggle.checked = (role === 'merchant');
    EL.roleLabel.textContent = role === 'merchant' ? 'Merchant Mode' : 'Personal Mode';

    if (role === 'merchant') {
        if (EL.balanceBreakdown) EL.balanceBreakdown.classList.add('hidden-role-element');
        if (EL.progressContainer) EL.progressContainer.classList.add('hidden-role-element');
        if (EL.btnDepositAction) EL.btnDepositAction.classList.add('hidden-role-element');
    } else {
        if (EL.balanceBreakdown) EL.balanceBreakdown.classList.remove('hidden-role-element');
        if (EL.progressContainer) EL.progressContainer.classList.remove('hidden-role-element');
        if (EL.btnDepositAction) EL.btnDepositAction.classList.remove('hidden-role-element');
    }

    // Toggle merchant-only sections
    const merchantSections = document.querySelectorAll('.merchant-only');
    merchantSections.forEach(sec => {
        sec.style.display = role === 'merchant' ? 'flex' : 'none'; // flex makes layout align properly, block is okay too
    });
};

// --- Vinchi:Payment Listener ---
window.addEventListener('vinchi:payment', async (e) => {
    const detail = e.detail;
    if (typeof showToast !== 'undefined') {
        showToast(`Successful payment — You saved $${detail.savedAmount} with ${detail.bank}`);
    }
    
    // Force visual update of the yield UI
    if (globalState.walletConnected && typeof updateDashboard === 'function') {
        await updateDashboard();
    }
});
