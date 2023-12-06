// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ERAHomiNft is LSP8IdentifiableDigitalAsset, ReentrancyGuard {
    constructor(
        address owner_
    ) LSP8IdentifiableDigitalAsset("ERAHomi", "ERAH", owner_, 0) {}

    function mintNewEraHomi(
        address to,
        uint256 amount,
        bool allowNonLSP1Recipient
    ) external nonReentrant {
        uint256 tokenSupply = totalSupply();
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = ++tokenSupply;

            _mint(to, bytes32(tokenId), allowNonLSP1Recipient, "");
        }
    }
}
