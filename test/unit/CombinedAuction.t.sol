// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CombinedAuction} from "../../src/CombinedAuction.sol";
import {ERC721Token} from "../../src/ERC721Token.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract CombinedAuctionTest is Test {
    CombinedAuction public ca;
    ERC721Token public token;
    address alice = vm.addr(1);
    address bob = vm.addr(2);

    function setUp() public {
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        token = new ERC721Token(
            "Ronaldo NFT", "RNLDNFT", "https://i.pinimg.com/564x/10/97/a6/1097a670e6e5c2f2e180538576070e9a.jpg"
        );
        uint256 tokenPrice = token.PRICE_PER_MINT();
        token.mint{value: tokenPrice * 3}(3);
        ca = new CombinedAuction(address(token), 0, 3 ether, 1 ether);
        token.approve(address(ca), 0);
        ca.start();
    }

    function test_getCurrentPrice() public {
        skip(1 days);
        console2.log("Current Price: ", ca.getCurrentPrice());
        assertEq(ca.getCurrentPrice(), 2714285714285714286); //2714285714285714286 wei is 2.71 ether
    }

    function test_getCurrentPriceAfterDutchEnds() public {
        console2.log("Current Price: ", ca.getCurrentPrice());
        skip(8 days);
        console2.log("Current Price: ", ca.getCurrentPrice());
        assertEq(ca.getCurrentPrice(), 1 ether);
    }

    function test_Buy() public {
        vm.prank(alice);
        skip(1 days);
        ca.buy{value: 2714285714285714287}();
        assertEq(ca.dutchPhaseOver(), true);
        assertEq(ca.highestBidder(), alice);
        assertEq(ca.highestBid(), 2714285714285714287);
        assertEq(ca.englishEndAt(), block.timestamp + 3 days);
    }

    function test_Bid() public {
        vm.prank(alice);
        ca.buy{value: 3 ether}();
        assertEq(ca.dutchPhaseOver(), true);
        assertEq(ca.highestBidder(), alice);
        vm.prank(bob);
        ca.bid{value: 4 ether}();
        assertEq(ca.highestBidder(), bob);
        assertEq(ca.highestBid(), 4 ether);
        assertEq(ca.englishEndAt(), block.timestamp + 3 days);
    }

    function test_NFTandNFTId() public {
        console2.log("NFT: ", address(ca.nft()));
        console2.log("NFT ID: ", ca.nftId());
        assertEq(address(ca.nft()), address(token));
        assertEq(ca.nftId(), 0);
    }

    function test_EndAuction() public {
        vm.prank(alice);
        ca.buy{value: 3 ether}();
        assertEq(ca.dutchPhaseOver(), true);
        assertEq(ca.highestBidder(), alice);
        vm.prank(bob);
        ca.bid{value: 4 ether}();
        assertEq(ca.highestBidder(), bob);
        assertEq(ca.highestBid(), 4 ether);
        assertEq(ca.englishEndAt(), block.timestamp + 3 days);
        skip(4 days);
        ca.endAuction();
        assertEq(ca.englishPhaseOver(), true);
        assertEq(ca.highestBidder(), bob);
        assertEq(ca.highestBid(), 4 ether);
        assertEq(token.ownerOf(0), bob);
        skip(1 days);
        vm.prank(alice);
        ca.bidderWithdraw();
        console2.log("Bob balance", bob.balance);
        console2.log("Contract balance", address(ca).balance);
    }

    function test_GetBids() public {
        vm.startPrank(alice);
        ca.buy{value: 3 ether}();
        assertEq(ca.dutchPhaseOver(), true);
        assertEq(ca.highestBidder(), alice);
        assertEq(ca.highestBid(), 3 ether);
        console2.log("Alice's bid: ", ca.getBids(alice));
        vm.stopPrank();
    }

    function test_FullScenario() public {
        vm.prank(alice);
        ca.buy{value: 3 ether}();
        assertEq(ca.dutchPhaseOver(), true);
        assertEq(ca.highestBidder(), alice);
        vm.startPrank(bob);
        ca.bid{value: 4 ether}();
        assertEq(ca.highestBidder(), bob);
        assertEq(ca.highestBid(), 4 ether);
        assertEq(ca.englishEndAt(), block.timestamp + 3 days);
        skip(4 days);
        ca.endAuction();
        assertEq(ca.englishPhaseOver(), true);
        assertEq(ca.highestBidder(), bob);
        assertEq(ca.highestBid(), 4 ether);
        assertEq(token.ownerOf(0), bob);
        skip(1 days);
        vm.stopPrank();
        vm.prank(alice);
        ca.bidderWithdraw();
        vm.prank(address(this));
        ca.sellerWithdraw();
        console2.log("Alice balance", alice.balance);
        console2.log("Bob balance", bob.balance);
        console2.log("Contract balance", address(ca).balance);
        console2.log("Seller balance ()", address(this).balance);
    }

    function test_EndAuctionIfNotSold() public {
        skip(8 days);
        ca.endAuctionIfNotSold();
        assertEq(token.ownerOf(0), address(this));
    }

    function test_SellerWithdrawAfterAuctionIsOver() public {
        vm.prank(alice);
        ca.buy{value: 3 ether}();
        skip(4 days);
        ca.endAuction();
        ca.sellerWithdraw();
    }

    function test_OwnerOf() public {
        vm.prank(alice);
        ca.buy{value: 3 ether}();
        skip(4 days);
        ca.endAuction();
        assertEq(token.ownerOf(0), alice);
    }

    function test_Seller() public {
        assertEq(ca.seller(), address(this));
    }

    function test_StartandEndPrice() public {
        assertEq(ca.startPrice(), 3 ether);
        assertEq(ca.endPrice(), 1 ether);
    }

    function test_GetBidsZeroAddress() public {
        assertEq(ca.getBids(address(0)), 0);
    }

    function test_GetBidsNotBidder() public {
        assertEq(ca.getBids(alice), 0);
        assertEq(ca.getBids(bob), 0);
    }

    function test_StateVariablesDefault() public {
        assertEq(ca.nftId(), 0);
        assertEq(ca.seller(), address(this));
        assertEq(ca.duration(), 7 days);
        assertEq(ca.startPrice(), 3 ether);
        assertEq(ca.endPrice(), 1 ether);
        assertEq(ca.dutchEndAt(), block.timestamp + 7 days);
        assertEq(ca.englishEndAt(), 0);
        assertEq(ca.highestBidder(), address(0));
        assertEq(ca.highestBid(), 0);
        assertEq(ca.dutchPhaseOver(), false);
        assertEq(ca.englishPhaseOver(), false);
    }

    // Fail Cases - These test cases will pass since we used the testFail prefix

    function test_RevertIf_NonSellerCallsStart() public {
        vm.prank(alice);
        vm.expectRevert(CombinedAuction.YouAreNotTheSeller.selector);
        ca.start();
    }

    function test_RevertIf_HighestBidderWithdraws() public {
        vm.startPrank(alice);
        ca.buy{value: 3 ether}();
        assertEq(ca.dutchPhaseOver(), true);
        assertEq(ca.highestBidder(), alice);
        assertEq(ca.highestBid(), 3 ether);
        vm.expectRevert(CombinedAuction.HighestBidderCantWithdraw.selector);
        ca.bidderWithdraw();
        vm.stopPrank();
    }

    function test_RevertIf_NonSellerCallsSellerWithdraw() public {
        vm.startPrank(alice);
        ca.buy{value: 3 ether}();
        skip(4 days);
        ca.endAuction();
        vm.expectRevert(CombinedAuction.YouAreNotTheSeller.selector);
        ca.sellerWithdraw();
        vm.stopPrank();
    }

    function test_RevertIf_SellerWithdrawBeforeAuctionIsOver() public {
        vm.expectRevert(CombinedAuction.AuctionNotEnded.selector);
        ca.sellerWithdraw();
    }

    function test_RevertIf_SellerWithdrawBeforeAuctionIsOver2() public {
        vm.prank(alice);
        ca.buy{value: 3 ether}();
        vm.expectRevert(CombinedAuction.AuctionNotEnded.selector);
        ca.sellerWithdraw();
    }

    function test_RevertIf_EndAuctionIfNotSoldTooEarly() public {
        skip(1 days);
        vm.expectRevert();
        ca.endAuctionIfNotSold();
        assertEq(token.ownerOf(0), address(ca));
    }

    function test_RevertIf_BuyAfterAuctionIsOver() public {
        skip(8 days);
        vm.prank(alice);
        vm.expectRevert(CombinedAuction.AuctionIsOver.selector);
        ca.buy{value: 3 ether}();
    }

    function test_RevertIf_BidAfterAuctionIsOver() public {
        skip(8 days);
        vm.prank(alice);
        vm.expectRevert(CombinedAuction.NotInEnglishPhase.selector);
        ca.bid{value: 4 ether}();
    }

    function test_RevertIf_BidBeforeEnglishPhase() public {
        vm.startPrank(alice);
        vm.expectRevert(CombinedAuction.NotInEnglishPhase.selector);
        ca.bid{value: 4 ether}();
        vm.stopPrank();
    }

    function test_RevertIf_BuyAfterEnglishPhase() public {
        vm.startPrank(alice);
        ca.buy{value: 3 ether}();
        skip(4 days);
        vm.expectRevert(CombinedAuction.DutchPhaseIsOver.selector);
        ca.buy{value: 4 ether}();
        vm.stopPrank();
    }

    function test_RevertIf_BuyWithInsufficientFunds() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                CombinedAuction.InsufficientFunds.selector,
                "Insufficient funds. Please check the current price with getCurrentPrice() function."
            )
        );
        ca.buy{value: 2 ether}();
    }

    function test_RevertIf_BidWithInsufficientFunds() public {
        vm.prank(alice);
        ca.buy{value: 3 ether}();
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(CombinedAuction.BidNotHighEnough.selector, "Value is not higher than highest bid.")
        );
        ca.bid{value: 2 ether}();
    }

    fallback() external payable {
        console2.log("Fallback called");
    }

    receive() external payable {}
}
