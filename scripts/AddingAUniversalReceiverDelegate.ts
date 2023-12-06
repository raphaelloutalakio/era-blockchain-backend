import { ethers } from 'hardhat';
import * as dotenv from 'dotenv';
import { abi as UP_ABI } from '@lukso/lsp-smart-contracts/artifacts/UniversalProfile.json';
import { ERC725YDataKeys, LSP1_TYPE_IDS } from '@lukso/lsp-smart-contracts';
import contracts from "../contracts.json";

// load env vars
dotenv.config();

// Update those values in the .env file
const { UP_ADDR, PRIVATE_KEY } = process.env;

// LSP8Tokens_RecipientNotification, LSP8Tokens_SenderNotification

async function main() {

    // setup provider
    const provider = new ethers.JsonRpcProvider('https://rpc.testnet.lukso.gateway.fm');
    // setup signer (the browser extension controller)
    const signer = new ethers.Wallet(PRIVATE_KEY as string, provider);

    let UP = new ethers.Contract(UP_ADDR as string, UP_ABI, provider);

    console.log('🔑 EOA: ', signer.address);
    console.log('🆙 Universal Profile: ', await UP.getAddress());




    // console.log("tyeps : ", LSP1_TYPE_IDS)
    // The address of the deployed URD
    const UniversalReceiverDelegateAddress = contracts?.contracts?.UniversalReceiverDelegate ?? '';



    // LSP7 notification receiver 
    // const typeIdLSP7Recipient = LSP1_TYPE_IDS.LSP7Tokens_RecipientNotification;
    // const constructedDataKeyLPS7 = ERC725YDataKeys.LSP1.LSP1UniversalReceiverDelegatePrefix + typeIdLSP7Recipient.substring(2, 42);
    // const tx7 = await UP.connect(signer).setData(constructedDataKeyLPS7, UniversalReceiverDelegateAddress);
    // await tx7.wait();


    // LSP8 notification receiver 
    const typeIdLSP8Recipient = LSP1_TYPE_IDS.LSP8Tokens_RecipientNotification;
    const constructedDataKeyLSP8 = ERC725YDataKeys.LSP1.LSP1UniversalReceiverDelegatePrefix + typeIdLSP8Recipient.substring(2, 42);

    const tx8 = await UP.connect(signer).setData(constructedDataKeyLSP8, UniversalReceiverDelegateAddress);
    await tx8.wait();
}

main()
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });