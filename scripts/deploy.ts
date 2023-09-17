import { HardhatRuntimeEnvironment } from "hardhat/types";
import { parseEther } from "@ethersproject/units";
import { getAddress } from "@zetachain/protocol-contracts";
import { prepareData, trackCCTX } from "@zetachain/toolkit/helpers";
import fs from "fs";
import { join } from "path";

const main = async () => {
  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);
  // deploy mintNFT
  const MinftNFtfactory = await hre.ethers.getContractFactory("MinftNFt");
  const mintNFTContract = await MinftNFtfactory.deploy();
  await mintNFTContract.deployed();

  console.log("MintNFTContract deployed at : ", mintNFTContract.address);

  // deploy ERA
  const ERAfactory = await hre.ethers.getContractFactory("ERA");
  const era_contract = await ERAfactory.deploy();
  await era_contract.deployed();

  console.log("ERA deployed at : ", era_contract.address);

  // deploy OmnichainERA
  const systemContract = getAddress("systemContract", "zeta_testnet");

  const OmnichainERAfactory = await hre.ethers.getContractFactory(
    "OmnichainERA"
  );

  const omni_contract = await OmnichainERAfactory.deploy(
    "Vishal",
    "VD",
    "Just for fun",
    80001,
    systemContract,
    era_contract.address
  );
  await omni_contract.deployed();

  console.log("OmniChainERAContract deployed at : ", omni_contract.address);

  const contracts = {
    MintNFt: mintNFTContract.address,
    ERA: era_contract.address,
    Omni: omni_contract.address,
  };
  try {
    // Define the file path
    const filePath = join(__dirname, "./contracts.json");

    // Use fs.writeFileSync to write the JSON object to the file synchronously
    fs.writeFileSync(filePath, JSON.stringify(contracts, null, 2));
    console.log("Contracts written to contracts.json");
  } catch (error) {
    console.error("Error writing contracts to contracts.json:", error);
  }
};

main();
