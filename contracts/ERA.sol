// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {ILSP7DigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP7DigitalAsset/ILSP7DigitalAsset.sol";
import {ILSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/ILSP8IdentifiableDigitalAsset.sol";
import {ILSP1UniversalReceiverDelegate} from "@lukso/lsp-smart-contracts/contracts/LSP1UniversalReceiver/ILSP1UniversalReceiverDelegate.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./ERATypes.sol";
import "hardhat/console.sol";

contract ERA is ReentrancyGuard {
    /// Events
    event Listed(
        uint64 indexed list_id,
        address lister,
        address indexed nftAddress,
        bytes32 indexed tokenId,
        address paymentToken,
        uint128 ask,
        address owner
    );

    event ItemDelisted(
        uint64 list_id,
        address indexed nftAddress,
        bytes32 indexed tokenId,
        address indexed paymentToken,
        uint128 ask,
        address owner,
        address lister
    );

    event Offered(
        uint64 indexed listId,
        uint64 indexed offerId,
        address offerer,
        address paymentToken,
        uint64 offerPrice
    );

    event OfferRemoved(uint64 indexed listId, uint64 indexed offerId);

    event ItemPurchased(
        address indexed buyer,
        address indexed lister,
        uint64 indexed listId,
        address nftAddress,
        bytes32 tokenId,
        address paymentToken,
        uint totalPrice
    );

    event ChangePrice(uint64 indexed item_id, address paymentToken, uint64 ask);

    event AuctionCreated(
        uint auctionId,
        address nftAddress,
        bytes32 tokenId,
        address paymentToken,
        uint minBid,
        uint minBidIncrement,
        uint startTime,
        uint expirationTime,
        address owner,
        address seller
    );

    event BidPlaced(
        uint indexed auctionId,
        address indexed bidder,
        uint bidAmount
    );

    event AuctionEnded(
        uint auctionId,
        address nftAddress,
        bytes32 tokenId,
        address paymentToken,
        address winner,
        uint winningBid
    );

    event CollectionApplication(
        uint application_id,
        address applicant,
        string collectionName,
        address NFTContract,
        address royaltyCollector,
        uint bps,
        bool approved
    );

    event CollectionApplicationApproved(
        uint indexed applicationId,
        address indexed applicant
    );

    event BundleCreated(
        uint bundle_id,
        address[] nftAddresses,
        bytes32[] tokenIds,
        address[] paymentTokens,
        uint[] prices,
        address seller
    );

    event BundlePurchased(uint bundle_id, address buyer, address seller);

    Marketplace public marketplace;
    address public omnichainEraAddr;
    address public owner;

    // Mappings
    mapping(address => RoyaltyCollection) public royaltyCollections;
    mapping(uint64 => List) public lists;
    mapping(uint => Offer[]) public listIdToOffers;
    mapping(uint => AuctionItem) public auctions;
    mapping(uint => NFTCollectionApplication) public collectionApplications;
    mapping(uint => Bundle) public bundles;

    // modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    constructor() {
        marketplace.fee_pbs = 150;
        marketplace.collateral_fee = 10000;
        marketplace.owner = msg.sender;
        owner = msg.sender;
    }

    function mutateOwner(address new_owner) public onlyOwner {
        marketplace.owner = new_owner;
    }

    function mutateFeesPbs(uint new_fee_pbs) public onlyOwner {
        if (new_fee_pbs < marketplace.collateral_fee)
            marketplace.fee_pbs = new_fee_pbs;
    }

    function mutateCollateralFees(uint new_collateral_fee) public onlyOwner {
        marketplace.collateral_fee = new_collateral_fee;
    }

    function calculateFees(
        uint amount,
        uint fee_pbs,
        uint collateral_fee
    ) public pure returns (uint) {
        return (amount * fee_pbs) / collateral_fee;
    }

    function add_royalty_collection(
        address _nftAddress,
        uint bps,
        address royaltyCollector
    ) public {
        RoyaltyCollection memory newRoyaltyCollector;
        newRoyaltyCollector.creator = msg.sender;
        newRoyaltyCollector.bps = bps;
        newRoyaltyCollector.royaltyCollector = royaltyCollector;
        royaltyCollections[_nftAddress] = newRoyaltyCollector;
    }

    function check_exists_royalty_collection(
        address _nftAddress
    ) public view returns (bool) {
        return royaltyCollections[_nftAddress].creator != address(0);
    }

    function update_royalty_collection(
        address _nftAddress,
        uint bps,
        address royaltyCollector
    ) public {
        require(
            royaltyCollections[_nftAddress].creator == msg.sender,
            "EInvliadOwner"
        );
        royaltyCollections[_nftAddress].creator = msg.sender;
        royaltyCollections[_nftAddress].bps = bps;
        royaltyCollections[_nftAddress].royaltyCollector = royaltyCollector;
    }

    function calculateRoyaltyCollectionFee(
        address _nftAddress,
        uint amount
    ) public view returns (uint) {
        return
            (amount * royaltyCollections[_nftAddress].bps) /
            marketplace.collateral_fee;
    }

    function list(
        address _nftAddress,
        bytes32 _tokenId,
        address _paymentToken,
        uint128 _ask
    ) external nonReentrant {
        require(_ask > 0, "Asked price should be greater than 0");

        ILSP8IdentifiableDigitalAsset asset = ILSP8IdentifiableDigitalAsset(
            _nftAddress
        );

        asset.transfer(msg.sender, address(this), _tokenId, true, "");

        require(
            asset.isOperatorFor(address(this), _tokenId),
            "NFT not transferred"
        );

        List memory newList = List({
            list_id: marketplace.listed,
            lister: msg.sender,
            nftAddress: _nftAddress,
            tokenId: _tokenId,
            paymentToken: _paymentToken,
            ask: _ask,
            owner: address(this),
            offers: 0,
            active: true
        });

        lists[marketplace.listed] = newList;

        marketplace.listed += 1;

        emit Listed(
            marketplace.listed - 1,
            msg.sender,
            _nftAddress,
            _tokenId,
            _paymentToken,
            _ask,
            address(this)
        );
    }

    function delist(address _lister, uint64 _listId) external {
        List storage listedItem = lists[_listId];

        if (msg.sender == omnichainEraAddr) {
            require(listedItem.lister == _lister, "Not lister");
        } else {
            require(msg.sender == listedItem.lister, "Not lister");
        }

        require(listedItem.active, "NFT is not listed");

        ILSP8IdentifiableDigitalAsset asset = ILSP8IdentifiableDigitalAsset(
            listedItem.nftAddress
        );

        asset.transfer(address(this), _lister, listedItem.tokenId, true, "");

        listedItem.active = false;

        emit ItemDelisted(
            _listId,
            listedItem.nftAddress,
            listedItem.tokenId,
            listedItem.paymentToken,
            listedItem.ask,
            listedItem.owner,
            listedItem.lister
        );
    }

    function changePrice(
        uint64 _listId,
        address _paymentToken,
        uint64 _ask
    ) external {
        List storage listedItem = lists[_listId];
        require(msg.sender == listedItem.lister, "Not lister");

        require(listedItem.active, "NFT is not listed");

        listedItem.paymentToken = _paymentToken;
        listedItem.ask = _ask;

        emit ChangePrice(_listId, _paymentToken, _ask);
    }

    function buy(uint64 _listId) external nonReentrant {
        require(_listId < marketplace.listed, "Invalid list ID");

        uint fee_amount;
        uint royalty_fee_amount;

        List storage listedItem = lists[_listId];
        require(listedItem.active, "NFT is not listed");

        uint256 totalAmount = uint256(listedItem.ask);

        if (marketplace.fee_pbs > 0) {
            fee_amount = calculateFees(
                listedItem.ask,
                marketplace.fee_pbs,
                marketplace.collateral_fee
            );
            totalAmount += fee_amount;
        }

        if (check_exists_royalty_collection(listedItem.nftAddress)) {
            royalty_fee_amount = calculateRoyaltyCollectionFee(
                listedItem.nftAddress,
                listedItem.ask
            );
            totalAmount += royalty_fee_amount;
        }

        ILSP7DigitalAsset _token = ILSP7DigitalAsset(listedItem.paymentToken);

        require(
            _token.balanceOf(msg.sender) >= totalAmount,
            "Insufficient funds"
        );

        _token.transfer(msg.sender, address(this), totalAmount, true, "");

        if (fee_amount != 0) {
            _token.transfer(
                address(this),
                marketplace.owner,
                fee_amount,
                true,
                ""
            );
        }

        if (royalty_fee_amount != 0) {
            _token.transfer(
                address(this),
                royaltyCollections[listedItem.nftAddress].royaltyCollector,
                royalty_fee_amount,
                true,
                ""
            );
        }

        _token.transfer(
            address(this),
            listedItem.lister,
            listedItem.ask,
            true,
            ""
        );

        ILSP8IdentifiableDigitalAsset asset = ILSP8IdentifiableDigitalAsset(
            listedItem.nftAddress
        );

        asset.transfer(address(this), msg.sender, listedItem.tokenId, true, "");
        listedItem.active = false;

        emit ItemPurchased(
            msg.sender,
            listedItem.lister,
            _listId,
            listedItem.nftAddress,
            listedItem.tokenId,
            listedItem.paymentToken,
            totalAmount
        );
    }

    function makeOffer(
        uint64 _listId,
        address _paymentToken,
        uint64 _offerPrice
    ) external {
        require(_offerPrice > 0, "Offer price must be greater than 0");
        require(_listId < marketplace.listed, "Invalid list ID");

        List storage listedItem = lists[_listId];
        require(listedItem.nftAddress != address(0), "Invalid nftAddress");

        uint64 offerId = uint64(listIdToOffers[_listId].length);

        Offer memory newOffer = Offer({
            offer_id: offerId,
            offerer: msg.sender,
            paymentToken: _paymentToken,
            offerPrice: _offerPrice,
            accepted: false
        });

        listIdToOffers[_listId].push(newOffer);
        listedItem.offers += 1;

        emit Offered(_listId, offerId, msg.sender, _paymentToken, _offerPrice);
    }

    function acceptOffer(
        uint64 _listId,
        uint64 _offerId
    ) external nonReentrant {
        List storage listedItem = lists[_listId];

        require(listedItem.lister == msg.sender, "Not lister");

        uint fee_amount;
        uint royalty_fee_amount;
        uint totalAmount;

        Offer storage _offer = listIdToOffers[_listId][_offerId];

        require(listedItem.active, "NFT is not listed");
        require(!_offer.accepted, "Offer already accepted");

        if (marketplace.fee_pbs > 0) {
            fee_amount = calculateFees(
                _offer.offerPrice,
                marketplace.fee_pbs,
                marketplace.collateral_fee
            );
            totalAmount += fee_amount;
        }

        if (check_exists_royalty_collection(listedItem.nftAddress)) {
            royalty_fee_amount = calculateRoyaltyCollectionFee(
                listedItem.nftAddress,
                _offer.offerPrice
            );
            totalAmount += royalty_fee_amount;
        }

        ILSP7DigitalAsset token = ILSP7DigitalAsset(_offer.paymentToken);
        require(
            token.balanceOf(_offer.offerer) >= totalAmount,
            "Insufficient funds"
        );

        token.transfer(_offer.offerer, address(this), totalAmount, true, "");

        if (fee_amount != 0) {
            token.transfer(
                address(this),
                marketplace.owner,
                fee_amount,
                true,
                ""
            );
        }

        if (royalty_fee_amount != 0) {
            token.transfer(
                address(this),
                listedItem.lister,
                totalAmount - fee_amount,
                true,
                ""
            );
        }

        ILSP8IdentifiableDigitalAsset asset = ILSP8IdentifiableDigitalAsset(
            listedItem.nftAddress
        );

        asset.transfer(
            address(this),
            _offer.offerer,
            listedItem.tokenId,
            true,
            ""
        );
        _offer.accepted = true;
        listedItem.active = false;

        emit ItemPurchased(
            _offer.offerer,
            listedItem.lister,
            _listId,
            listedItem.nftAddress,
            listedItem.tokenId,
            listedItem.paymentToken,
            totalAmount
        );
    }

    function removeOffer(uint64 _listId, uint64 _offerId) public {
        require(_listId < marketplace.listed, "List does not exist");
        require(
            _offerId < listIdToOffers[_listId].length,
            "Offer does not exist"
        );
        Offer storage _offer = listIdToOffers[_listId][_offerId];
        require(_offer.offerer == msg.sender, "Not the offerer");

        delete listIdToOffers[_listId][_offerId];

        emit OfferRemoved(_listId, _offerId);
    }

    // Auction
    // Function to facilitate NFT auctions, allowing users to bid on items
    function listAuction(
        address _nftAddress,
        bytes32 _tokenId,
        address payable _paymentToken,
        uint32 _minBid,
        uint32 _minBidIncrement,
        uint32 _startTime,
        uint32 _expirationTime
    ) external nonReentrant {
        if (_startTime < block.timestamp || _expirationTime < _startTime)
            revert("InvalidStartDate");
        if (_startTime < block.timestamp) revert("StartTimeMustBeInTheFuture");
        if (_expirationTime < _startTime)
            revert("ExpirationTimeMustBeAfterStartTime");

        ILSP8IdentifiableDigitalAsset asset = ILSP8IdentifiableDigitalAsset(
            _nftAddress
        );

        asset.transfer(msg.sender, address(this), _tokenId, true, "");

        require(
            asset.tokenOwnerOf(_tokenId) == address(this),
            "NFT not transferred"
        );

        AuctionItem memory newAuctionItem = AuctionItem({
            auctionId: marketplace.auctioned,
            nftAddress: _nftAddress,
            tokenId: _tokenId,
            paymentToken: _paymentToken,
            minBid: _minBid,
            minBidIncrement: _minBidIncrement,
            startTime: _startTime,
            expirationTime: _expirationTime,
            owner: address(this),
            seller: msg.sender,
            highestBidder: address(0),
            highestBid: 0,
            active: true
        });

        auctions[marketplace.auctioned] = newAuctionItem;
        marketplace.auctioned += 1;

        emit AuctionCreated(
            marketplace.auctioned - 1,
            newAuctionItem.nftAddress,
            newAuctionItem.tokenId,
            newAuctionItem.paymentToken,
            newAuctionItem.minBid,
            newAuctionItem.minBidIncrement,
            newAuctionItem.startTime,
            newAuctionItem.expirationTime,
            address(this),
            newAuctionItem.seller
        );
    }

    function placeBid(
        uint64 _auctionId,
        uint128 _bidAmount
    ) external nonReentrant {
        require(_auctionId < marketplace.auctioned, "Auction does not exist");

        AuctionItem storage auctionItem = auctions[_auctionId];

        require(auctionItem.active, "Auction is not active");

        require(
            block.timestamp > auctionItem.startTime &&
                block.timestamp < auctionItem.expirationTime,
            "Auction is not currently open for bids"
        );

        ILSP7DigitalAsset token = ILSP7DigitalAsset(auctionItem.paymentToken);

        require(
            _bidAmount >= auctionItem.highestBid + auctionItem.minBidIncrement,
            "Bid amount is too low"
        );

        require(
            token.balanceOf(msg.sender) >= _bidAmount,
            "Insufficient funds"
        );

        token.transfer(msg.sender, address(this), _bidAmount, true, "");

        auctionItem.highestBidder = msg.sender;
        auctionItem.highestBid = _bidAmount;

        emit BidPlaced(_auctionId, msg.sender, _bidAmount);
    }

    function endAuction(uint _auctionId) external nonReentrant {
        require(_auctionId < marketplace.auctioned, "Auction does not exist");
        AuctionItem storage auctionItem = auctions[_auctionId];
        require(auctionItem.active, "Auction is not active");
        require(
            block.timestamp >= auctionItem.expirationTime,
            "Auction has not yet expired"
        );

        require(
            auctionItem.highestBidder != address(0),
            "No valid bids in this auction"
        );

        ILSP7DigitalAsset token = ILSP7DigitalAsset(auctionItem.paymentToken);

        token.transfer(
            address(this),
            auctionItem.seller,
            auctionItem.highestBid,
            true,
            ""
        );

        ILSP8IdentifiableDigitalAsset asset = ILSP8IdentifiableDigitalAsset(
            auctionItem.nftAddress
        );

        asset.transfer(
            address(this),
            auctionItem.highestBidder,
            auctionItem.tokenId,
            true,
            ""
        );

        auctionItem.active = false;

        emit AuctionEnded(
            _auctionId,
            auctionItem.nftAddress,
            auctionItem.tokenId,
            auctionItem.paymentToken,
            auctionItem.highestBidder,
            auctionItem.highestBid
        );
    }

    // Collection Launch
    // Function to allow projects to apply for launching NFT collections on the platform
    function applyForCollectionLaunch(
        string memory _collectionName,
        address _NFTContract,
        address _royaltyCollector,
        uint _bps
    ) external {
        require(_bps <= 10000, "BPS must be <= 10000");

        uint applicationId = marketplace.nextApplicationId;

        NFTCollectionApplication
            memory newApplication = NFTCollectionApplication({
                application_id: applicationId,
                applicant: msg.sender,
                collectionName: _collectionName,
                NFTContract: _NFTContract,
                royaltyCollector: _royaltyCollector,
                bps: _bps,
                approved: false
            });

        collectionApplications[applicationId] = newApplication;

        marketplace.nextApplicationId++;
        emit CollectionApplication(
            applicationId,
            msg.sender,
            _collectionName,
            _NFTContract,
            _royaltyCollector,
            _bps,
            false
        );
    }

    function approveCollectionApplication(
        uint applicationId
    ) external onlyOwner {
        require(
            applicationId < marketplace.nextApplicationId,
            "Invalid application ID"
        );
        NFTCollectionApplication storage application = collectionApplications[
            applicationId
        ];
        require(!application.approved, "Application has already been approved");

        application.approved = true;

        emit CollectionApplicationApproved(
            applicationId,
            application.applicant
        );
    }

    // // Bundles
    function createBundle(
        address[] memory _nftAddresses,
        bytes32[] memory _tokenIds,
        address[] memory _paymentTokens,
        uint[] memory _prices
    ) external nonReentrant {
        require(
            _nftAddresses.length == _tokenIds.length &&
                _nftAddresses.length == _paymentTokens.length &&
                _nftAddresses.length == _prices.length,
            "Invalid bundle parameters"
        );
        require(
            _nftAddresses.length > 0,
            "Bundle must contain at least one NFT"
        );

        for (uint i = 0; i < _nftAddresses.length; i++) {
            ILSP8IdentifiableDigitalAsset asset = ILSP8IdentifiableDigitalAsset(
                _nftAddresses[i]
            );

            asset.transfer(msg.sender, address(this), _tokenIds[i], true, "");

            require(
                asset.isOperatorFor(address(this), _tokenIds[i]),
                "NFT not transferred"
            );
        }

        Bundle memory newBundle = Bundle({
            bundle_id: marketplace.volume,
            nftAddresses: _nftAddresses,
            tokenIds: _tokenIds,
            paymentTokens: _paymentTokens,
            prices: _prices,
            seller: msg.sender,
            active: true
        });

        bundles[marketplace.volume] = newBundle;

        emit BundleCreated(
            marketplace.volume,
            _nftAddresses,
            _tokenIds,
            _paymentTokens,
            _prices,
            msg.sender
        );

        marketplace.volume = marketplace.volume + 1;
    }

    function buyBundle(uint bundle_id) external nonReentrant {
        Bundle storage bundle = bundles[bundle_id];
        require(bundle.active, "Bundle is not active");

        uint totalBundlePrice = 0;
        for (uint i = 0; i < bundle.nftAddresses.length; i++) {
            require(
                bundle.nftAddresses[i] != address(0),
                "Invalid NFT address"
            );
            require(bundle.tokenIds[i] != 0, "Invalid token ID");
            require(
                bundle.paymentTokens[i] != address(0),
                "Invalid paymentToken address"
            );
            totalBundlePrice += bundle.prices[i];
        }

        require(totalBundlePrice > 0, "Invalid bundle price");

        for (uint i = 0; i < bundle.nftAddresses.length; i++) {
            ILSP8IdentifiableDigitalAsset asset = ILSP8IdentifiableDigitalAsset(
                bundle.nftAddresses[i]
            );

            asset.transfer(
                address(this),
                msg.sender,
                bundle.tokenIds[i],
                true,
                ""
            );
        }

        for (uint i = 0; i < bundle.nftAddresses.length; i++) {
            ILSP7DigitalAsset token = ILSP7DigitalAsset(
                bundle.paymentTokens[i]
            );

            token.transfer(
                msg.sender,
                bundle.seller,
                bundle.prices[i],
                true,
                ""
            );
        }

        bundle.active = false;

        emit BundlePurchased(bundle_id, msg.sender, bundle.seller);
    }
}
