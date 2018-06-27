pragma solidity ^0.4.23;

import "./MonsterBreeding.sol";
import "./MonsterFood.sol";
import "./MonsterLib.sol";

contract MonsterFeeding is MonsterBreeding {
    
    event MonsterFed(uint monsterId, uint growScore);
    
    
    function setMonsterFoodAddress(address _address) external onlyCEO {
        MonsterFood candidateContract = MonsterFood(_address);

        // NOTE: verify that a contract is what we expect
        require(candidateContract.isMonsterFood());

        // Set the new contract address
        monsterFood = candidateContract;
    }
    
    function feedMonster(uint _monsterId, uint _foodCode) external payable{

        (uint p1, uint p2, uint p3) = monsterStorage.getMonsterBits(_monsterId);
        
        (p1, p2, p3) = monsterFood.feedMonster.value(msg.value)( msg.sender, _foodCode, p1, p2, p3);
        
        monsterStorage.setMonsterBits(_monsterId, p1, p2, p3);

        emit MonsterFed(_monsterId, 0);
        
    }
}