pragma solidity ^0.4.23;

import "./MonsterFeeding.sol";
import "./MonsterBattles.sol";

/// @title Handles creating auctions for sale and siring of monsters.
contract MonsterFighting is MonsterFeeding {
    /// @dev Sets the reference to the battles contract.
    /// @param _address - Address of battles contract.
    function setBattlesAddress(address _address) external onlyCEO {
        MonsterBattles candidateContract = MonsterBattles(_address);

        // NOTE: verify that a contract is what we expect
        require(candidateContract.isBattleContract());

        // Set the new contract address
        battlesContract = candidateContract;
    }
    
    function getBits(uint256 source, uint8 offset, uint8 count) internal pure returns(uint256 bits_)
    {
        uint256 mask = (uint(2) ** count - 1) * uint(2) ** offset;
        return (source & mask) / uint(2) ** offset;
    }
    
    function prepareForBattle(uint _param1, uint _param2, uint _param3) external payable returns(uint){
        require(_param1 > 0);
        require(_param2 > 0);
        require(_param3 > 0);
        
        for(uint i = 0; i < 5; i++){
            uint monsterId = getBits(_param1, uint8(i * 32), uint8(32));
            require(_owns(msg.sender, monsterId));
            _approve(monsterId, address(battlesContract));
        }
        
        return battlesContract.prepareForBattle.value(msg.value)(msg.sender, _param1, _param2, _param3);
    }
    
    function withdrawFromBattle(uint _param1, uint _param2, uint _param3) external returns(uint){
        return battlesContract.withdrawFromBattle(msg.sender, _param1, _param2, _param3);
    }
    
    function finishBattle(uint _param1, uint _param2, uint _param3) external returns(uint) {
        return battlesContract.finishBattle(msg.sender, _param1, _param2, _param3);
    }
}