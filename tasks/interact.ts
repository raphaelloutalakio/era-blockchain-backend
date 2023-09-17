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

  let message, data;
  const select = args.select;
  const omniContractAddr = "0x2B7a6d8520c899B4D3846f77D278fBC35D157f75";

  if (select === "1") {
    // yourfunction
    message = ethers.utils.hexDataSlice(
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes("yourFunction(uint256)")),
      0,
      4
    );
    data = prepareData(
      omniContractAddr,
      ["bytes4", "uint256"],
      [message, "9999"]
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
      omniContractAddr,
      ["bytes4", "address", "uint256", "address", "int256"],
      [
        message,
        "0xAeA020FCc5B6D838E7d663F66143B6F2eb72dbCC",
        "3",
        "0x2DDA7BA58e54733381a5139f2775d1e7de49A4e0",
        "22000000",
      ]
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
    data = prepareData(omniContractAddr, ["bytes4", "uint256"], [message, "1"]);
  }
  // else if (select === "4") {
  //   // list
  //   message = ethers.utils.hexDataSlice(
  //     ethers.utils.keccak256(ethers.utils.toUtf8Bytes("buy(address,uint256)")),
  //     0,
  //     4
  //   );
  //   data = prepareData(omniContractAddr, ["bytes4", "uint256"], [message, "2"]);
  // }

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
