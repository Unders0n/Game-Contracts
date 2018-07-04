pragma solidity ^0.4.23;

import "./MonsterAccessControl.sol";
import "./MonsterBitSaleAuction.sol";
import "./MonsterBattles.sol";
import "./MonsterFood.sol";
import "./MonsterStorage.sol";
import "./MonsterConstants.sol";
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


    /// @dev The address of the ClockAuction contract that handles sales of Monsters. This
    ///  same contract handles both peer-to-peer sales as well as the gen0 sales which are
    ///  initiated every 15 minutes.
    SaleClockAuction public saleAuction;
    SiringClockAuction public siringAuction;
    MonsterBattles public battlesContract;
    MonsterFood public monsterFood;
    MonsterStorage public monsterStorage;
    MonsterConstants public monsterConstants;
    
    /// @dev The address of the sibling contract that is used to implement the sooper-sekret
    ///  genetic combination algorithm.
    MonsterGeneticsInterface public geneScience;
    
    function setMonsterStorageAddress(address _address) external onlyCEO {
        MonsterStorage candidateContract = MonsterStorage(_address);

        // NOTE: verify that a contract is what we expect
        require(candidateContract.isMonsterStorage());

        // Set the new contract address
        monsterStorage = candidateContract;
    }
    
    function setMonsterConstantsAddress(address _address) external onlyCEO {
        MonsterConstants candidateContract = MonsterConstants(_address);

        // NOTE: verify that a contract is what we expect
        require(candidateContract.isMonsterConstants());

        // Set the new contract address
        monsterConstants = candidateContract;
    }
    
    /// @dev Sets the reference to the battles contract.
    /// @param _address - Address of battles contract.
    function setBattlesAddress(address _address) external onlyCEO {
        MonsterBattles candidateContract = MonsterBattles(_address);

        // NOTE: verify that a contract is what we expect
        require(candidateContract.isBattleContract());

        // Set the new contract address
        battlesContract = candidateContract;
    }


    /// @dev Assigns ownership of a specific Monster to an address.
    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        // Since the number of monsters is capped to 2^32 we can't overflow this
        uint count = monsterStorage.ownershipTokenCount(_to);
        monsterStorage.setOwnershipTokenCount(_to, count + 1);
        
        // transfer ownership
        monsterStorage.setMonsterIndexToOwner(_tokenId, _to);
        // When creating new monsters _from is 0x0, but we can't account that address.
        if (_from != address(0)) {
            count =  monsterStorage.ownershipTokenCount(_from);
            monsterStorage.setOwnershipTokenCount(_from, count - 1);
            // clear any previously approved ownership exchange
            monsterStorage.setMonsterIndexToApproved(_tokenId, address(0));
        }
        
        if(_from == address(saleAuction))
        {
            MonsterLib.Monster memory monster = readMonster(_tokenId);
            if(monster.level == 0)
            {
                monsterStorage.setActionCooldown(_tokenId, 
                    monster.cooldownIndex, 
                    uint64(now + monsterConstants.growCooldowns(monster.activeGrowCooldownIndex)), 
                    now,
                    monster.activeGrowCooldownIndex, 
                    monster.activeRestCooldownIndex);
            }
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
        require(_matronId == uint256(uint32(_matronId)));
        require(_sireId == uint256(uint32(_sireId)));
        require(_generation == uint256(uint16(_generation)));
        
        
        
        MonsterLib.Monster memory _monster = MonsterLib.Monster({
            genes: _genes,
            birthTime: uint64(now),
            cooldownEndTimestamp: 0,
            matronId: uint32(_matronId),
            sireId: uint32(_sireId),
            siringWithId: uint32(0),
            cooldownIndex: uint16(0),
            generation: uint16(_generation),
            battleGenes: uint64(_battleGenes),
            level: uint8(_level),
            activeGrowCooldownIndex: uint8(0),
            activeRestCooldownIndex: uint8(0),
            potionEffect: uint8(0),
            potionExpire: uint64(0),
            cooldownStartTimestamp: 0,
            battleCounter: uint8(0)
        });
        
        
        setMonsterGrow(_monster);
        (uint p1, uint p2, uint p3) = MonsterLib.encodeMonsterBits(_monster);
        
        uint monsterId = monsterStorage.createMonster(p1, p2, p3);

        // emit the birth event
        emit Birth(
            _owner,
            monsterId,
            _genes
        );

        // This will assign ownership, and also emit the Transfer event as
        // per ERC721 draft
        _transfer(0, _owner, monsterId);

        return monsterId;
    }
    
    function setMonsterGrow(MonsterLib.Monster monster) internal view
    {
         //New monster starts with the same cooldown as parent gen/2
        uint16 cooldownIndex = uint16(monster.generation / 2);
        if (cooldownIndex > 13) {
            cooldownIndex = 13;
        }
        
        monster.cooldownIndex = uint16(cooldownIndex);
        
        if(monster.level == 0)
        {
            uint gen = monster.generation;
            if(gen > monsterConstants.genToGrowCdIndexLength())
            {
                gen = monsterConstants.genToGrowCdIndexLength();
            }
            
            monster.activeGrowCooldownIndex = monsterConstants.genToGrowCdIndex(gen);
            monster.cooldownEndTimestamp = uint64(now + monsterConstants.growCooldowns(monster.activeGrowCooldownIndex));
            monster.cooldownStartTimestamp = uint64(now);
        }
    }
    
    function readMonster(uint monsterId) internal view returns(MonsterLib.Monster)
    {
        (uint p1, uint p2, uint p3) = monsterStorage.getMonsterBits(monsterId);
       
        MonsterLib.Monster memory mon = MonsterLib.decodeMonsterBits(p1, p2, p3);
         
        return mon;
    }
    
    
    
    

}