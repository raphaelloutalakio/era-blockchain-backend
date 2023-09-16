// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ERA is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR");

    /// Structs
    struct Marketplace {
        uint256 fee_pbs;
        uint256 collateral_fee;
        uint256 volume;
        uint256 listed;
        uint256 offered;
        uint256 auctions;
        address owner;
        uint256 nextApplicationId;
    }

    struct List {
        uint256 list_id;
        address NFT;
        uint256 tokenId;
        address COIN;
        uint256 ask;
        address owner;
        address lister;
        uint256 offers;
    }

    struct Offer {
        uint256 offer_id;
        address NFT;
        uint256 tokenId;
        address COIN;
        uint256 offerPrice;
        address offerer;
    }

    struct AuctionListing {
        uint256 auction_id;
        address NFT;
        uint256 item_id;
        address COIN;
        uint256 min_bid;
        uint256 min_bid_increment;
        uint256 starts;
        uint256 expires;
        address owner;
        address highestBidder;
        uint256 highestBid;
        bool active;
    }

    struct RoyaltyCollection {
        address creator;
        uint256 bps;
        address royaltyCollector;
    }

    struct NFTCollectionApplication {
        uint256 application_id;
        address applicant;
        string collectionName;
        address NFTContract;
        address royaltyCollector;
        uint256 bps;
        bool approved;
    }

    struct Bundle {
        uint256 bundle_id;
        address[] nftAddresses;
        uint256[] tokenIds;
        address[] coins;
        uint256[] prices;
        address seller;
        bool active;
    }

    /// Events
    event Listing(
        uint256 list_id,
        address NFT,
        uint256 Token_ID,
        address token,
        uint256 amount,
        address seller,
        uint256 expires
    );

    event DeList(uint256 item_id);

    event AddOffer(
        uint256 offer_id,
        address NFT,
        uint256 Token_ID,
        address token,
        uint256 amount,
        address offer
    );

    event RemoveOffer(uint256 offer_id);

    event Buy(
        address NFT,
        uint256 item_id,
        address COIN,
        uint256 amount,
        address buyer,
        address seller
    );

    event ChangePrice(uint256 item_id, address COIN, uint256 ask);

    event AuctionCreated(
        uint256 auction_id,
        address NFT,
        uint256 item_id,
        address COIN,
        uint256 min_bid,
        uint256 min_bid_increment,
        uint256 starts,
        uint256 expires,
        address owner
    );

    event AuctionBid(
        uint256 auction_id,
        address NFT,
        uint256 item_id,
        address COIN,
        uint256 bid,
        address bidder
    );

    event AuctionEnded(
        uint256 auction_id,
        address NFT,
        uint256 item_id,
        address COIN,
        address winner,
        uint256 winningBid
    );

    event CollectionApplication(
        uint256 application_id,
        address applicant,
        string collectionName,
        address NFTContract,
        address royaltyCollector,
        uint256 bps,
        bool approved
    );

    event CollectionApplicationApproved(
        uint256 indexed applicationId,
        address indexed applicant
    );

    event BundleCreated(
        uint256 bundle_id,
        address[] nftAddresses,
        uint256[] tokenIds,
        address[] coins,
        uint256[] prices,
        address seller
    );

    event BundlePurchased(uint256 bundle_id, address buyer, address seller);

    Marketplace public marketplace;

    // Mappings
    mapping(address => RoyaltyCollection) public royaltyCollections;
    mapping(uint256 => List) lists;
    mapping(uint256 => Offer) offers;
    mapping(uint256 => AuctionListing) public auctions;
    mapping(uint256 => NFTCollectionApplication) public collectionApplications;
    mapping(uint256 => Bundle) public bundles;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        marketplace.fee_pbs = 150;
        marketplace.collateral_fee = 10000;
        marketplace.volume = 0;
        marketplace.listed = 0;
        marketplace.offered = 0;
        marketplace.auctions = 0;
        marketplace.owner = msg.sender;
    }

    function mutate_owner(address new_owner) public {
        require(msg.sender == marketplace.owner, "ENotOwner");
        marketplace.owner = new_owner;
    }

    function mutate_fee_pbs(uint256 new_fee_pbs) public {
        require(msg.sender == marketplace.owner, "ENotOwner");
        if (new_fee_pbs < marketplace.collateral_fee)
            marketplace.fee_pbs = new_fee_pbs;
    }

    function mutate_collateral_fee(
        uint256 new_collateral_fee
    ) public onlyRole(OPERATOR_ROLE) {
        marketplace.collateral_fee = new_collateral_fee;
    }

    function calculate_fees(
        uint256 amount,
        uint256 fee_pbs,
        uint256 collateral_fee
    ) public pure returns (uint256) {
        return (amount * fee_pbs) / collateral_fee;
    }

    function add_royalty_collection(
        address NFT,
        uint256 bps,
        address royaltyCollector
    ) public {
        RoyaltyCollection memory newRoyaltyCollector;
        newRoyaltyCollector.creator = msg.sender;
        newRoyaltyCollector.bps = bps;
        newRoyaltyCollector.royaltyCollector = royaltyCollector;
        royaltyCollections[NFT] = newRoyaltyCollector;
    }

    function check_exists_royalty_collection(
        address NFT
    ) public view returns (bool) {
        return royaltyCollections[NFT].creator != address(0);
    }

    function update_royalty_collection(
        address NFT,
        uint256 bps,
        address royaltyCollector
    ) public {
        require(royaltyCollections[NFT].creator == msg.sender, "EInvliadOwner");
        royaltyCollections[NFT].creator = msg.sender;
        royaltyCollections[NFT].bps = bps;
        royaltyCollections[NFT].royaltyCollector = royaltyCollector;
    }

    function calculate_royalty_collection_fee(
        address NFT,
        uint256 amount
    ) public view returns (uint256) {
        return
            (amount * royaltyCollections[NFT].bps) / marketplace.collateral_fee;
    }

    function list(
        address _nftAddress,
        uint256 _tokenId,
        address _coin,
        uint256 _ask
    ) external nonReentrant {
        require(_ask > 0, "EInvalidList");

        IERC721 asset = IERC721(_nftAddress);
        asset.transferFrom(msg.sender, address(this), _tokenId);

        require(
            asset.ownerOf(_tokenId) == address(this),
            "NFT not transferred"
        );

        List memory newList = List({
            list_id: marketplace.listed,
            NFT: _nftAddress,
            tokenId: _tokenId,
            COIN: _coin,
            ask: _ask,
            owner: address(this),
            lister: msg.sender,
            offers: 0
        });

        lists[marketplace.listed] = newList;

        emit Listing(
            marketplace.listed,
            _nftAddress,
            _tokenId,
            _coin,
            _ask,
            msg.sender,
            0
        );

        marketplace.listed = marketplace.listed + 1;
    }

    function changePrice(uint256 list_id, address _coin, uint256 ask) external {
        require(lists[list_id].lister == msg.sender, "Not lister");
        lists[list_id].COIN = _coin;
        lists[list_id].ask = ask;
        emit ChangePrice(list_id, lists[list_id].COIN, lists[list_id].ask);
    }

    function delist(uint256 list_id) external {
        require(lists[list_id].lister == msg.sender, "Not lister");
        lists[list_id].owner = address(0);
        lists[list_id].lister = address(0);

        IERC721 asset = IERC721(lists[list_id].NFT);
        asset.transferFrom(address(this), msg.sender, lists[list_id].tokenId);

        emit DeList(list_id);
    }

    function buy(uint256 list_id) external nonReentrant {
        uint256 fee_amount;
        uint256 royalty_fee_amount;
        if (marketplace.fee_pbs > 0) {
            fee_amount = calculate_fees(
                lists[list_id].ask,
                marketplace.fee_pbs,
                marketplace.collateral_fee
            );
        }

        if (check_exists_royalty_collection(lists[list_id].NFT)) {
            royalty_fee_amount = calculate_royalty_collection_fee(
                lists[list_id].NFT,
                lists[list_id].ask
            );
        }

        if (fee_amount != 0)
            IERC20(lists[list_id].COIN).transferFrom(
                msg.sender,
                marketplace.owner,
                fee_amount
            );

        if (royalty_fee_amount != 0)
            IERC20(lists[list_id].COIN).transferFrom(
                msg.sender,
                royaltyCollections[lists[list_id].NFT].royaltyCollector,
                fee_amount
            );

        IERC20(lists[list_id].COIN).transferFrom(
            msg.sender,
            lists[list_id].owner,
            lists[list_id].ask - fee_amount - royalty_fee_amount
        );

        IERC721 asset = IERC721(lists[list_id].NFT);
        asset.transferFrom(address(this), msg.sender, lists[list_id].tokenId);

        emit Buy(
            lists[list_id].NFT,
            lists[list_id].tokenId,
            lists[list_id].COIN,
            lists[list_id].ask,
            lists[list_id].owner,
            msg.sender
        );

        // Delist the list because the list of accepted.
        lists[list_id].owner = address(0);
        emit DeList(list_id);
    }

    function make_offer(
        address _nftAddress,
        uint256 _tokenId,
        address _coin,
        uint256 _offerPrice
    ) external {
        Offer memory newOffer = Offer({
            offer_id: marketplace.offered,
            NFT: _nftAddress,
            tokenId: _tokenId,
            COIN: _coin,
            offerPrice: _offerPrice,
            offerer: msg.sender
        });

        offers[marketplace.offered] = newOffer;

        emit AddOffer(
            marketplace.offered,
            _nftAddress,
            _tokenId,
            _coin,
            _offerPrice,
            msg.sender
        );
        marketplace.offered = marketplace.offered + 1;
    }

    function remove_offer(uint256 offer_id) public {
        require(offers[offer_id].offerer == msg.sender, "E_Invalid_Owner");
        offers[offer_id].offerer = address(0);
        emit RemoveOffer(offer_id);
    }

    function accept_offer(uint256 offer_id) external nonReentrant {
        uint256 fee_amount;
        uint256 royalty_fee_amount;
        if (marketplace.fee_pbs > 0) {
            fee_amount = calculate_fees(
                offers[offer_id].offerPrice,
                marketplace.fee_pbs,
                marketplace.collateral_fee
            );
        }

        if (check_exists_royalty_collection(offers[offer_id].NFT)) {
            royalty_fee_amount = calculate_royalty_collection_fee(
                offers[offer_id].NFT,
                offers[offer_id].offerPrice
            );
        }

        if (fee_amount != 0)
            IERC20(offers[offer_id].COIN).transferFrom(
                offers[offer_id].offerer,
                marketplace.owner,
                fee_amount
            );

        if (royalty_fee_amount != 0)
            IERC20(offers[offer_id].COIN).transferFrom(
                offers[offer_id].offerer,
                msg.sender,
                offers[offer_id].offerPrice - fee_amount
            );

        IERC721 asset = IERC721(offers[offer_id].NFT);
        asset.transferFrom(
            address(this),
            offers[offer_id].offerer,
            offers[offer_id].tokenId
        );

        emit Buy(
            offers[offer_id].NFT,
            offers[offer_id].tokenId,
            offers[offer_id].COIN,
            offers[offer_id].offerPrice,
            msg.sender,
            offers[offer_id].offerer
        );
        offers[offer_id].offerer = address(0);
        emit RemoveOffer(offer_id);
    }

    // Auction
    // Function to facilitate NFT auctions, allowing users to bid on items
    function placeBid(
        uint256 _auctionId,
        uint256 _bidAmount
    ) external nonReentrant {
        AuctionListing storage auction = auctions[_auctionId];

        require(auction.active, "Auction is not active");

        require(
            _bidAmount > auction.highestBid,
            "Bid amount must be higher than the current highest bid"
        );

        require(
            _bidAmount >= auction.min_bid,
            "Bid amount is below the minimum bid"
        );

        require(
            _bidAmount >= auction.highestBid + auction.min_bid_increment,
            "Bid increment not met"
        );

        if (auction.highestBidder != address(0)) {
            IERC20(auction.COIN).transfer(
                auction.highestBidder,
                auction.highestBid
            );
        }

        IERC20(auction.COIN).transferFrom(
            msg.sender,
            address(this),
            _bidAmount
        );

        auction.highestBid = _bidAmount;
        auction.highestBidder = msg.sender;

        emit AuctionBid(
            _auctionId,
            auction.NFT,
            auction.item_id,
            auction.COIN,
            _bidAmount,
            msg.sender
        );
    }

    // Function to end auctions and transfer the NFT to the winning bidder
    function endAuction(uint256 _auctionId) external nonReentrant {
        AuctionListing storage auction = auctions[_auctionId];

        require(
            block.timestamp >= auction.expires,
            "Auction has not yet expired"
        );

        require(auction.highestBidder != address(0), "No bids received");

        IERC721(auction.NFT).transferFrom(
            address(this),
            auction.highestBidder,
            auction.item_id
        );

        auction.active = false;

        emit AuctionEnded(
            _auctionId,
            auction.NFT,
            auction.item_id,
            auction.COIN,
            auction.highestBidder,
            auction.highestBid
        );
    }

    // Collection Launch
    // Function to allow projects to apply for launching NFT collections on the platform
    function applyForCollectionLaunch(
        string memory _collectionName,
        address _NFTContract,
        address _royaltyCollector,
        uint256 _bps
    ) external {
        require(_bps <= 10000, "BPS must be <= 10000");

        uint256 applicationId = marketplace.nextApplicationId;

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
        uint256 applicationId
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
        uint256[] memory _tokenIds,
        address[] memory _coins,
        uint256[] memory _prices
    ) external nonReentrant {
        require(
            _nftAddresses.length == _tokenIds.length &&
                _nftAddresses.length == _coins.length &&
                _nftAddresses.length == _prices.length,
            "Invalid bundle parameters"
        );
        require(
            _nftAddresses.length > 0,
            "Bundle must contain at least one NFT"
        );

        for (uint256 i = 0; i < _nftAddresses.length; i++) {
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
            coins: _coins,
            prices: _prices,
            seller: msg.sender,
            active: true
        });

        bundles[marketplace.volume] = newBundle;

        emit BundleCreated(
            marketplace.volume,
            _nftAddresses,
            _tokenIds,
            _coins,
            _prices,
            msg.sender
        );

        marketplace.volume = marketplace.volume + 1;
    }

    function buyBundle(uint256 bundle_id) external nonReentrant {
        Bundle storage bundle = bundles[bundle_id];
        require(bundle.active, "Bundle is not active");

        uint256 totalBundlePrice = 0;
        for (uint256 i = 0; i < bundle.nftAddresses.length; i++) {
            require(
                bundle.nftAddresses[i] != address(0),
                "Invalid NFT address"
            );
            require(bundle.tokenIds[i] != 0, "Invalid token ID");
            require(bundle.coins[i] != address(0), "Invalid coin address");
            totalBundlePrice += bundle.prices[i];
        }

        require(totalBundlePrice > 0, "Invalid bundle price");

        for (uint256 i = 0; i < bundle.nftAddresses.length; i++) {
            IERC721 asset = IERC721(bundle.nftAddresses[i]);
            asset.transferFrom(address(this), msg.sender, bundle.tokenIds[i]);
        }

        for (uint256 i = 0; i < bundle.nftAddresses.length; i++) {
            IERC20(bundle.coins[i]).transferFrom(
                msg.sender,
                bundle.seller,
                bundle.prices[i]
            );
        }

        bundle.active = false;

        emit BundlePurchased(bundle_id, msg.sender, bundle.seller);
    }
}
