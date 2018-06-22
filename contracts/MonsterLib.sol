pragma solidity ^0.4.24;

library MonsterLib {
    
    //max uint constant for bit operations
    uint constant UINT_MAX = uint(2) ** 256 - 1;
    
    function getBits(uint256 source, uint offset, uint count) public pure returns(uint256 bits_)
    {
        uint256 mask = (uint(2) ** count - 1) * uint(2) ** offset;
        return (source & mask) / uint(2) ** offset;
    }
    
    function setBits(uint target, uint bits, uint size, uint offset) public pure returns(uint)
    {
        //ensure bits do not exccess declared size
        uint256 truncateMask = uint(2) ** size - 1;
        bits = bits & truncateMask;
        
        //shift in place
        bits = bits * uint(2) ** offset;
        
        uint clearMask = ((uint(2) ** size - 1) * (uint(2) ** offset)) ^ UINT_MAX;
        target = target & clearMask;
        target = target | bits;
        return target;
        
    }
    
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
        
        uint8 potionEffect;
        uint64 potionExpire;
        
        uint64 foodCooldownEndTimestamp;
        
        uint8 battleCounter;
    }
    
    function mixCooldowns(uint cooldownEndTimestamp, uint foodCooldownEndTimestamp, uint potionExpire, uint battleCounter) public pure returns(uint)
    {
        uint cooldowns = 0;
        cooldowns = setBits(cooldowns, cooldownEndTimestamp, 64, 0);
        cooldowns = setBits(cooldowns, potionExpire, 64, 64);
        cooldowns = setBits(cooldowns, foodCooldownEndTimestamp, 64, 128);
        cooldowns = setBits(cooldowns, battleCounter, 8, 192);
    }
    
    function unmixCooldowns(uint cooldowns) public pure returns(uint64 cooldownEndTimestamp, uint64 potionExpire, uint64 foodCooldownEndTimestamp, uint8 battleCounter) 
    {
        cooldownEndTimestamp = uint64(getBits(cooldowns, 0, 64));
        potionExpire = uint64(getBits(cooldowns, 64, 64));
        foodCooldownEndTimestamp = uint64(getBits(cooldowns, 128, 64));
        battleCounter = uint8(getBits(cooldowns, 192, 8));
    }
    
    function encodeMonsterBits(Monster mon) internal pure returns(uint p1, uint p2, uint p3)
    {
        p1 = mon.genes;
        
        p2 = 0;
        p2 = setBits(p2, mon.cooldownEndTimestamp, 64, 0);
        p2 = setBits(p2, mon.potionExpire, 64, 64);
        p2 = setBits(p2, mon.foodCooldownEndTimestamp, 64, 128);
        p2 = setBits(p2, mon.birthTime, 64, 192);
        
        p3 = 0;
        p3 = setBits(p3, mon.generation, 16, 0);
        p3 = setBits(p3, mon.matronId, 32, 16);
        p3 = setBits(p3, mon.sireId, 32, 48);
        p3 = setBits(p3, mon.siringWithId, 32, 80);
        p3 = setBits(p3, mon.cooldownIndex, 16, 112);
        p3 = setBits(p3, mon.battleGenes, 64, 128);
        p3 = setBits(p3, mon.growScore, 16, 192);
        p3 = setBits(p3, mon.level, 8, 208);
        p3 = setBits(p3, mon.potionEffect, 8, 216);
        p3 = setBits(p3, mon.battleCounter, 8, 224);
    }
    
    function decodeMonsterBits(uint p1, uint p2, uint p3) internal pure returns(Monster mon)
    {
        mon = MonsterLib.Monster({
            genes: 0,
            birthTime: 0,
            cooldownEndTimestamp: 0,
            matronId: 0,
            sireId: 0,
            siringWithId: 0,
            cooldownIndex: 0,
            generation: 0,
            battleGenes: 0,
            level: 0,
            growScore: 0,
            potionEffect: 0,
            potionExpire: 0,
            foodCooldownEndTimestamp: 0,
            battleCounter: 0
        });
        
        mon.genes = p1;
        
        mon.cooldownEndTimestamp = uint64(getBits(p2, 0, 64));
        mon.potionExpire = uint64(getBits(p2, 64, 64));
        mon.foodCooldownEndTimestamp = uint64(getBits(p2, 128, 64));
        mon.birthTime = uint64(getBits(p2, 192, 64));
        
        mon.generation = uint16(getBits(p3, 0, 16));
        mon.matronId = uint32(getBits(p3, 16, 32));
        mon.sireId = uint32(getBits(p3, 48, 32));
        mon.siringWithId = uint32(getBits(p3, 80, 32));
        mon.cooldownIndex = uint16(getBits(p3, 112, 16));
        mon.battleGenes = uint64(getBits(p3, 128, 64));
        mon.growScore = uint16(getBits(p3, 192, 16));
        mon.level = uint8(getBits(p3, 208, 8));
        mon.potionEffect = uint8(getBits(p3, 216, 8));
        mon.battleCounter = uint8(getBits(p3, 224, 8));
    }
    
    function encodeMonster(
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
        uint256 cooldowns) 
        internal pure returns(Monster monster)
    {
        Monster memory mon = Monster({
            genes: genes,
            birthTime: uint64(birthTime),
            matronId: uint32(matronId),
            sireId: uint32(sireId),
            siringWithId: uint32(siringWithId),
            cooldownIndex: uint16(cooldownIndex),
            generation: uint16(generation),
            battleGenes: uint64(battleGenes),
            level: uint8(level),
            growScore: uint16(growScore),
            potionEffect: uint8(potionEffect),
            cooldownEndTimestamp: 0,
            potionExpire: 0,
            foodCooldownEndTimestamp : 0,
            battleCounter: 0
        });
        
        //mon.cooldownIndex = _cooldownIndex;
        (mon.cooldownEndTimestamp, mon.potionExpire, mon.foodCooldownEndTimestamp, mon.battleCounter) = unmixCooldowns(cooldowns);
        
        return mon;
    }
    
    
}