import { HardhatRuntimeEnvironment } from "hardhat/types";
import { parseEther } from "@ethersproject/units";
import { getAddress } from "@zetachain/protocol-contracts";
import { prepareData, trackCCTX } from "@zetachain/toolkit/helpers";
import fs from "fs";
import { join } from "path";

const deployContracts = async () => {
  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  // Deploy MinftNFt contract
  const MinftNftFactory = await hre.ethers.getContractFactory("MinftNFt");
  const minftNftContract = await MinftNftFactory.deploy();
  await minftNftContract.deployed();

  console.log("MinftNFt contract deployed at : ", minftNftContract.address);

  // Deploy ERA contract
  const eraFactory = await hre.ethers.getContractFactory("ERA");
  const eraContract = await eraFactory.deploy();
  await eraContract.deployed();

  console.log("ERA contract deployed at : ", eraContract.address);

  // Deploy OmnichainERA contract
  const systemContractAddress = getAddress("systemContract", "zeta_testnet");
  const omnichainERAFactory = await hre.ethers.getContractFactory(
    "OmnichainERA"
  );

  const omnichainEraContract = await omnichainERAFactory.deploy(
    "Era-Homi",
    "EHomi",
    "ERAHOMI",
    // 80001,
    systemContractAddress,
    eraContract.address
  );
  await omnichainEraContract.deployed();

  console.log(
    "OmnichainERA contract deployed at : ",
    omnichainEraContract.address
  );

  // Deploy USDCToken contract
  const usdcTokenFactory = await hre.ethers.getContractFactory("USDCToken");
  const usdcContract = await usdcTokenFactory.deploy(
    parseEther("93849384938490384038")
  );
  await usdcContract.deployed();

  // Define contract addresses
  const contractAddresses = {
    MintNFt: minftNftContract.address,
    ERA: eraContract.address,
    OmnichainERA: omnichainEraContract.address,
    USDCToken: usdcContract.address,
  };

  try {
    const filePath = join(__dirname, "./contracts.json");

    fs.writeFileSync(filePath, JSON.stringify(contractAddresses, null, 2));
    console.log("Contracts written to contracts.json");
  } catch (error) {
    console.error("Error writing contracts to contracts.json:", error);
  }
};

deployContracts();
