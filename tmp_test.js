const { ethers } = require("ethers");

async function main() {
    const category = "entretenimiento";
    const amount = 1000;
    const day = 1; // Tuesday
    
    // Simulate what server.js does
    const categoryId = ethers.keccak256(ethers.toUtf8Bytes(category));
    const storeId    = ethers.keccak256(ethers.toUtf8Bytes("vinchi-comercio-1"));
    const amountBN = ethers.parseEther(amount.toString());
    
    console.log("Category Hash:", categoryId);
    console.log("Store Hash:", storeId);
}

main().catch(console.error);
