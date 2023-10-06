// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@zetachain/protocol-contracts/contracts/zevm/SystemContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@zetachain/toolkit/contracts/BytesHelperLib.sol";

import "./ERA.sol";

contract OmnichainERA is zContract, ERC721URIStorage {
    error SenderNotSystemContract();
    error WrongChain(uint256 chainId);

    SystemContract public immutable systemContract;
    uint256 public immutable chainId;
    uint256 constant BITCOIN = 18332;
    ERA public eraContract;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    string private baseTokenURI;
    mapping(uint256 => string) private tokenURIs;

    // modifier
    modifier onlySystem() {
        require(
            msg.sender == address(systemContract),
            "Only system contract can call this function"
        );
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        string memory _baseTokenURI,
        uint256 chainID,
        address systemContractAddress,
        address _eraContractAddress
    ) ERC721(name, symbol) {
        systemContract = SystemContract(systemContractAddress);
        chainId = chainID;
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

    function getSelector(bytes memory input) public pure returns (bytes4) {
        require(input.length >= 4, "Input byte array too short");
        bytes4 val;
        assembly {
            val := mload(add(input, 32))
        }
        return val;
    }

    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override onlySystem {
        require(message.length > 0, "Empty message");

        address _caller = BytesHelperLib.bytesToAddress(context.origin, 0);
        bytes4 selector;

        if (chainId == BITCOIN) {
            selector = getSelector(message);

            if (selector == bytes4(keccak256("yourFunction(uint64)"))) {
                uint64 value = BytesHelperLib.bytesToUint64(message, 4);
                eraContract.yourFunction(value);
            } else if (
                selector ==
                bytes4(keccak256("list(address,address,uint64,address,uint64)"))
            ) {
                address _nftAddress = BytesHelperLib.bytesToAddress(message, 4);
                uint64 _tokenId = BytesHelperLib.bytesToUint64(message, 24);
                address _paymentTokenAddress = BytesHelperLib.bytesToAddress(
                    message,
                    32
                );
                uint64 _ask = BytesHelperLib.bytesToUint64(message, 52);
                eraContract.list(
                    _caller,
                    _nftAddress,
                    _tokenId,
                    _paymentTokenAddress,
                    _ask
                );
            } else if (
                selector == bytes4(keccak256("delist(address,uint64)"))
            ) {
                uint64 listId = BytesHelperLib.bytesToUint64(message, 4);
                eraContract.delist(_caller, listId);
            } else if (
                selector ==
                bytes4(keccak256("changePrice(address,uint64,address,uint64)"))
            ) {
                uint64 _listId = BytesHelperLib.bytesToUint64(message, 4);
                address _paymentTokenAddress = BytesHelperLib.bytesToAddress(
                    message,
                    12
                );
                uint64 _ask = BytesHelperLib.bytesToUint64(message, 32);
                eraContract.changePrice(
                    _caller,
                    _listId,
                    _paymentTokenAddress,
                    _ask
                );
            } else if (selector == bytes4(keccak256("buy(address,uint64)"))) {
                uint64 _listId = BytesHelperLib.bytesToUint64(message, 4);
                eraContract.buy(_caller, _listId);
            } else if (
                selector ==
                bytes4(keccak256("makeOffer(uint64,address,address,uint64)"))
            ) {
                uint64 _listId = BytesHelperLib.bytesToUint64(message, 4);
                address _paymentTokenAddress = BytesHelperLib.bytesToAddress(
                    message,
                    12
                );
                uint64 _offerPrice = BytesHelperLib.bytesToUint64(message, 32);
                eraContract.makeOffer(
                    _caller,
                    _listId,
                    _paymentTokenAddress,
                    _offerPrice
                );
            } else if (
                selector == bytes4(keccak256("acceptOffer(uint64,uint64)"))
            ) {
                uint64 _listId = BytesHelperLib.bytesToUint64(message, 4);
                uint64 _offerId = BytesHelperLib.bytesToUint64(message, 12);

                eraContract.acceptOffer(_listId, _offerId);
            } else if (
                selector ==
                bytes4(keccak256("removeOffer(address,uint64,uint64)"))
            ) {
                uint64 _listId = BytesHelperLib.bytesToUint64(message, 4);
                uint64 _offerId = BytesHelperLib.bytesToUint64(message, 12);

                eraContract.removeOffer(_caller, _listId, _offerId);
            } else {
                revert("Unknown function selector");
            }
        } else {
            (selector) = abi.decode(message, (bytes4));

            if (selector == bytes4(keccak256("yourFunction(uint64)"))) {
                (, uint64 value) = abi.decode(message, (bytes4, uint64));
                eraContract.yourFunction(value);
            } else if (
                selector ==
                bytes4(keccak256("list(address,address,uint64,address,uint64)"))
            ) {
                (
                    ,
                    address nftAddress,
                    uint64 tokenId,
                    address paymentToken,
                    uint64 ask
                ) = abi.decode(
                        message,
                        (bytes4, address, uint64, address, uint64)
                    );

                eraContract.list(
                    _caller,
                    nftAddress,
                    tokenId,
                    paymentToken,
                    ask
                );
            } else if (
                selector == bytes4(keccak256("delist(address,uint64)"))
            ) {
                (, uint64 listId) = abi.decode(message, (bytes4, uint64));
                eraContract.delist(_caller, listId);
            } else if (
                selector ==
                bytes4(keccak256("changePrice(address,uint64,address,uint64)"))
            ) {
                (, uint64 listId, address payementToken, uint64 ask) = abi
                    .decode(message, (bytes4, uint64, address, uint64));

                eraContract.changePrice(_caller, listId, payementToken, ask);
            } else if (selector == bytes4(keccak256("buy(address,uint64)"))) {
                (, uint64 listId) = abi.decode(message, (bytes4, uint64));
                eraContract.buy(_caller, listId);
            } else if (
                selector ==
                bytes4(keccak256("makeOffer(uint64,address,address,uint64)"))
            ) {
                (, uint64 listId, address paymentToken, uint64 offerPrice) = abi
                    .decode(message, (bytes4, uint64, address, uint64));

                eraContract.makeOffer(
                    _caller,
                    listId,
                    paymentToken,
                    offerPrice
                );
            } else if (
                selector == bytes4(keccak256("acceptOffer(uint64,uint64)"))
            ) {
                (, uint64 listId, uint64 offerId) = abi.decode(
                    message,
                    (bytes4, uint64, uint64)
                );

                eraContract.acceptOffer(listId, offerId);
            } else if (
                selector ==
                bytes4(keccak256("removeOffer(address,uint64,uint64)"))
            ) {
                (, uint64 listId, uint64 offerId) = abi.decode(
                    message,
                    (bytes4, uint64, uint64)
                );

                eraContract.removeOffer(_caller, listId, offerId);
            } else {
                revert("Unknown function selector");
            }
        }
    }
}
