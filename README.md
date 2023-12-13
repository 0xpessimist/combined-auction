# Combined Auction

Smart contract implementing a combined auction mechanism switching from Dutch to English Auction, providing more flexibility. It allows users to auction their non-fungible tokens (NFTs) in a more flexible way than traditional Dutch Auction.

## Overview

This contract features (and combines) two types of auctions:
- **Dutch Auction**: Initially, the price starts high and decreases until a bidder accepts the price or the auction ends.
- **English Auction**: If a bidder accepts the price during Dutch Auction, an English auction begins with assigning the accepted price in Dutch Auction as the highest bid. Participants can place bids higher than the current highest bid until the auction concludes.

- Seller of NFT deploys this contract.
- Auction lasts for 7 days.
- Participants can bid by depositing ETH greater than the current highest bidder.
- All bidders can withdraw their bid if it is not the current highest bid.

## Usage

1. **Deployment**: Deploy the contract with specifying the NFT's address, NFT ID, Starting Price, Last Price. Starting and Last Prices are for the Dutch Auction phase and the NFT owner must approve their token for the contract before calling `start()` function.
2. **Start Auction**: Use the `start()` function to commence the auction.
3. **Bid or Buy**: During the Dutch Auction phase, users can `buy()` the NFT. In the English Auction phase, participants can `bid()` higher than the current highest bid.
4. **Auction End**: Once the auction ends, use `endAuction()` to conclude and transfer the NFT to the winning bidder.
5. **Withdraw Funds**: Bidders can `bidderWithdraw()` their funds if they're not the highest bidder, while the seller can `sellerWithdraw()` after the auction ends.

## Disclaimer

This contract is provided as-is and has not been audited, users are advised to review its functionality, test it extensively and get a security audit service from a reliable party before usage in a production environment.

The main contract containing the Combined Auction mechanism is `CombinedAuction.sol` and the file containing the tests of the auction is `CombinedAuction.t.sol`. For testing the auction with NFTs, `ERC721Token.sol` and `LilOwnable.sol` developed by an awesome purple-haired dev were used. https://github.com/m1guelpf/erc721-drop
