pragma solidity ^0.4.23;

import "./MonsterAuction.sol";
import "./MonsterOwnership.sol";

/// @title all functions related to creating monsters
contract MonsterMinting is MonsterAuction {

    // Limits the number of monsters the contract owner can ever create.
    uint256 public constant PROMO_CREATION_LIMIT = 1000;
    uint256 public constant GEN0_CREATION_LIMIT = 45000;

    uint256 public constant GEN0_STARTING_PRICE = 1 ether;
    uint256 public constant GEN0_ENDING_PRICE = 0.1 ether;
    uint256 public constant GEN0_AUCTION_DURATION = 30 days;


    // Counts the number of monsters the contract owner has created.
    uint256 public promoCreatedCount;
    uint256 public gen0CreatedCount;


    /// @dev we can create promo monsters, up to a limit. Only callable by COO
    /// @param _genes the encoded genes of the monster to be created, any value is accepted
    /// @param _owner the future owner of the created monsters. Default to contract COO
    function createPromoMonster(uint256 _genes, uint256 _battleGenes, uint256 _level, address _owner) external onlyCOO {
        address monsterOwner = _owner;
        if (monsterOwner == address(0)) {
             monsterOwner = cooAddress;
        }
        require(promoCreatedCount < PROMO_CREATION_LIMIT);

        promoCreatedCount++;
        _createMonster(0, 0, 0, _genes, _battleGenes, _level, monsterOwner);
    }
    
    /// @dev Creates a new gen0 monster with the given genes and
    ///  creates an auction for it.
    function createGen0AuctionCustom(uint _genes, uint _battleGenes, uint _level, uint _startingPrice, uint _endingPrice, uint _duration) external onlyCOO {
        require(gen0CreatedCount < GEN0_CREATION_LIMIT);

        uint256 monsterId = _createMonster(0, 0, 0, _genes, _battleGenes, _level, address(this));
        _approve(monsterId, saleAuction);

        saleAuction.createAuction(
            monsterId,
            _startingPrice,
            _endingPrice,
            _duration,
            address(this)
        );

        gen0CreatedCount++;
    }

    /// @dev Creates a new gen0 monster with the given genes and
    ///  creates an auction for it.
    function createGen0Auction(uint256 _genes, uint256 _battleGenes) external onlyCOO {
        require(gen0CreatedCount < GEN0_CREATION_LIMIT);

        uint256 monsterId = _createMonster(0, 0, 0, _genes, _battleGenes, 2, address(this));
        _approve(monsterId, saleAuction);

        saleAuction.createAuction(
            monsterId,
            GEN0_STARTING_PRICE,
            GEN0_ENDING_PRICE,
            GEN0_AUCTION_DURATION,
            address(this)
        );

        gen0CreatedCount++;
    }

   
}