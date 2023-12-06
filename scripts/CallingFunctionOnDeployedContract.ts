import { ethers } from 'hardhat';
import * as dotenv from 'dotenv';
import { abi as UP_ABI } from '@lukso/lsp-smart-contracts/artifacts/UniversalProfile.json';
import { MyToken__factory, ERAHomiNft__factory, UniversalReceiverDelegate__factory, ERA__factory } from '../typechain-types';
import contracts from "../contracts.json";
// load env vars
dotenv.config();



// Update those values in the .env file
const { UP_ADDR, PRIVATE_KEY } = process.env;



function toBytes32(value) {
    if (!value) {
        return '0x';
    }

    let hexString;

    if (typeof value === 'string') {
        // Convert the string to UTF-8 and truncate or pad to 32 bytes
        const utf8Bytes = Buffer.from(value, 'utf-8');
        hexString = utf8Bytes.slice(0, 32).toString('hex').padEnd(64, '0');
    } else if (typeof value === 'number') {
        // Convert the number to a 32-byte hex string
        hexString = value.toString(16).padStart(64, '0');
    } else {
        throw new Error('Unsupported type. Only string or number is allowed.');
    }

    return '0x' + hexString;
}


async function main() {

    // setup provider
    const provider = new ethers.JsonRpcProvider('https://rpc.testnet.lukso.network');
    // setup signer (the browser extension controller)
    const signer = new ethers.Wallet(PRIVATE_KEY as string, provider);

    const deployedContractAddress = contracts?.contracts?.MyToken ?? '';
    const eraHomiDeployedAddrss = contracts?.contracts?.ERAHomiNft ?? '';
    const eraDeployedAddress = contracts?.contracts?.ERA;

    let myToken = new ethers.Contract(deployedContractAddress, MyToken__factory.abi, provider);
    // let eraHomiNFT = new ethers.Contract(eraHomiDeployedAddrss, ERAHomiNft__factory.abi, provider);
    // let era = new ethers.Contract(eraDeployedAddress, ERA__factory.abi, provider);


    const recipientAddress = "0x94f0ee9f0e2a0A52A99d155740EC51432774d189"

    // mint
    const tx = await myToken.connect(signer).mint(recipientAddress, { gasLimit: 400_000 });
    await tx.wait();

    // min nft 
    // const minNftTx = await eraHomiNFT.connect(signer).mintNewEraHomi(recipientAddress, 1, true, { gasLimit: 400_000 });
    // await minNftTx.wait()


    // check operiator
    // const approveTx = await eraHomiNFT.connect(signer).authorizeOperator(era.target,
    //     "0x0000000000000000000000000000000000000000000000000000000000000005",
    //     ethers.randomBytes(0), { gasLimit: 600_000 }
    // );

    // approveTx.wait();





    // balance
    // const bal = await myToken.connect(signer).giveVal();
    // console.log("bal : ", bal);

    // decimals
    // const tx = await myToken.giveVal();
    // console.log("value : ", tx);
    // // await tx.wait()


    // const abi = ["function changeWhitelisting(address token, bool status)"]
    // let myUniversalReceiverDelegate = new ethers.Contract(deployedContractAddress, abi, provider);

    // const addressToWhitelist = "0x..."
    // const tx = await myUniversalReceiverDelegate.connect(signer).changeWhitelisting(addressToWhitelist, true);
    // await tx.wait();



}


main()
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });