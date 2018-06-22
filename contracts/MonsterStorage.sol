pragma solidity ^0.4.23;


import "./MonsterLib.sol";
import "./Pausable.sol";
import "./ERC721.sol";

contract MonsterStorage is Ownable
{
    ERC721 public nonFungibleContract;
    constructor(address _nftAddress) public
    {
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
    }
    
    function setTokenContract(address _nftAddress) external onlyOwner
    {
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
    }
    
    modifier onlyCore() {
        require(msg.sender == address(nonFungibleContract));
        _;
    }
    
    /*** STORAGE ***/

    /// @dev An array containing the Monster struct for all Monsters in existence. The ID
    ///  of each monster is actually an index into this array. Note that ID 0 is a negamonster,
    ///  the unMonster, the mythical beast that is the parent of all gen0 monsters. A bizarre
    ///  creature that is both matron and sire... to itself! Has an invalid genetic code.
    ///  In other words, monster ID 0 is invalid... ;-)
    MonsterLib.Monster[] monsters;
    
    uint256 public pregnantMonsters;
    
    function setPregnantMonsters(uint newValue) onlyCore public
    {
        pregnantMonsters = newValue;
    }
    
    function getMonstersCount() public view returns(uint) 
    {
        return monsters.length;
    }
    
    
    /// @dev A mapping from monster IDs to the address that owns them. All monsters have
    ///  some valid owner address, even gen0 monsters are created with a non-zero owner.
    mapping (uint256 => address) public monsterIndexToOwner;
    
    function setMonsterIndexToOwner(uint index, address owner) onlyCore public
    {
        monsterIndexToOwner[index] = owner;
    }

    // @dev A mapping from owner address to count of tokens that address owns.
    //  Used internally inside balanceOf() to resolve ownership count.
    mapping (address => uint256) public ownershipTokenCount;
    
    function setOwnershipTokenCount(address owner, uint count) onlyCore public
    {
        ownershipTokenCount[owner] = count;
    }

    /// @dev A mapping from MonsterIDs to an address that has been approved to call
    ///  transferFrom(). Each Monster can only have one approved address for transfer
    ///  at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public monsterIndexToApproved;
    
    function setMonsterIndexToApproved(uint index, address approved) onlyCore public
    {
        if(approved == address(0))
        {
            delete monsterIndexToApproved[index];
        }
        else
        {
            monsterIndexToApproved[index] = approved;
        }
    }
    
    /// @dev A mapping from MonsterIDs to an address that has been approved to use
    ///  this monster for siring via breedWith(). Each monster can only have one approved
    ///  address for siring at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public sireAllowedToAddress;
    
    function setSireAllowedToAddress(uint index, address allowed) onlyCore public
    {
        if(allowed == address(0))
        {
            delete sireAllowedToAddress[index];
        }
        else 
        {
            sireAllowedToAddress[index] = allowed;
        }
    }
    
    /// @dev An internal method that creates a new monster and stores it. This
    ///  method doesn't do any checking and should only be called when the
    ///  input data is known to be valid. Will generate both a Birth event
    ///  and a Transfer event.
    /// @param _generation The generation number of this monster, must be computed by caller.
    /// @param _genes The monster's genetic code.
    
    function createMonster(
        uint256 _matronId,
        uint256 _sireId,
        uint256 _generation,
        uint256 _genes,
        uint256 _battleGenes,
        uint256 _level
    )
        onlyCore
        public
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

        MonsterLib.Monster memory _monster = MonsterLib.Monster({
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
            potionEffect: 0,
            potionExpire: 0,
            foodCooldownEndTimestamp: 0,
            battleCounter: 0
        });
        uint256 newMonsterId = monsters.push(_monster) - 1;

        // It's probably never going to happen, 4 billion monsters is A LOT, but
        // let's just be 100% sure we never let this happen.
        require(newMonsterId == uint256(uint32(newMonsterId)));

        return newMonsterId;
    }
    
    function setActionCooldown(uint monsterId, uint cooldownIndex, uint actionCooldown) onlyCore public
    {
        MonsterLib.Monster storage mon = monsters[monsterId];
        mon.cooldownIndex = uint16(cooldownIndex);
        mon.cooldownEndTimestamp = uint64(actionCooldown);
    }
    
    function setSiringWith(uint monsterId, uint siringWithId) onlyCore public
    {
        MonsterLib.Monster storage mon = monsters[monsterId];
        if(siringWithId == 0)
        {
            delete mon.siringWithId;
        }
        else
        {
            mon.siringWithId = uint32(siringWithId);
        }
    }
    
    function setMonster(
        uint256 _id,
        uint256 birthTime,
        uint256 generation,
        uint256 genes,
        uint256 battleGenes,
        uint256 cooldownIndex,
        uint256 matronId,
        uint256 sireId,
        uint256 siringWithId,
        uint256 growScore,
        uint256 level,
        uint256 potionEffect,
        uint256 cooldowns
        ) onlyCore public
    {
            MonsterLib.Monster storage mon = monsters[_id];
            mon.birthTime = uint64(birthTime);
            mon.generation = uint16(generation);
            mon.genes = genes;
            mon.battleGenes = uint64(battleGenes);
            mon.cooldownIndex = uint16(cooldownIndex);
            mon.matronId = uint32(matronId);
            mon.sireId = uint32(sireId);
            mon.siringWithId = uint32(siringWithId);
            mon.growScore = uint16(growScore);
            mon.level = uint8(level);
            mon.potionEffect = uint8(potionEffect);
            (mon.cooldownEndTimestamp, mon.potionExpire, mon.foodCooldownEndTimestamp, mon.battleCounter) = MonsterLib.unmixCooldowns(cooldowns);
    }
    
    function getMonsterBits(uint monsterId) public view returns(uint p1, uint p2, uint p3)
    {
        MonsterLib.Monster storage mon = monsters[monsterId];
        (p1, p2, p3) = MonsterLib.encodeMonsterBits(mon);
    }
    
    function setMonsterBits(uint monsterId, uint p1, uint p2, uint p3) onlyCore public
    {
        MonsterLib.Monster storage mon = monsters[monsterId];
        MonsterLib.Monster memory mon2 = MonsterLib.decodeMonsterBits(p1, p2, p3);
        mon.birthTime = mon2.birthTime;
        mon.generation = mon2.generation;
        mon.genes = mon2.genes;
        mon.battleGenes = mon2.battleGenes;
        mon.cooldownIndex = mon2.cooldownIndex;
        mon.matronId = mon2.matronId;
        mon.sireId = mon2.sireId;
        mon.siringWithId = mon2.siringWithId;
        mon.growScore = mon2.growScore;
        mon.level = mon2.level;
        mon.potionEffect = mon2.potionEffect;
        mon.cooldownEndTimestamp = mon2.cooldownEndTimestamp;
        mon.potionExpire = mon2.potionExpire;
        mon.foodCooldownEndTimestamp = mon2.foodCooldownEndTimestamp;
        mon.battleCounter = mon2.battleCounter;
        
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
        uint256 matronId,
        uint256 sireId,
        uint256 siringWithId,
        uint256 growScore,
        uint256 level,
        uint256 potionEffect,
        uint256 cooldowns
        
    ) {
        MonsterLib.Monster storage mon = monsters[_id];

        birthTime = mon.birthTime;
        generation = mon.generation;
        genes = mon.genes;
        matronId = mon.matronId;
        sireId = mon.sireId;
        siringWithId = mon.siringWithId;
        cooldownIndex = mon.cooldownIndex;
        battleGenes = mon.battleGenes;
        growScore = mon.growScore;
        level = mon.level;
        potionEffect = mon.potionEffect;
        
        //uint cooldownEndTimestamp, uint foodCooldownEndTimestamp, uint potionExpire, uint battleCounter
        cooldowns = MonsterLib.mixCooldowns(mon.cooldownEndTimestamp, mon.foodCooldownEndTimestamp, mon.potionExpire, mon.battleCounter);
    }
}