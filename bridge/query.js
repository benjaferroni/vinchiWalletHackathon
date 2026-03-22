const { ethers } = require("ethers");

async function main() {
    const provider = new ethers.JsonRpcProvider("https://api.avax-test.network/ext/bc/C/rpc");
    
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

    const routerAddr = "0xcf2Ef3b09C1a1d757d1110d526a8A6Ca191D9254";
    const routerContract = new ethers.Contract(routerAddr, AGENT_ROUTER_ABI, provider);

    const category = "entretenimiento";
    const categoryId = ethers.keccak256(ethers.toUtf8Bytes(category));
    const storeId    = ethers.keccak256(ethers.toUtf8Bytes("vinchi-comercio-1"));
    const amountBN = ethers.parseEther("1000");
    const day = 1; // Tuesday

    console.log("Calling findBestPromotion for 'entretenimiento' on Tuesday...");
    const raw = await routerContract.findBestPromotion({
      storeId,
      categoryId,
      amount: amountBN,
      dayOfWeek: day
    });

    console.log("Result Description:", raw.description);
    console.log("Result SaveAmount:", ethers.formatEther(raw.savedAmount));
    console.log("Result BankName:", raw.bankName);
}

main().catch(console.error);
