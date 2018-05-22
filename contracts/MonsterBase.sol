pragma solidity ^0.4.23;

import "./MonsterAccessControl.sol";
import "./MonsterBitSaleAuction.sol";
import "./MonsterBattles.sol";
import "./MonsterFood.sol";
import "./MonsterGeneticsInterface.sol";

/// @title Base contract for MonsterBit. Holds all common structs, events and base variables.
/// @dev See the MonsterCore contract documentation to understand how the various contract facets are arranged.
contract MonsterBase is MonsterAccessControl {
    /*** EVENTS ***/

    /// @dev The Birth event is fired whenever a new monster comes into existence. This obviously
    ///  includes any time a monster is created through the giveBirth method, but it is also called
    ///  when a new gen0 monster is created.
    event Birth(address owner, uint256 monsterId, uint256 genes);

    /// @dev Transfer event as defined in current draft of ERC721. Emitted every time a monster
    ///  ownership is assigned, including births.
    event Transfer(address from, address to, uint256 tokenId);

    /*** DATA TYPES ***/

    /// @dev The main Monster struct. Every monster in MonsterBit is represented by a copy
    ///  of this structure, so great care was taken to ensure that it fits neatly into
    ///  exactly two 256-bit words. Note that the order of the members in this structure
    ///  is important because of the byte-packing rules used by Ethereum.
    ///  Ref: http://solidity.readthedocs.io/en/develop/miscellaneous.html
    struct Monster {
        // The Monster's genetic code is packed into these 256-bits, the format is
        // sooper-sekret! A monster's genes never change.
        uint256 genes;
        
        // The timestamp from the block when this monster came into existence.
        uint64 birthTime;
        
        // The "generation number" of this monster. Monsters minted by the CK contract
        // for sale are called "gen0" and have a generation number of 0. The
        // generation number of all other monsters is the larger of the two generation
        // numbers of their parents, plus one.
        // (i.e. max(matron.generation, sire.generation) + 1)
        uint16 generation;
        
        // The minimum timestamp after which this monster can engage in breeding
        // activities again. This same timestamp is used for the pregnancy
        // timer (for matrons) as well as the siring cooldown.
        uint64 cooldownEndTimestamp;
        
        // The ID of the parents of this monster, set to 0 for gen0 monsters.
        // Note that using 32-bit unsigned integers limits us to a "mere"
        // 4 billion monsters. This number might seem small until you realize
        // that Ethereum currently has a limit of about 500 million
        // transactions per year! So, this definitely won't be a problem
        // for several years (even as Ethereum learns to scale).
        uint32 matronId;
        uint32 sireId;
        
        // Set to the ID of the sire monster for matrons that are pregnant,
        // zero otherwise. A non-zero value here is how we know a monster
        // is pregnant. Used to retrieve the genetic material for the new
        // monster when the birth transpires.
        uint32 siringWithId;
        
        // Set to the index in the cooldown array (see below) that represents
        // the current cooldown duration for this monster. This starts at zero
        // for gen0 cats, and is initialized to floor(generation/2) for others.
        // Incremented by one for each successful breeding action, regardless
        // of whether this monster is acting as matron or sire.
        uint16 cooldownIndex;
        
        // Monster genetic code for battle attributes
        uint64 battleGenes;
        
        uint16 growScore;
        uint8 level;
        
        uint8 potionId;
        uint64 potionExpire;
        
        uint64 foodCooldownEndTimestamp;
    }
    
    /// @dev A lookup table indicating the cooldown duration after any successful
    ///  breeding action, called "pregnancy time" for matrons and "siring cooldown"
    ///  for sires. Designed such that the cooldown roughly doubles each time a monster
    ///  is bred, encouraging owners not to just keep breeding the same monster over
    ///  and over again. Caps out at one week (a cat monster breed an unbounded number
    ///  of times, and the maximum cooldown is always seven days).
    uint32[14] public cooldowns = [
        uint32(1 minutes),
        uint32(2 minutes),
        uint32(5 minutes),
        uint32(10 minutes),
        uint32(30 minutes),
        uint32(1 hours),
        uint32(2 hours),
        uint32(4 hours),
        uint32(8 hours),
        uint32(16 hours),
        uint32(1 days),
        uint32(2 days),
        uint32(4 days),
        uint32(7 days)
    ];
    
    uint32[2] public levelScores = [100, 100];

    /*** STORAGE ***/

    /// @dev An array containing the Monster struct for all Monsters in existence. The ID
    ///  of each monster is actually an index into this array. Note that ID 0 is a negamonster,
    ///  the unMonster, the mythical beast that is the parent of all gen0 monsters. A bizarre
    ///  creature that is both matron and sire... to itself! Has an invalid genetic code.
    ///  In other words, monster ID 0 is invalid... ;-)
    Monster[] monsters;

    /// @dev A mapping from monster IDs to the address that owns them. All monsters have
    ///  some valid owner address, even gen0 monsters are created with a non-zero owner.
    mapping (uint256 => address) public monsterIndexToOwner;

    // @dev A mapping from owner address to count of tokens that address owns.
    //  Used internally inside balanceOf() to resolve ownership count.
    mapping (address => uint256) ownershipTokenCount;

    /// @dev A mapping from MonsterIDs to an address that has been approved to call
    ///  transferFrom(). Each Monster can only have one approved address for transfer
    ///  at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public monsterIndexToApproved;
    
    /// @dev A mapping from MonsterIDs to an address that has been approved to use
    ///  this monster for siring via breedWith(). Each monster can only have one approved
    ///  address for siring at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public sireAllowedToAddress;

    /// @dev The address of the ClockAuction contract that handles sales of Monsters. This
    ///  same contract handles both peer-to-peer sales as well as the gen0 sales which are
    ///  initiated every 15 minutes.
    SaleClockAuction public saleAuction;
    SiringClockAuction public siringAuction;
    MonsterBattles public battlesContract;
    MonsterFood public monsterFood;
    
    /// @dev The address of the sibling contract that is used to implement the sooper-sekret
    ///  genetic combination algorithm.
    MonsterGeneticsInterface public geneScience;


    /// @dev Assigns ownership of a specific Monster to an address.
    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        // Since the number of monsters is capped to 2^32 we can't overflow this
        ownershipTokenCount[_to]++;
        // transfer ownership
        monsterIndexToOwner[_tokenId] = _to;
        // When creating new monsters _from is 0x0, but we can't account that address.
        if (_from != address(0)) {
            ownershipTokenCount[_from]--;
            // clear any previously approved ownership exchange
            delete monsterIndexToApproved[_tokenId];
        }
        // Emit the transfer event.
        emit Transfer(_from, _to, _tokenId);
    }

    /// @dev An internal method that creates a new monster and stores it. This
    ///  method doesn't do any checking and should only be called when the
    ///  input data is known to be valid. Will generate both a Birth event
    ///  and a Transfer event.
    /// @param _generation The generation number of this monster, must be computed by caller.
    /// @param _genes The monster's genetic code.
    /// @param _owner The inital owner of this monster, must be non-zero (except for the unMonster, ID 0)
    function _createMonster(
        uint256 _matronId,
        uint256 _sireId,
        uint256 _generation,
        uint256 _genes,
        uint256 _battleGenes,
        uint256 _level,
        address _owner
    )
        internal
        returns (uint)
    {
        // These requires are not strictly necessary, our calling code should make
        // sure that these conditions are never broken. However! _createMonster() is already
        // an expensive call (for storage), and it doesn't hurt to be especially careful
        // to ensure our data structures are always valid.
        
        require(_matronId == uint256(uint32(_matronId)));
        require(_sireId == uint256(uint32(_sireId)));
        require(_generation == uint256(uint16(_generation)));

        // New monster starts with the same cooldown as parent gen/2
        uint16 cooldownIndex = uint16(_generation / 2);
        if (cooldownIndex > 13) {
            cooldownIndex = 13;
        }

        Monster memory _monster = Monster({
            genes: _genes,
            birthTime: uint64(now),
            cooldownEndTimestamp: 0,
            matronId: uint32(_matronId),
            sireId: uint32(_sireId),
            siringWithId: 0,
            cooldownIndex: cooldownIndex,
            generation: uint16(_generation),
            battleGenes: uint64(_battleGenes),
            level: uint8(_level),
            growScore: 0,
            potionId: 0,
            potionExpire: 0,
            foodCooldownEndTimestamp: 0
        });
        uint256 newMonsterId = monsters.push(_monster) - 1;

        // It's probably never going to happen, 4 billion monsters is A LOT, but
        // let's just be 100% sure we never let this happen.
        require(newMonsterId == uint256(uint32(newMonsterId)));

        // emit the birth event
        emit Birth(
            _owner,
            newMonsterId,
            _monster.genes
        );

        // This will assign ownership, and also emit the Transfer event as
        // per ERC721 draft
        _transfer(0, _owner, newMonsterId);

        return newMonsterId;
    }

}