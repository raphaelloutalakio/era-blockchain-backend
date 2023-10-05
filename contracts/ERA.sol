// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERATypes.sol";
import "hardhat/console.sol";

contract ERA is AccessControl, ReentrancyGuard {
    uint32 public storedData;

    function yourFunction(uint32 newValue) public {
        storedData = newValue;
    }

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR");

    /// Events
    event Listed(
        uint indexed list_id,
        address lister,
        address indexed nftAddress,
        uint indexed tokenId,
        address paymentToken,
        uint ask,
        address owner
    );

    event ItemDelisted(
        uint list_id,
        address indexed nftAddress,
        uint indexed tokenId,
        address indexed paymentToken,
        uint ask,
        address owner,
        address lister
    );

    event Offered(
        uint indexed listId,
        uint indexed offerId,
        address offerer,
        address paymentToken,
        uint offerPrice
    );

    event OfferRemoved(uint indexed listId, uint indexed offerId);

    event ItemPurchased(
        address indexed buyer,
        address indexed lister,
        uint indexed listId,
        address nftAddress,
        uint tokenId,
        address paymentToken,
        uint totalPrice
    );

    event ChangePrice(uint indexed item_id, address paymentToken, uint ask);

    event AuctionCreated(
        uint auctionId,
        address nftAddress,
        uint tokenId,
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
        uint tokenId,
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
        uint[] tokenIds,
        address[] paymentTokens,
        uint[] prices,
        address seller
    );

    event BundlePurchased(uint bundle_id, address buyer, address seller);

    Marketplace public marketplace;

    // Mappings
    mapping(address => RoyaltyCollection) public royaltyCollections;
    mapping(uint => List) public lists;
    mapping(uint => Offer[]) public listIdToOffers;
    mapping(uint => AuctionItem) public auctions;
    mapping(uint => NFTCollectionApplication) public collectionApplications;
    mapping(uint => Bundle) public bundles;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        marketplace.fee_pbs = 150;
        marketplace.collateral_fee = 10000;
        marketplace.owner = msg.sender;
    }

    function mutate_owner(address new_owner) public onlyRole(OPERATOR_ROLE) {
        marketplace.owner = new_owner;
    }

    function mutate_fee_pbs(uint new_fee_pbs) public onlyRole(OPERATOR_ROLE) {
        if (new_fee_pbs < marketplace.collateral_fee)
            marketplace.fee_pbs = new_fee_pbs;
    }

    function mutate_collateral_fee(
        uint new_collateral_fee
    ) public onlyRole(OPERATOR_ROLE) {
        marketplace.collateral_fee = new_collateral_fee;
    }

    function calculate_fees(
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
        address _lister,
        address _nftAddress,
        uint _tokenId,
        address _paymentToken,
        uint _ask
    ) external nonReentrant {
        require(_ask > 0, "Asked price should be greater than 0");

        IERC721 asset = IERC721(_nftAddress);
        asset.transferFrom(_lister, address(this), _tokenId);

        require(
            asset.ownerOf(_tokenId) == address(this),
            "NFT not transferred"
        );

        List memory newList = List({
            list_id: marketplace.listed,
            lister: _lister,
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
            _lister,
            _nftAddress,
            _tokenId,
            _paymentToken,
            _ask,
            address(this)
        );
    }

    function delist(address _lister, uint64 _listId) external {
        List storage listedItem = lists[_listId];

        require(listedItem.lister == _lister, "Not lister");
        require(listedItem.active, "NFT is not listed");

        IERC721 asset = IERC721(listedItem.nftAddress);
        asset.transferFrom(address(this), _lister, listedItem.tokenId);
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
        address _lister,
        uint64 _listId,
        address _paymentToken,
        uint64 _ask
    ) external {
        require(lists[_listId].lister == _lister, "Not lister");
        List storage listedItem = lists[_listId];
        listedItem.paymentToken = _paymentToken;
        listedItem.ask = _ask;

        emit ChangePrice(_listId, _paymentToken, _ask);
    }

    function buy(address _buyer, uint64 _listId) external nonReentrant {
        uint fee_amount;
        uint royalty_fee_amount;

        List storage listedItem = lists[_listId];
        require(listedItem.active, "NFT is not listed");

        uint totalAmount = listedItem.ask;

        if (marketplace.fee_pbs > 0) {
            fee_amount = calculate_fees(
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

        IERC20 _token = IERC20(listedItem.paymentToken);

        require(_token.balanceOf(_buyer) >= totalAmount, "Insufficient funds");

        require(
            _token.transferFrom(_buyer, address(this), totalAmount),
            "Transfer from buyer failed"
        );

        if (fee_amount != 0) {
            require(
                _token.transfer(marketplace.owner, fee_amount),
                "Fee transfer failed"
            );
        }

        if (royalty_fee_amount != 0) {
            require(
                _token.transfer(
                    royaltyCollections[listedItem.nftAddress].royaltyCollector,
                    royalty_fee_amount
                ),
                "Royalty fee transfer failed"
            );
        }

        require(
            _token.transfer(listedItem.lister, listedItem.ask),
            "Transfer to lister failed"
        );

        IERC721 asset = IERC721(listedItem.nftAddress);
        asset.transferFrom(address(this), _buyer, listedItem.tokenId);
        listedItem.active = false;

        emit ItemPurchased(
            _buyer,
            listedItem.lister,
            _listId,
            listedItem.nftAddress,
            listedItem.tokenId,
            listedItem.paymentToken,
            totalAmount
        );
    }

    function makeOffer(
        address _offerer, // caller
        uint64 _listId,
        address _paymentToken,
        uint64 _offerPrice
    ) external {
        require(_offerPrice > 0, "Offer price must be greater than 0");
        require(_listId < marketplace.listed, "Invalid list ID");

        List storage listedItem = lists[_listId];
        require(listedItem.nftAddress != address(0), "Invalid nftAddress");

        uint offerId = listIdToOffers[_listId].length;

        Offer memory newOffer = Offer({
            offer_id: offerId,
            offerer: _offerer,
            paymentToken: _paymentToken,
            offerPrice: _offerPrice,
            accepted: false
        });

        listIdToOffers[_listId].push(newOffer);
        listedItem.offers += 1;

        emit Offered(_listId, offerId, _offerer, _paymentToken, _offerPrice);
    }

    function acceptOffer(
        uint64 _listId,
        uint64 _offerId
    ) external nonReentrant {
        uint fee_amount;
        uint royalty_fee_amount;
        uint totalAmount;

        List storage listedItem = lists[_listId];
        Offer storage _offer = listIdToOffers[_listId][_offerId];

        require(listedItem.active, "NFT is not listed");
        require(!_offer.accepted, "Offer already accepted");

        if (marketplace.fee_pbs > 0) {
            fee_amount = calculate_fees(
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

        IERC20 token = IERC20(_offer.paymentToken);

        require(
            token.balanceOf(_offer.offerer) >= totalAmount,
            "Insufficient funds"
        );

        require(
            token.transferFrom(_offer.offerer, address(this), totalAmount),
            "Transfer from offer failed"
        );

        if (fee_amount != 0) {
            require(
                token.transfer(marketplace.owner, fee_amount),
                "Fee transfer failed"
            );
        }

        if (royalty_fee_amount != 0) {
            require(
                token.transfer(listedItem.lister, totalAmount - fee_amount),
                "Royalty fee transfer failed"
            );
        }

        IERC721 asset = IERC721(listedItem.nftAddress);
        asset.transferFrom(address(this), _offer.offerer, listedItem.tokenId);
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

    // check offer is caller or not
    function removeOffer(address _offerer, uint _listId, uint _offerId) public {
        require(_listId < marketplace.listed, "List does not exist");
        require(
            _offerId < listIdToOffers[_listId].length,
            "Offer does not exist"
        );

        delete listIdToOffers[_listId][_offerId];

        emit OfferRemoved(_listId, _offerId);
    }

    // Auction
    // Function to facilitate NFT auctions, allowing users to bid on items
    function listAuction(
        address _seller,
        address _nftAddress,
        uint _tokenId,
        address _paymentToken,
        uint _minBid,
        uint _minBidIncrement,
        uint _startTime,
        uint _expirationTime
    ) external nonReentrant {
        if (_startTime < block.timestamp || _expirationTime < _startTime)
            revert("InvalidStartDate");
        if (_startTime < block.timestamp) revert("StartTimeMustBeInTheFuture");
        if (_expirationTime < _startTime)
            revert("ExpirationTimeMustBeAfterStartTime");

        IERC721 asset = IERC721(_nftAddress);
        asset.transferFrom(_seller, address(this), _tokenId);

        require(
            asset.ownerOf(_tokenId) == address(this),
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
            seller: _seller,
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
        address _bidder,
        uint _auctionId,
        uint _bidAmount
    ) external nonReentrant {
        require(_auctionId < marketplace.auctioned, "Auction does not exist");

        AuctionItem storage auctionItem = auctions[_auctionId];

        require(auctionItem.active, "Auction is not active");

        require(
            block.timestamp > auctionItem.startTime &&
                block.timestamp < auctionItem.expirationTime,
            "Auction is not currently open for bids"
        );

        IERC20 token = IERC20(auctionItem.paymentToken);

        require(
            _bidAmount >= auctionItem.highestBid + auctionItem.minBidIncrement,
            "Bid amount is too low"
        );

        require(token.balanceOf(_bidder) >= _bidAmount, "Insufficient funds");

        require(
            token.transferFrom(_bidder, address(this), _bidAmount),
            "Transfer from bidder failed"
        );

        auctionItem.highestBidder = _bidder;
        auctionItem.highestBid = _bidAmount;

        emit BidPlaced(_auctionId, _bidder, _bidAmount);
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

        IERC20 token = IERC20(auctionItem.paymentToken);

        require(
            token.transfer(auctionItem.seller, auctionItem.highestBid),
            "Transfer to seller failed"
        );

        IERC721 nft = IERC721(auctionItem.nftAddress);
        nft.transferFrom(
            address(this),
            auctionItem.highestBidder,
            auctionItem.tokenId
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
    ) external onlyRole(OPERATOR_ROLE) {
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

    // Bundles
    function createBundle(
        address[] memory _nftAddresses,
        uint[] memory _tokenIds,
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
            IERC721 asset = IERC721(_nftAddresses[i]);
            asset.transferFrom(msg.sender, address(this), _tokenIds[i]);
            require(
                asset.ownerOf(_tokenIds[i]) == address(this),
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
            IERC721 asset = IERC721(bundle.nftAddresses[i]);
            asset.transferFrom(address(this), msg.sender, bundle.tokenIds[i]);
        }

        for (uint i = 0; i < bundle.nftAddresses.length; i++) {
            IERC20(bundle.paymentTokens[i]).transferFrom(
                msg.sender,
                bundle.seller,
                bundle.prices[i]
            );
        }

        bundle.active = false;

        emit BundlePurchased(bundle_id, msg.sender, bundle.seller);
    }
}
