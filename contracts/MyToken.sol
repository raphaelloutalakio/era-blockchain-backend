// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LSP7DigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP7DigitalAsset/LSP7DigitalAsset.sol";

contract MyToken is LSP7DigitalAsset {
    constructor() LSP7DigitalAsset("USDC", "USD", msg.sender, false) {
        _mint(msg.sender, 10000000 ether, true, "");
    }

    function mint(address recipient) public {
        _mint(recipient, 10, true, "");
    }
}
