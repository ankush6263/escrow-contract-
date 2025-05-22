const hre = require("hardhat");

async function main() {
  console.log("🚀 Starting deployment to Core Testnet 2...");
  
  // Get the ContractFactory and Signers
  const [deployer] = await hre.ethers.getSigners();
  
  console.log("📝 Deploying contracts with the account:", deployer.address);
  console.log("💰 Account balance:", (await deployer.getBalance()).toString());
  
  // Get the contract factory
  const EscrowContract = await hre.ethers.getContractFactory("Project");
  
  console.log("⏳ Deploying Escrow Contract...");
  
  // Deploy the contract
  const escrowContract = await EscrowContract.deploy();
  
  // Wait for deployment to be mined
  await escrowContract.deployed();
  
  console.log("✅ Escrow Contract deployed successfully!");
  console.log("📍 Contract address:", escrowContract.address);
  console.log("🔗 Transaction hash:", escrowContract.deployTransaction.hash);
  console.log("⛽ Gas used:", escrowContract.deployTransaction.gasLimit?.toString());
  
  // Verify the contract on Core Testnet 2 explorer (if API key is provided)
  if (process.env.CORE_SCAN_API_KEY) {
    console.log("⏳ Waiting for block confirmations...");
    await escrowContract.deployTransaction.wait(6);
    
    console.log("🔍 Verifying contract on Core Testnet 2 explorer...");
    try {
      await hre.run("verify:verify", {
        address: escrowContract.address,
        constructorArguments: [],
      });
      console.log("✅ Contract verified successfully!");
    } catch (error) {
      console.log("❌ Error verifying contract:", error.message);
    }
  }
  
  // Display useful information
  console.log("\n📋 Deployment Summary:");
  console.log("=".repeat(50));
  console.log(`Contract Name: Escrow Contract`);
  console.log(`Network: Core Testnet 2`);
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Contract Address: ${escrowContract.address}`);
  console.log(`Explorer URL: https://scan.test2.btcs.network/address/${escrowContract.address}`);
  console.log("=".repeat(50));
  
  // Save deployment info to a file
  const fs = require("fs");
  const deploymentInfo = {
    network: "core_testnet2",
    contractAddress: escrowContract.address,
    deployerAddress: deployer.address,
    transactionHash: escrowContract.deployTransaction.hash,
    blockNumber: escrowContract.deployTransaction.blockNumber,
    timestamp: new Date().toISOString(),
    explorerUrl: `https://scan.test2.btcs.network/address/${escrowContract.address}`
  };
  
  fs.writeFileSync(
    "deployment-info.json",
    JSON.stringify(deploymentInfo, null, 2)
  );
  
  console.log("💾 Deployment info saved to deployment-info.json");
}

// Error handling
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
