import { ethers } from 'hardhat';
import * as dotenv from 'dotenv';
import { abi as UP_ABI } from '@lukso/lsp-smart-contracts/artifacts/UniversalProfile.json';
import { MyToken__factory, ERA__factory, ERAHomiNft__factory, UniversalReceiverDelegate__factory } from '../typechain-types';
import fs from "fs";
import { join } from "path";
import contractData from "../contracts.json";


// load env vars
dotenv.config();

// Update those values in the .env file
const { UP_ADDR, PRIVATE_KEY } = process.env;

// MyTOken : 0xB5150F1d51318Ad0C5B8F4dF4dB8DA3Db0886c2c


async function main() {

    // setup provider
    const provider = new ethers.JsonRpcProvider('https://rpc.testnet.lukso.network');
    // setup signer (the browser extension controller)
    const signer = new ethers.Wallet(PRIVATE_KEY as string, provider);

    let era, myToken, eraHomiNFT, delegate;

    // USDC Token
    myToken = await new MyToken__factory(signer).deploy({ gasLimit: 20_000_000 });
    console.log("Mytoken : ", myToken.target);

    // era = await new ERA__factory(signer).deploy({ gasLimit: 20_000_000 });
    // console.log("Main ERA : ", era.target);

    // // ERA Homi NFT
    //  eraHomiNFT = await new ERAHomiNft__factory(signer).deploy(signer.address, { gasLimit: 20_000_000 });
    // console.log("ERA HOMI NFT : ", eraHomiNFT.target);

    // // // universal receciver delegate
    //  delegate = await new UniversalReceiverDelegate__factory(signer).deploy({ gasLimit: 20_000_000 })
    // console.log("delegate contract : ", delegate.target)

    //     const urd = await new UniversalReceiverDelegate__factory(signer).deploy({ gasLimit: 20_000_000 });
    //     console.log((urd.target));
    // }

    const contractAddresses = {
        ERA: era?.target || contractData?.contracts?.ERA,
        ERAHomiNft: eraHomiNFT?.target || contractData?.contracts.ERAHomiNft,
        MyToken: myToken?.target || contractData?.contracts?.MyToken,
        UniversalReceiverDelegate: delegate?.target || contractData?.contracts?.UniversalReceiverDelegate,
    };

    try {
        const filePath = join(__dirname, "../contracts.json");

        const currentDate = new Date();
        const formattedDate = currentDate.toLocaleDateString('en-GB', {
            day: 'numeric',
            month: 'short',
            year: 'numeric'
        });
        const formattedTime = currentDate.toLocaleTimeString('en-US', {
            hour12: false,
            hour: 'numeric',
            minute: 'numeric'
        });

        const formattedDateTime = `${formattedDate}, ${formattedTime}`;

        const dataToWrite = {
            date: formattedDateTime,
            contracts: contractAddresses
        };


        fs.writeFileSync(filePath, JSON.stringify(dataToWrite, null, 2));
        console.log("Contracts and timestamp written to contracts.json");
    } catch (error) {
        console.error("Error writing contracts and timestamp to contracts.json:", error);
    }

}

main()
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });