pragma solidity ^0.4.23;


import "./MonsterLib.sol";
import "./Pausable.sol";
import "./ERC721.sol";

contract MonsterStorage is Ownable
{
    ERC721 public nonFungibleContract;
    
    bool public isMonsterStorage = true;
    
    constructor(address _nftAddress) public
    {
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
        MonsterLib.Monster memory mon = MonsterLib.decodeMonsterBits(uint(-1), 0, 0);
        _createMonster(mon);
        monsterIndexToOwner[0] = address(0);
    }
    
    function setTokenContract(address _nftAddress) external onlyOwner
    {
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
    }
    
    modifier onlyCore() {
        require(msg.sender != address(0) && msg.sender == address(nonFungibleContract));
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

    function createMonster(uint p1, uint p2, uint p3)
        onlyCore
        public
        returns (uint)
    {

        MonsterLib.Monster memory mon = MonsterLib.decodeMonsterBits(p1, p2, p3);


        uint256 newMonsterId = _createMonster(mon);

        // It's probably never going to happen, 4 billion monsters is A LOT, but
        // let's just be 100% sure we never let this happen.
        require(newMonsterId == uint256(uint32(newMonsterId)));

        return newMonsterId;
    }
    
    function _createMonster(MonsterLib.Monster mon) internal returns(uint)
    {
        uint256 newMonsterId = monsters.push(mon) - 1;
        
        return newMonsterId;
    }
    
    function setLevel(uint monsterId, uint level) onlyCore public
    {
        MonsterLib.Monster storage mon = monsters[monsterId];
        mon.level = uint8(level);
    }
    
    function setPotion(uint monsterId, uint potionEffect, uint potionExpire) onlyCore public
    {
        MonsterLib.Monster storage mon = monsters[monsterId];
        mon.potionEffect = uint8(potionEffect);
        mon.potionExpire = uint64(potionExpire);
    }
    

    function setBattleCounter(uint monsterId, uint battleCounter) onlyCore public
    {
        MonsterLib.Monster storage mon = monsters[monsterId];
        mon.battleCounter = uint8(battleCounter);
    }
    
    function setActionCooldown(uint monsterId, 
    uint cooldownIndex, 
    uint cooldownEndTimestamp, 
    uint cooldownStartTimestamp,
    uint activeGrowCooldownIndex, 
    uint activeRestCooldownIndex) onlyCore public
    {
        MonsterLib.Monster storage mon = monsters[monsterId];
        mon.cooldownIndex = uint16(cooldownIndex);
        mon.cooldownEndTimestamp = uint64(cooldownEndTimestamp);
        mon.cooldownStartTimestamp = uint64(cooldownStartTimestamp);
        mon.activeRestCooldownIndex = uint8(activeRestCooldownIndex);
        mon.activeGrowCooldownIndex = uint8(activeGrowCooldownIndex);
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
    
    
    function getMonsterBits(uint monsterId) public view returns(uint p1, uint p2, uint p3)
    {
        MonsterLib.Monster storage mon = monsters[monsterId];
        (p1, p2, p3) = MonsterLib.encodeMonsterBits(mon);
    }
    
    function setMonsterBits(uint monsterId, uint p1, uint p2, uint p3) onlyCore public
    {
        MonsterLib.Monster storage mon = monsters[monsterId];
        MonsterLib.Monster memory mon2 = MonsterLib.decodeMonsterBits(p1, p2, p3);
        mon.cooldownIndex = mon2.cooldownIndex;
        mon.siringWithId = mon2.siringWithId;
        mon.activeGrowCooldownIndex = mon2.activeGrowCooldownIndex;
        mon.activeRestCooldownIndex = mon2.activeRestCooldownIndex;
        mon.level = mon2.level;
        mon.potionEffect = mon2.potionEffect;
        mon.cooldownEndTimestamp = mon2.cooldownEndTimestamp;
        mon.potionExpire = mon2.potionExpire;
        mon.cooldownStartTimestamp = mon2.cooldownStartTimestamp;
        mon.battleCounter = mon2.battleCounter;
        
    }
    
    function setMonsterBitsFull(uint monsterId, uint p1, uint p2, uint p3) onlyCore public
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
        mon.activeGrowCooldownIndex = mon2.activeGrowCooldownIndex;
        mon.activeRestCooldownIndex = mon2.activeRestCooldownIndex;
        mon.level = mon2.level;
        mon.potionEffect = mon2.potionEffect;
        mon.cooldownEndTimestamp = mon2.cooldownEndTimestamp;
        mon.potionExpire = mon2.potionExpire;
        mon.cooldownStartTimestamp = mon2.cooldownStartTimestamp;
        mon.battleCounter = mon2.battleCounter;
        
    }
    
}