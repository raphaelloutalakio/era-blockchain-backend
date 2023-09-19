import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { parseEther } from "@ethersproject/units";
import { getAddress } from "@zetachain/protocol-contracts";
import { prepareData, trackCCTX } from "@zetachain/toolkit/helpers";
import contracts from "../scripts/contracts.json";

const ethers = require("ethers");

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  let message, data;
  const select = args.select;

  const omniContractAddress = contracts.Omni;
  const nftContractAddress = contracts.MintNFt;
  const eraContractAddress = contracts.ERA;

  console.log(contracts);
  const paymentToken = "0x8a239DBDBc385218439623028cEf69506577b1d2";
  const amountToListBuy = "22000000000000000000";
  const nftToBuy = "1";
  const toDList = "0";
  const nftToList = "2";

  if (select === "1") {
    // yourfunction
    message = ethers.utils.hexDataSlice(
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes("yourFunction(uint256)")),
      0,
      4
    );
    data = prepareData(
      omniContractAddress,
      ["bytes4", "uint256"],
      [message, "99"]
    );
  } else if (select === "2") {
    // list
    message = ethers.utils.hexDataSlice(
      ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("list(address,address,uint256,address,int256)")
      ),
      0,
      4
    );
    data = prepareData(
      omniContractAddress,
      ["bytes4", "address", "uint256", "address", "int256"],
      [message, nftContractAddress, nftToList, paymentToken, amountToListBuy]
    );
  } else if (select === "3") {
    // list
    message = ethers.utils.hexDataSlice(
      ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("delist(address,uint256)")
      ),
      0,
      4
    );
    data = prepareData(
      omniContractAddress,
      ["bytes4", "uint256"],
      [message, toDList]
    );
  } else if (select === "4") {
    // list
    message = ethers.utils.hexDataSlice(
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes("buy(address,uint256)")),
      0,
      4
    );
    data = prepareData(
      omniContractAddress,
      ["bytes4", "uint256"],
      [message, nftToBuy]
    );
  }

  console.log("data to pass : ", data);

  const to = getAddress("tss", hre.network.name);
  const value = parseEther("0.001");

  const tx = await signer.sendTransaction({ data, to, value });

  console.log(`
🚀 Successfully broadcasted a token transfer transaction on ${hre.network.name} network.
📝 Transaction hash: ${tx.hash}
`);
  await trackCCTX(tx.hash);
};

task("interact", "Interact with the contract")
  // .addParam("contract", "The address of the withdraw contract on ZetaChain")
  // .addParam("amount", "Amount of tokens to send")
  .addParam("select", "select something")
  .setAction(main);
