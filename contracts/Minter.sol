// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERA.sol";

contract Minter is zContract, ERC721URIStorage {
    error SenderNotSystemContract();
    error WrongChain();

    SystemContract public immutable systemContract;
    uint256 public immutable chain;
    ERA public eraContract;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    string private baseTokenURI;
    mapping(uint256 => string) private tokenURIs;

    constructor(
        string memory name,
        string memory symbol,
        string memory _baseTokenURI,
        uint256 chainID,
        address systemContractAddress,
        address _eraContractAddress
    ) ERC721(name, symbol) {
        systemContract = SystemContract(systemContractAddress);
        chain = chainID;
        baseTokenURI = _baseTokenURI;
        eraContract = ERA(_eraContractAddress);
    }

    function setBaseURI(string memory _baseTokenURI) external {
        baseTokenURI = _baseTokenURI;
    }

    function mintNFT(address _to, string memory _metadataURI) internal {
        uint256 tokenId = _tokenIdCounter.current();
        _mint(_to, tokenId);
        _tokenIdCounter.increment();
        _setTokenURI(tokenId, _metadataURI);
    }

    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override {
        if (msg.sender != address(systemContract)) {
            revert SenderNotSystemContract();
        }
        (address to, string memory metadataURI) = abi.decode(
            message,
            (address, string)
        );

        address acceptedZRC20 = systemContract.gasCoinZRC20ByChainId(chain);
        if (zrc20 != acceptedZRC20) revert WrongChain();

        mintNFT(to, metadataURI);
    }
}
