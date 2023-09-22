import fs from "fs/promises";
import { ethers } from "hardhat";
import contracts from "./contracts.json";

const main = async () => {
  try {
    const omniContractAddress = contracts.Omni;
    const nftContractAddress = contracts.MintNFt;
    const eraContractAddress = contracts.ERA;

    console.log(omniContractAddress, nftContractAddress, eraContractAddress);

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

    for (let i = 0; i < 10; i++) {
      try {
        // mint nft and approve era_contract
        const tx = await nftContract.mintNFT("XYX");
        await tx.wait();

        console.log(`Minted NFT #${i + 1}`);

        // You can add more specific error handling here if needed
      } catch (mintError) {
        console.error(`Error minting NFT #${i + 1}:`, mintError);
      }
    }

    // The rest of your code...
  } catch (error) {
    console.error("Error reading or interacting with contracts:", error);
  }
};

main();
