// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function transferFrom(address _from, address _to, uint256 _nftId) external;
}

contract CombinedAuction {
    error InsufficientFunds(string helper);
    error BidNotHighEnough(string helper);
    error AuctionIsOver();
    error DutchPhaseIsOver();
    error NotInEnglishPhase();
    error AuctionNotEnded();
    error YouAreNotTheSeller();
    error NoFundsToWithdraw();
    error HighestBidderCantWithdraw();

    enum AuctionType {
        Dutch,
        English
    }

    mapping(address => uint256) public bids;

    IERC721 public nft;
    uint256 public nftId;
    AuctionType public currentAuctionType;

    uint256 public duration = 7 days;
    address payable public seller;
    uint256 public startPrice;
    uint256 public endPrice;
    uint256 public dutchEndAt;
    uint256 public englishEndAt;
    address public highestBidder;
    uint256 public highestBid;

    bool public dutchPhaseOver;
    bool public englishPhaseOver;

    event AuctionStarted(
        address indexed seller, uint256 indexed nftId, uint256 startPrice, uint256 endPrice, uint256 dutchEndAt
    );
    event AuctionEnded(address indexed receiver, uint256 indexed highestBid, uint256 nftId);
    event Bid(address indexed bidder, uint256 indexed bid);
    event Buy(address indexed buyer, uint256 indexed bid);
    event BidderWithdraw(address indexed bidder, uint256 indexed amount);
    event SellerWithdraw(address indexed seller, uint256 indexed amount);

    modifier onlyDuringDutchPhase() {
        if (block.timestamp > dutchEndAt) {
            revert AuctionIsOver();
        } else if (dutchPhaseOver) {
            revert DutchPhaseIsOver();
        }
        _;
    }

    modifier onlyDuringEnglishPhase() {
        if (!dutchPhaseOver || englishPhaseOver) {
            revert NotInEnglishPhase();
        }
        _;
    }

    constructor(address _nft, uint256 _nftId, uint256 _startPrice, uint256 _endPrice) {
        nft = IERC721(_nft);
        nftId = _nftId;
        seller = payable(msg.sender);
        startPrice = _startPrice;
        endPrice = _endPrice;
        currentAuctionType = AuctionType.Dutch;
    }

    function start() external {
        if (msg.sender != seller) {
            revert YouAreNotTheSeller();
        }

        dutchEndAt = block.timestamp + duration;
        nft.transferFrom(seller, address(this), nftId);

        emit AuctionStarted(seller, nftId, startPrice, endPrice, dutchEndAt);
    }

    function getCurrentPrice() public view returns (uint256) {
        uint256 elapsed;
        uint256 currentPrice;

        if (dutchEndAt == 0) {
            return startPrice;
        } else if (!dutchPhaseOver && block.timestamp < dutchEndAt) {
            elapsed = block.timestamp - (dutchEndAt - duration);
            currentPrice = startPrice - ((startPrice - endPrice) * elapsed / duration);
        } else if (!dutchPhaseOver && block.timestamp > dutchEndAt) {
            currentPrice = endPrice;
        } else if (dutchPhaseOver) {
            currentPrice = highestBid;
        }

        return currentPrice;
    }

    function buy() external payable onlyDuringDutchPhase {
        if (msg.value < getCurrentPrice()) {
            revert InsufficientFunds(
                "Insufficient funds. Please check the current price with getCurrentPrice() function."
            );
        }

        dutchPhaseOver = true;
        highestBidder = msg.sender;
        highestBid = msg.value;
        bids[msg.sender] += msg.value;

        if (block.timestamp < dutchEndAt) {
            englishEndAt = block.timestamp + 3 days; // If dutch auction didn't end, English Auction duration is 3 days
        } else {
            englishEndAt = block.timestamp + 1 days; // If dutch auction ended, English Auction duration is 1 day
        }

        currentAuctionType = AuctionType.English;
    }

    function bid() external payable onlyDuringEnglishPhase {
        if (msg.value < highestBid) {
            revert BidNotHighEnough("Value is not higher than highest bid.");
        }

        bids[msg.sender] += msg.value;
        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function getBids(address bidder) external view returns (uint256) {
        return bids[bidder];
    }

    function bidderWithdraw() external {
        if (msg.sender == highestBidder) {
            revert HighestBidderCantWithdraw();
        }

        uint256 bal = bids[msg.sender];
        bids[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{value: bal}("");
        require(success, "Transfer failed");

        emit BidderWithdraw(msg.sender, bal);
    }

    function endAuction() external onlyDuringEnglishPhase {
        if (block.timestamp <= englishEndAt) {
            revert AuctionNotEnded();
        }

        englishPhaseOver = true;
        if (highestBidder != address(0)) {
            nft.transferFrom(address(this), highestBidder, nftId);
        }

        emit AuctionEnded(highestBidder, highestBid, nftId);
    }

    function endAuctionIfNotSold() external {
        if (block.timestamp > dutchEndAt && highestBidder == address(0) && msg.sender == seller) {
            nft.transferFrom(address(this), seller, nftId);
        } else {
            revert();
        }

        emit AuctionEnded(seller, highestBid, nftId);
    }

    function sellerWithdraw() external {
        if (msg.sender != seller) {
            revert YouAreNotTheSeller();
        }

        if (block.timestamp <= englishEndAt || !englishPhaseOver) {
            revert AuctionNotEnded();
        }

        (bool success,) = seller.call{value: highestBid}("");
        require(success, "Transfer failed");

        emit SellerWithdraw(seller, highestBid);
    }
}
