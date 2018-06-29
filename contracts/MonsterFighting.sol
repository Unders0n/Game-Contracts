pragma solidity ^0.4.23;

import "./MonsterFeeding.sol";
import "./MonsterBattles.sol";
import "./MonsterLib.sol";

/// @title Handles creating auctions for sale and siring of monsters.
contract MonsterFighting is MonsterFeeding {
    
    
      function prepareForBattle(uint _param1, uint _param2, uint _param3) external payable returns(uint){
        require(_param1 > 0);
        require(_param2 > 0);
        require(_param3 > 0);
        
        for(uint i = 0; i < 5; i++){
            uint monsterId = MonsterLib.getBits(_param1, uint8(i * 32), uint8(32));
            require(_owns(msg.sender, monsterId));
            _approve(monsterId, address(battlesContract));
        }
        
        return battlesContract.prepareForBattle.value(msg.value)(msg.sender, _param1, _param2, _param3);
    }
    
    function withdrawFromBattle(uint _param1, uint _param2, uint _param3) external returns(uint){
        return battlesContract.withdrawFromBattle(msg.sender, _param1, _param2, _param3);
    }
    
    function finishBattle(uint _param1, uint _param2, uint _param3) external returns(uint) {
        (uint return1, uint return2, uint return3) = battlesContract.finishBattle(msg.sender, _param1, _param2, _param3);
        uint[10] memory monsterIds;
        uint i;
        uint monsterId;
        
        require(return3>=0);
        
        for(i = 0; i < 8; i++){
            monsterId = MonsterLib.getBits(return1, uint8(i * 32), uint8(32));
            monsterIds[i] = monsterId;
        }
        
        for(i = 0; i < 2; i++){
            monsterId = MonsterLib.getBits(return2, uint8(i * 32), uint8(32));
            monsterIds[i+8] = monsterId;
        }
        
        for(i = 0; i < 10; i++){
            monsterId = monsterIds[i];
            MonsterLib.Monster memory monster = readMonster(monsterId);
            uint bc = monster.battleCounter + 1;
            uint increaseIndex = 0;
            if(bc >= 10)
            {
                bc = 0;
                increaseIndex = 1;
            }
            monster.battleCounter = uint8(bc);
            _triggerCooldown(monsterId, monster, increaseIndex);
        }
        
        
    }
}