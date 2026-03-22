const { ethers } = require("ethers");

async function main() {
    const abi = [
      {
        inputs: [{
          components: [
            { name: "storeId",    type: "bytes32" },
            { name: "categoryId", type: "bytes32" },
            { name: "amount",     type: "uint256" },
            { name: "dayOfWeek",  type: "uint8"   },
          ],
          name: "ctx", type: "tuple"
        }],
        name: "findBestPromotion",
        outputs: [],
        stateMutability: "view",
        type: "function"
      }
    ];

    const iface = new ethers.Interface(abi);

    const categoryId = ethers.keccak256(ethers.toUtf8Bytes("entretenimiento"));
    const storeId    = ethers.keccak256(ethers.toUtf8Bytes("vinchi-comercio-1"));
    const amountBN   = ethers.parseEther("1000");
    const day        = 1;

    try {
        const encoded = iface.encodeFunctionData("findBestPromotion", [{
            storeId,
            categoryId,
            amount: amountBN,
            dayOfWeek: day
        }]);
        console.log("Encoded with Object:", encoded);
    } catch (e) {
        console.error("Error Object:", e.message);
    }
}

main().catch(console.error);
