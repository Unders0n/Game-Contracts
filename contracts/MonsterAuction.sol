pragma solidity ^0.4.23;

import "./MonsterFighting.sol";

/// @title Handles creating auctions for sale and siring of monsters.
///  This wrapper of ReverseAuction exists only so that users can create
///  auctions with only one transaction.
contract MonsterAuction is MonsterFeeding {

    // @notice The auction contract variables are defined in MonsterBase to allow
    //  us to refer to them in MonsterOwnership to prevent accidental transfers.
    // `saleAuction` refers to the auction for gen0 and p2p sale of monsters.
    // `siringAuction` refers to the auction for siring rights of monsters.

    /// @dev Sets the reference to the sale auction.
    /// @param _address - Address of sale contract.
    function setSaleAuctionAddress(address _address) external onlyCEO {
        SaleClockAuction candidateContract = SaleClockAuction(_address);

        // NOTE: verify that a contract is what we expect - https://github.com/Lunyr/crowdsale-contracts/blob/cfadd15986c30521d8ba7d5b6f57b4fefcc7ac38/contracts/LunyrToken.sol#L117
        require(candidateContract.isSaleClockAuction());

        // Set the new contract address
        saleAuction = candidateContract;
    }


    /// @dev Put a monster up for auction.
    ///  Does some ownership trickery to create auctions in one tx.
    function createSaleAuction(
        uint256 _monsterId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration
    )
        external
        whenNotPaused
    {
        // Auction contract checks input sizes
        // If monster is already on any auction, this will throw
        // because it will be owned by the auction contract.
        require(_owns(msg.sender, _monsterId));
        // Ensure the monster is not pregnant to prevent the auction
        // contract accidentally receiving ownership of the child.
        // NOTE: the monster IS allowed to be in a cooldown.
        _approve(_monsterId, saleAuction);
        // Sale auction throws if inputs are invalid and clears
        // transfer and sire approval after escrowing the monster.
        saleAuction.createAuction(
            _monsterId,
            _startingPrice,
            _endingPrice,
            _duration,
            msg.sender
        );
    }
    
    /// @dev Put a monster up for auction to be sire.
    ///  Performs checks to ensure the monster can be sired, then
    ///  delegates to reverse auction.
    function createSiringAuction(
        uint256 _monsterId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration
    )
        external
        whenNotPaused
    {
        // Auction contract checks input sizes
        // If monster is already on any auction, this will throw
        // because it will be owned by the auction contract.
        require(_owns(msg.sender, _monsterId));
        require(isReadyToBreed(_monsterId));
        _approve(_monsterId, siringAuction);
        // Siring auction throws if inputs are invalid and clears
        // transfer and sire approval after escrowing the kitty.
        siringAuction.createAuction(
            _monsterId,
            _startingPrice,
            _endingPrice,
            _duration,
            msg.sender
        );
    }
    
    /// @dev Completes a siring auction by bidding.
    ///  Immediately breeds the winning matron with the sire on auction.
    /// @param _sireId - ID of the sire on auction.
    /// @param _matronId - ID of the matron owned by the bidder.
    function bidOnSiringAuction(
        uint256 _sireId,
        uint256 _matronId
    )
        external
        payable
        whenNotPaused
    {
        // Auction contract checks input sizes
        require(_owns(msg.sender, _matronId));
        require(isReadyToBreed(_matronId));
        require(_canBreedWithViaAuction(_matronId, _sireId));

        // Define the current price of the auction.
        uint256 currentPrice = siringAuction.getCurrentPrice(_sireId);
        require(msg.value >= currentPrice + autoBirthFee);

        // Siring auction will throw if the bid fails.
        siringAuction.bid.value(msg.value - autoBirthFee)(_sireId);
        _breedWith(uint32(_matronId), uint32(_sireId));
    }


    
}