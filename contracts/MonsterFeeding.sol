pragma solidity ^0.4.23;

import "./MonsterBreeding.sol";
import "./MonsterFood.sol";
import "./MonsterLib.sol";

contract MonsterFeeding is MonsterBreeding {
    
    event MonsterFed(uint monsterId, uint growScore);
    
    
    function setMonsterFeedingAddress(address _address) external onlyCEO {
        MonsterFood candidateContract = MonsterFood(_address);

        // NOTE: verify that a contract is what we expect
        require(candidateContract.isMonsterFood());

        // Set the new contract address
        monsterFood = candidateContract;
    }
    
    function feedMonster(uint _monsterId, uint _foodCode) external payable{
        Monster storage monster = monsters[_monsterId];
        
        uint cooldowns = 0;
        cooldowns = MonsterLib.setBits(cooldowns, monster.cooldownEndTimestamp, 64, 0);
        cooldowns = MonsterLib.setBits(cooldowns, monster.potionExpire, 64, 64);
        cooldowns = MonsterLib.setBits(cooldowns, monster.foodCooldownEndTimestamp, 64, 128);
        
        (uint newGrowScore, uint newLevel, uint potionEffect, uint newCooldowns) = 
                monsterFood.feedMonster.value(msg.value)(
                    msg.sender,
                    _foodCode,
                monster.generation,
                monster.cooldownIndex,
                monster.growScore, 
                monster.level, 
                monster.cooldownEndTimestamp, 
                monster.siringWithId);
        
        
        monster.growScore = uint16(newGrowScore);
        monster.level = uint8(newLevel);
        monster.cooldownEndTimestamp = uint64(MonsterLib.getBits(newCooldowns, 0, 64));
        monster.potionEffect = uint8(potionEffect);
        monster.potionExpire = uint64(MonsterLib.getBits(newCooldowns, 64, 64));
        monster.foodCooldownEndTimestamp = uint64(MonsterLib.getBits(newCooldowns, 128, 64));

        emit MonsterFed(_monsterId, monster.growScore);
        
    }
}