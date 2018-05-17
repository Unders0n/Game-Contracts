pragma solidity ^0.4.23;

import "./MonsterBreeding.sol";
import "./MonsterFood.sol";

contract MonsterFeeding is MonsterBreeding {
    
    event LevelUp(uint monsterId, uint level);
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
        require(monster.level < 2);
        
        (uint feedingScore, uint priceWei, bool exists) = monsterFood.getFood(_foodCode);
        require(exists);
        
        require(msg.value > priceWei);
        require(feedingScore >= 10);
        
        uint devalvation = monster.generation / 2;
        if(devalvation > 8){
            devalvation = 8;
        }
        
        feedingScore -= devalvation;
        
        uint growScore = monster.growScore + feedingScore;
        if(growScore >= levelScores[monster.level]){
            monster.level++;
            monster.growScore = 0;
            emit LevelUp(_monsterId, monster.level);
        } else{
            monster.growScore += uint8(feedingScore);
        }
        
        emit MonsterFed(_monsterId, monster.growScore);
        
    }
}