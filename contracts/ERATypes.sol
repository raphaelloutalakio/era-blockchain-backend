// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

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
    address lister;
    address nftAddress;
    uint256 tokenId;
    address paymentToken;
    uint256 ask;
    address owner;
    uint256 offers;
}

struct Offer {
    uint256 offer_id;
    uint256 listId;
    address nftAddress;
    uint256 tokenId;
    address paymentToken;
    uint256 offerPrice;
    address offerer;
    bool accepted;
}

struct AuctionListing {
    uint256 auction_id;
    address nftAddress;
    uint256 item_id;
    address paymentToken;
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
    address[] paymentTokens;
    uint256[] prices;
    address seller;
    bool active;
}
