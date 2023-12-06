// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// 0x20804611b3e2ea21c480dc465142210acf4a2485947541770ec1fb87dee4a55c

import {ILSP1UniversalReceiverDelegate} from "@lukso/lsp-smart-contracts/contracts/LSP1UniversalReceiver/ILSP1UniversalReceiverDelegate.sol";
import "hardhat/console.sol";
import {_TYPEID_LSP7_TOKENSSENDER, _TYPEID_LSP7_TOKENSRECIPIENT, _INTERFACEID_LSP7} from "@lukso/lsp-smart-contracts/contracts/LSP7DigitalAsset/LSP7Constants.sol";
import {_TYPEID_LSP8_TOKENSSENDER, _TYPEID_LSP8_TOKENSRECIPIENT, _INTERFACEID_LSP8} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8Constants.sol";

contract UniversalReceiverDelegate is ILSP1UniversalReceiverDelegate {
    mapping(address => bool) public isWhitelisted;

    uint public lp7count = 10;
    uint public lp8count = 101;
    event UniversalEmiiitedBhaiya(
        address sender,
        address from,
        address to,
        bytes32 tokenId
    );

    function changeWhitelisting(address token, bool status) public {
        isWhitelisted[token] = status;
    }

    function universalReceiverDelegate(
        address sender,
        uint256 /*value*/,
        bytes32 typeId,
        bytes memory data
    ) public returns (bytes memory) {
        if (typeId == _TYPEID_LSP7_TOKENSRECIPIENT) {
            lp7count += 1;
            // emit UniversalEmiiitedBhaiya(lp7count);
        } else if (typeId == _TYPEID_LSP8_TOKENSRECIPIENT) {
            (address from, address to, bytes32 tokenId, ) = abi.decode(
                data,
                (address, address, bytes32, bytes)
            );

            

            lp8count += 2;
            emit UniversalEmiiitedBhaiya(sender, from, to, tokenId);
        }

        return "";
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(ILSP1UniversalReceiverDelegate).interfaceId;
    }
}
