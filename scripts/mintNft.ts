import fs from "fs/promises"; // Import the 'promises' version of 'fs' for async file operations
import { ethers } from "hardhat"; // Import ethers for contract interaction

const main = async () => {
  try {
    // Read the contracts.json file
    const contractsFile = await fs.readFile("../contracts.json", "utf-8");
    const contracts = JSON.parse(contractsFile);

    // Obtain the contract addresses
    const omniContractAddress = contracts.Omni;
    const nftContractAddress = contracts.MintNFt;
    const eraContractAddress = contracts.ERA;

    // Connect to the contracts using ethers
    const [signer] = await ethers.getSigners();

    const omniContract = await ethers.getContractAt(
      "OmnichainERA",
      omniContractAddress,
      signer
    );
    const nftContract = await ethers.getContractAt(
      "MinftNFt",
      nftContractAddress,
      signer
    );
    const eraContract = await ethers.getContractAt(
      "ERA",
      eraContractAddress,
      signer
    );

    console.log(`🔑 Using account: ${signer.address}\n`);

    // for (let i = 0; i < 10; i++) {
    //   // mint nft and approve era_contract
    //   const tx = await nftContract.mintNFT("XYX");
    //   await tx.wait();

    //   const nftId = await nftContract.getCurrentTokenId();
    //   const approve_tx = await nftContract.approve(
    //     eraContractAddress,
    //     nftId.toString()
    //   );

    //   await approve_tx.wait();
    // }

    const;
  } catch (error) {
    console.error("Error reading or interacting with contracts:", error);
  }
};

main();
