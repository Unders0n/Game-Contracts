pragma solidity ^0.4.23;


import "./MonsterMinting.sol";


/// @title MonsterBit: Collectible, breedable, and monsters on the Ethereum blockchain.
/// @dev The main MonsterBit contract, keeps track of monsters so they don't wander around and get lost.
contract MonsterCore is MonsterMinting {

    // This is the main MonsterBit contract. In order to keep our code seperated into logical sections,
    // we've broken it up in two ways. First, we have several seperately-instantiated sibling contracts
    // that handle auctions and our super-top-secret genetic combination algorithm. The auctions are
    // seperate since their logic is somewhat complex and there's always a risk of subtle bugs. By keeping
    // them in their own contracts, we can upgrade them without disrupting the main contract that tracks
    // monster ownership. The genetic combination algorithm is kept seperate so we can open-source all of
    // the rest of our code without making it _too_ easy for folks to figure out how the genetics work.
    // Don't worry, I'm sure someone will reverse engineer it soon enough!
    //
    // Secondly, we break the core contract into multiple files using inheritence, one for each major
    // facet of functionality of CK. This allows us to keep related code bundled together while still
    // avoiding a single giant file with everything in it. The breakdown is as follows:
    //
    //      - MonsterBase: This is where we define the most fundamental code shared throughout the core
    //             functionality. This includes our main data storage, constants and data types, plus
    //             internal functions for managing these items.
    //
    //      - MonsterAccessControl: This contract manages the various addresses and constraints for operations
    //             that can be executed only by specific roles. Namely CEO, CFO and COO.
    //
    //      - MonsterOwnership: This provides the methods required for basic non-fungible token
    //             transactions, following the draft ERC-721 spec (https://github.com/ethereum/EIPs/issues/721).
    //
    //      - MonsterBreeding: This file contains the methods necessary to breed monsters together, including
    //             keeping track of siring offers, and relies on an external genetic combination contract.
    //
    //      - MonsterAuctions: Here we have the public methods for auctioning or bidding on monsters or siring
    //             services. The actual auction functionality is handled in two sibling contracts (one
    //             for sales and one for siring), while auction creation and bidding is mostly mediated
    //             through this facet of the core contract.
    //
    //      - MonsterMinting: This final facet contains the functionality we use for creating new gen0 monsters.
    //             We can make up to 5000 "promo" monsters that can be given away (especially important when
    //             the community is new), and all others can only be created and then immediately put up
    //             for auction via an algorithmically determined starting price. Regardless of how they
    //             are created, there is a hard limit of 50k gen0 monsters. After that, it's all up to the
    //             community to breed, breed, breed!

    // Set in case the core contract is broken and an upgrade is required
    address public newContractAddress;

    /// @notice Creates the main MonsterBit smart contract instance.
    constructor() public {
        // Starts paused.
        paused = true;

        // the creator of the contract is the initial CEO
        ceoAddress = msg.sender;

        // the creator of the contract is also the initial COO
        cooAddress = msg.sender;

        // start with the mythical monster 0 - so we don't have generation-0 parent issues
        _createMonster(0, 0, 0, uint256(-1), 0, 0, address(0));
    }

    /// @dev Used to mark the smart contract as upgraded, in case there is a serious
    ///  breaking bug. This method does nothing but keep track of the new contract and
    ///  emit a message indicating that the new address is set. It's up to clients of this
    ///  contract to update to the new contract address in that case. (This contract will
    ///  be paused indefinitely if such an upgrade takes place.)
    /// @param _v2Address new address
    function setNewAddress(address _v2Address) external onlyCEO whenPaused {
        // See README.md for updgrade plan
        newContractAddress = _v2Address;
        emit ContractUpgrade(_v2Address);
    }

    /// @notice No tipping!
    /// @dev Reject all Ether from being sent here, unless it's from one of the
    ///  two auction contracts. (Hopefully, we can prevent user accidents.)
    function() external payable {
        require(
            msg.sender == address(saleAuction)
            ||
            msg.sender == address(siringAuction)
            ||
            msg.sender == address(battlesContract)
        );
    }

    /// @notice Returns all the relevant information about a specific monster.
    /// @param _id The ID of the monster of interest.
    function getMonster(uint256 _id)
        external
        view
        returns (
        uint256 birthTime,
        uint256 generation,
        uint256 genes,
        uint256 battleGenes,
        uint256 cooldownIndex,
        uint256 cooldownEndTimestamp,
        uint256 matronId,
        uint256 sireId,
        uint256 siringWithId,
        uint256 growScore,
        uint256 level,
        uint256 potionId,
        uint256 potionExpire
        
    ) {
        Monster storage mon = monsters[_id];

        birthTime = mon.birthTime;
        generation = mon.generation;
        genes = mon.genes;
        cooldownEndTimestamp = mon.cooldownEndTimestamp;
        matronId = mon.matronId;
        sireId = mon.sireId;
        siringWithId = mon.siringWithId;
        cooldownIndex = mon.cooldownIndex;
        battleGenes = mon.battleGenes;
        growScore = mon.growScore;
        level = mon.level;
        potionId = mon.potionId;
        potionExpire = mon.potionExpire;
    }

    /// @dev Override unpause so it requires all external contract addresses
    ///  to be set before contract can be unpaused. Also, we can't have
    ///  newContractAddress set either, because then the contract was upgraded.
    /// @notice This is public rather than external so we can call super.unpause
    ///  without using an expensive CALL.
    function unpause() public onlyCEO whenPaused {
        require(saleAuction != address(0));
        require(siringAuction != address(0));
        require(monsterFood != address(0));
        require(battlesContract != address(0));
        require(geneScience != address(0));
        require(newContractAddress == address(0));

        // Actually unpause the contract.
        super.unpause();
    }

    // @dev Allows the CFO to capture the balance available to the contract.
    function withdrawBalance() external onlyCFO {
        uint256 balance = address(this).balance;
        cfoAddress.transfer(balance);
    }
    
    /// @dev Transfers the balance of the sale auction contract
    /// to the MonsterCore contract. We use two-step withdrawal to
    /// prevent two transfer calls in the auction bid function.
    function withdrawDependentBalances() external onlyCLevel {
        saleAuction.withdrawBalance();
        siringAuction.withdrawBalance();
        battlesContract.withdrawBalance();
        monsterFood.withdrawBalance();
    }
}




