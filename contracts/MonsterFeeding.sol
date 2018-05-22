pragma solidity ^0.4.23;

import "./MonsterBreeding.sol";
import "./MonsterFood.sol";

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
        
        (uint newGrowScore, uint newLevel, uint newMfCooldown, uint potionId, uint potionExpire) = 
                monsterFood.feedMonster.value(msg.value)(_foodCode,
                monster.growScore, 
                monster.level, 
                monster.cooldownEndTimestamp, 
                monster.siringWithId);
                
        
                
        monster.growScore = uint16(newGrowScore);
        monster.level = uint8(newLevel);
        monster.cooldownEndTimestamp = uint64(newMfCooldown);
        monster.potionId = uint8(potionId);
        monster.potionExpire = uint64(potionExpire);

        emit MonsterFed(_monsterId, monster.growScore);
        
    }
}