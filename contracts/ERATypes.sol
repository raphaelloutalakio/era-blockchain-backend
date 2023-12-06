// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

struct Marketplace {
    uint fee_pbs;
    uint collateral_fee;
    uint volume;
    uint64 listed;
    uint offered;
    uint64 auctioned;
    address owner;
    uint64 nextApplicationId;
}

struct List {
    uint64 list_id;
    address lister;
    address nftAddress;
    uint64 tokenId;
    address paymentToken;
    uint128 ask;
    address owner;
    uint offers;
    bool active;
}

struct Offer {
    uint64 offer_id;
    address offerer;
    address paymentToken;
    uint64 offerPrice;
    bool accepted;
}

struct AuctionItem {
    uint64 auctionId;
    address nftAddress;
    uint64 tokenId;
    address paymentToken;
    uint32 minBid;
    uint32 minBidIncrement;
    uint32 startTime;
    uint32 expirationTime;
    address owner;
    address seller;
    address highestBidder;
    uint128 highestBid;
    bool active;
}

struct RoyaltyCollection {
    address creator;
    uint bps;
    address royaltyCollector;
}

struct NFTCollectionApplication {
    uint application_id;
    address applicant;
    string collectionName;
    address NFTContract;
    address royaltyCollector;
    uint bps;
    bool approved;
}

struct Bundle {
    uint bundle_id;
    address[] nftAddresses;
    uint64[] tokenIds;
    address[] paymentTokens;
    uint[] prices;
    address seller;
    bool active;
}
