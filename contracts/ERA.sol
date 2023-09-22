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
    uint256 public storedData;

    function yourFunction(uint256 newValue) public {
        storedData = newValue;
    }

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR");

    /// Events
    event Listed(
        uint256 list_id,
        address lister,
        address nftAddress,
        uint256 tokenId,
        address paymentToken,
        uint256 ask,
        address owner
    );

    event ItemDelisted(
        uint256 list_id,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed paymentToken,
        uint256 ask,
        address owner,
        address lister
    );

    event Offered(
        uint256 listId,
        uint256 offerId,
        address offerer,
        address paymentToken,
        uint256 offerPrice
    );

    event OfferRemoved(uint256 listId, uint256 offerId);

    event ItemPurchased(
        address indexed buyer,
        address indexed lister,
        uint256 indexed listId,
        address nftAddress,
        uint256 tokenId,
        address paymentToken,
        uint256 totalPrice
    );

    event ChangePrice(uint256 item_id, address paymentToken, uint256 ask);

    event AuctionCreated(
        uint256 auction_id,
        address nftAddress,
        uint256 item_id,
        address paymentToken,
        uint256 min_bid,
        uint256 min_bid_increment,
        uint256 starts,
        uint256 expires,
        address owner
    );

    event AuctionBid(
        uint256 auction_id,
        address nftAddress,
        uint256 item_id,
        address paymentToken,
        uint256 bid,
        address bidder
    );

    event AuctionEnded(
        uint256 auction_id,
        address nftAddress,
        uint256 item_id,
        address paymentToken,
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
        address[] paymentTokens,
        uint256[] prices,
        address seller
    );

    event BundlePurchased(uint256 bundle_id, address buyer, address seller);

    Marketplace public marketplace;

    // Mappings
    mapping(address => RoyaltyCollection) public royaltyCollections;
    mapping(uint256 => List) public lists;
    mapping(uint => Offer[]) public listIdToOffers;
    mapping(uint256 => AuctionListing) public auctions;
    mapping(uint256 => NFTCollectionApplication) public collectionApplications;
    mapping(uint256 => Bundle) public bundles;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        marketplace.fee_pbs = 150;
        marketplace.collateral_fee = 10000;
        marketplace.owner = msg.sender;
    }

    function mutate_owner(address new_owner) public onlyRole(OPERATOR_ROLE) {
        marketplace.owner = new_owner;
    }

    function mutate_fee_pbs(
        uint256 new_fee_pbs
    ) public onlyRole(OPERATOR_ROLE) {
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
        address _nftAddress,
        uint256 bps,
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
        uint256 bps,
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
        uint256 amount
    ) public view returns (uint256) {
        return
            (amount * royaltyCollections[_nftAddress].bps) /
            marketplace.collateral_fee;
    }

    function list(
        address _lister,
        address _nftAddress,
        uint256 _tokenId,
        address _paymentToken,
        uint256 _ask
    ) external nonReentrant {
        require(_ask > 0, "EInvalidList");

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

        marketplace.listed = marketplace.listed + 1;

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

    function changePrice(
        address _lister,
        uint256 _listId,
        address _paymentToken,
        uint256 _ask
    ) external {
        require(lists[_listId].lister == _lister, "Not lister");
        List storage listedItem = lists[_listId];
        listedItem.paymentToken = _paymentToken;
        listedItem.ask = _ask;

        emit ChangePrice(_listId, _paymentToken, _ask);
    }

    function delist(address _lister, uint256 _listId) external {
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

    function buy(address _buyer, uint256 _listId) external nonReentrant {
        uint256 fee_amount;
        uint256 royalty_fee_amount;

        List storage listedItem = lists[_listId];
        require(listedItem.active, "NFT is not listed");

        uint256 totalAmount = listedItem.ask;

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
        uint256 _listId,
        address _offerer, // caller
        address _paymentToken,
        uint256 _offerPrice
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
        uint256 _listId,
        uint256 _offerId
    ) external nonReentrant {
        uint256 fee_amount;
        uint256 royalty_fee_amount;
        uint256 totalAmount;

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

        IERC20 _token = IERC20(_offer.paymentToken);

        require(
            _token.balanceOf(_offer.offerer) >= totalAmount,
            "Insufficient funds"
        );

        require(
            _token.transferFrom(_offer.offerer, address(this), totalAmount),
            "Transfer from offer failed"
        );

        if (fee_amount != 0) {
            require(
                _token.transfer(marketplace.owner, fee_amount),
                "Fee transfer failed"
            );
        }

        if (royalty_fee_amount != 0) {
            require(
                _token.transfer(listedItem.lister, totalAmount - fee_amount),
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
    function removeOffer(
        address _offerer,
        uint256 _listId,
        uint256 _offerId
    ) public {
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
            IERC20(auction.paymentToken).transfer(
                auction.highestBidder,
                auction.highestBid
            );
        }

        IERC20(auction.paymentToken).transferFrom(
            msg.sender,
            address(this),
            _bidAmount
        );

        auction.highestBid = _bidAmount;
        auction.highestBidder = msg.sender;

        emit AuctionBid(
            _auctionId,
            auction.nftAddress,
            auction.item_id,
            auction.paymentToken,
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

        IERC721(auction.nftAddress).transferFrom(
            address(this),
            auction.highestBidder,
            auction.item_id
        );

        auction.active = false;

        emit AuctionEnded(
            _auctionId,
            auction.nftAddress,
            auction.item_id,
            auction.paymentToken,
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
        address[] memory _paymentTokens,
        uint256[] memory _prices
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
            require(
                bundle.paymentTokens[i] != address(0),
                "Invalid paymentToken address"
            );
            totalBundlePrice += bundle.prices[i];
        }

        require(totalBundlePrice > 0, "Invalid bundle price");

        for (uint256 i = 0; i < bundle.nftAddresses.length; i++) {
            IERC721 asset = IERC721(bundle.nftAddresses[i]);
            asset.transferFrom(address(this), msg.sender, bundle.tokenIds[i]);
        }

        for (uint256 i = 0; i < bundle.nftAddresses.length; i++) {
            IERC20(bundle.paymentTokens[i]).transferFrom(
                msg.sender,
                bundle.seller,
                bundle.prices[i]
            );
        }

        bundle.active = false;

        emit BundlePurchased(bundle_id, msg.sender, bundle.seller);
    }

    function getRoyaltyCollection(
        address _nftAddress
    )
        external
        view
        returns (address creator, uint256 bps, address royaltyCollector)
    {
        require(
            check_exists_royalty_collection(_nftAddress),
            "Royalty collection not found"
        );
        RoyaltyCollection storage royalty = royaltyCollections[_nftAddress];
        return (royalty.creator, royalty.bps, royalty.royaltyCollector);
    }

    function getList(
        uint256 _listId
    )
        external
        view
        returns (
            address nftAddress,
            uint256 tokenId,
            address paymentToken,
            uint256 ask,
            address owner,
            address lister,
            uint256 _offers
        )
    {
        require(_listId < marketplace.listed, "Invalid list ID");
        List storage _list = lists[_listId];
        return (
            _list.nftAddress,
            _list.tokenId,
            _list.paymentToken,
            _list.ask,
            _list.owner,
            _list.lister,
            _list.offers
        );
    }

    // function getOffer(
    //     uint256 _offerId
    // )
    //     external
    //     view
    //     returns (
    //         uint256 listId,
    //         address nftAddress,
    //         uint256 tokenId,
    //         address paymentToken,
    //         uint256 offerPrice,
    //         address offerer,
    //         bool accepted
    //     )
    // {
    //     require(_offerId < marketplace.offered, "Invalid offer ID");
    //     Offer storage offer = offers[_offerId];
    //     return (
    //         offer.listId,
    //         offer.nftAddress,
    //         offer.tokenId,
    //         offer.paymentToken,
    //         offer.offerPrice,
    //         offer.offerer,
    //         offer.accepted
    //     );
    // }

    function getAuction(
        uint256 _auctionId
    )
        external
        view
        returns (
            address nftAddress,
            uint256 item_id,
            address paymentToken,
            uint256 min_bid,
            uint256 min_bid_increment,
            uint256 starts,
            uint256 expires,
            address owner,
            address highestBidder,
            uint256 highestBid,
            bool active
        )
    {
        require(_auctionId < marketplace.auctions, "Invalid auction ID");
        AuctionListing storage auction = auctions[_auctionId];
        return (
            auction.nftAddress,
            auction.item_id,
            auction.paymentToken,
            auction.min_bid,
            auction.min_bid_increment,
            auction.starts,
            auction.expires,
            auction.owner,
            auction.highestBidder,
            auction.highestBid,
            auction.active
        );
    }

    function getCollectionApplication(
        uint256 _applicationId
    )
        external
        view
        returns (
            address applicant,
            string memory collectionName,
            address NFTContract,
            address royaltyCollector,
            uint256 bps,
            bool approved
        )
    {
        require(
            _applicationId < marketplace.nextApplicationId,
            "Invalid application ID"
        );
        NFTCollectionApplication storage application = collectionApplications[
            _applicationId
        ];
        return (
            application.applicant,
            application.collectionName,
            application.NFTContract,
            application.royaltyCollector,
            application.bps,
            application.approved
        );
    }

    function getBundle(
        uint256 _bundle_id
    )
        external
        view
        returns (
            address[] memory nftAddresses,
            uint256[] memory tokenIds,
            address[] memory paymentTokens,
            uint256[] memory prices,
            address seller,
            bool active
        )
    {
        require(_bundle_id < marketplace.volume, "Invalid bundle ID");
        Bundle storage bundle = bundles[_bundle_id];
        return (
            bundle.nftAddresses,
            bundle.tokenIds,
            bundle.paymentTokens,
            bundle.prices,
            bundle.seller,
            bundle.active
        );
    }
}
