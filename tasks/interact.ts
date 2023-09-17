import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { parseEther } from "@ethersproject/units";
import { getAddress } from "@zetachain/protocol-contracts";
import { prepareData, trackCCTX } from "@zetachain/toolkit/helpers";

const ethers = require("ethers");

// polygon mumbai : 0xCbeBB06cfF9070e61467440aD575c68A2e0b27B0
// bitcoin  : 0xc248C4DD38678BE5184D86Fc548582BDEeEBFA96

// to check
// npx hardhat cctx --tx ef85eb6f704da0f2a4798870fb1105f7b6826f0d404a8bdaeb52d46eb81ba6e2
// npx hardhat cctx --tx 2a421322f03b08e55ba78b4de213ebc8b552eef8411381e81d11074a6e413404

const main = async (args: any, hre: HardhatRuntimeEnvironment) => {
  const [signer] = await hre.ethers.getSigners();
  console.log(`🔑 Using account: ${signer.address}\n`);

  const message = ethers.utils.hexDataSlice(
    ethers.utils.keccak256(ethers.utils.toUtf8Bytes("yourFunction(uint256)")),
    0,
    4
  );

  const data = prepareData(
    args.contract,
    ["bytes4", "uint256"],
    [message, "8989"]
  );

  console.log("data to pass : ", data);

  const to = getAddress("tss", hre.network.name);
  const value = parseEther(args.amount);

  const tx = await signer.sendTransaction({ data, to, value });

  console.log(`
🚀 Successfully broadcasted a token transfer transaction on ${hre.network.name} network.
📝 Transaction hash: ${tx.hash}
`);
  await trackCCTX(tx.hash);
};

task("interact", "Interact with the contract")
  .addParam("contract", "The address of the withdraw contract on ZetaChain")
  .addParam("amount", "Amount of tokens to send")
  .setAction(main);
