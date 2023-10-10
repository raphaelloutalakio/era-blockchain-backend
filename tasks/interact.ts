import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { parseEther } from "@ethersproject/units";
import { getAddress } from "@zetachain/protocol-contracts";
import { prepareData, trackCCTX } from "@zetachain/toolkit/helpers";
import contracts from "../scripts/contracts.json";

const ethers = require("ethers");
const parseEth = (val: any) => ethers.utils.parseEther(val);

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  let selector, data;
  const select = args.select;

  const omniContractAddress = contracts.OmnichainERA;
  const nftContractAddress = contracts.MintNFt;
  const eraContractAddress = contracts.ERA;
  const paymentToken = contracts.USDCToken;

  console.log(contracts);
  const amountToListBuy = parseEth("2");
  const buy = "0";
  const dlist = "0";
  const nftidlist = "2";
  const offerListId = "0";
  const idlist = "0";

  if (select === "1") {
    // yourfunction
    selector = ethers.utils.hexDataSlice(
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes("yourFunction(uint64)")),
      0,
      4
    );
    data = prepareData(
      omniContractAddress,
      ["bytes4", "uint64"],
      [selector, "990"]
    );
    console.log(selector);
  } else if (select === "2") {
    // list
    selector = ethers.utils.hexDataSlice(
      ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("list(address,address,uint64,address,uint64)")
      ),
      0,
      4
    );
    data = prepareData(
      omniContractAddress,
      ["bytes4", "address", "uint64", "address", "uint64"],
      [selector, nftContractAddress, nftidlist, paymentToken, amountToListBuy]
    );
    console.log(
      omniContractAddress,
      selector,
      nftContractAddress,
      nftidlist,
      paymentToken,
      amountToListBuy
    );
  } else if (select === "3") {
    // buy
    selector = ethers.utils.hexDataSlice(
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes("buy(address,uint64)")),
      0,
      4
    );
    data = prepareData(
      omniContractAddress,
      ["bytes4", "uint64"],
      [selector, buy]
    );
  } else if (select === "4") {
    // makeOffer
    selector = ethers.utils.hexDataSlice(
      ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("makeOffer(address,uint64,address,uint64)")
      ),
      0,
      4
    );
    data = prepareData(
      omniContractAddress,
      ["bytes4", "uint64", "address", "uint64"],
      [selector, , offerListId, paymentToken, amountToListBuy]
    );
  } else if (select === "5") {
    // makeOffer
    selector = ethers.utils.hexDataSlice(
      ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("acceptOffer(address,uint64,uint64)")
      ),
      0,
      4
    );
    data = prepareData(
      omniContractAddress,
      ["bytes4", "uint64", "uint64"],
      [selector, , idlist, offerListId]
    );
  }
  // 5fe578480cd2C11B313c70AeD4360FdF6C9d0Df92b05bc6e548D690Af43f3ab3D041cac56A396D19A0b3F6Bf00000000000000012dC9E747A4A1B1F74eaF26b5AF0A8381600572d91BC16D674EC80000

  console.log("data to pass : ", data);

  //   const to = getAddress("tss", hre.network.name);
  //   const value = parseEther("0.0001");

  //   const tx = await signer.sendTransaction({ data, to, value });

  //   console.log(`
  // 🚀 Successfully broadcasted a token transfer transaction on ${hre.network.name} network.
  // 📝 Transaction hash: ${tx.hash}
  // `);
  //   await trackCCTX(tx.hash);
};

task("interact", "Interact with the contract")
  // .addParam("contract", "The address of the withdraw contract on ZetaChain")
  // .addParam("amount", "Amount of tokens to send")
  .addParam("select", "select something")
  .setAction(main);
