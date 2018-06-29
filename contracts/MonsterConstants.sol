pragma solidity ^0.4.23;

import "./Pausable.sol";

contract MonsterConstants is Ownable
{
    bool public isMonsterConstants = true;
    
    uint32[14] public growCooldowns = [
        uint32(30 minutes),
        uint32(1 hours),
        uint32(1 hours),
        uint32(2 hours),
        uint32(2 hours),
        uint32(4 hours),
        uint32(4 hours),
        uint32(8 hours),
        uint32(8 hours),
        uint32(16 hours),
        uint32(16 hours),
        uint32(24 hours),
        uint32(24 hours),
        uint32(48 hours)
    ];
    
    function growCooldownsLength() public view returns(uint)
    {
        return growCooldowns.length;
    }
    
    uint8[27] public genToGrowCdIndex = [
        0, 0,
        1, 1,
        2, 2,
        3, 3,
        4, 4,
        5, 5,
        6, 6,
        7, 7,
        8, 8,
        9, 9,
        10, 10,
        11, 11,
        12, 12,
        13
    ];
    
    function genToGrowCdIndexLength() public view returns(uint)
    {
        return genToGrowCdIndex.length;
    }
    
    uint32[14] public actionCooldowns = [
        uint32(1 minutes),
        uint32(2 minutes),
        uint32(5 minutes),
        uint32(10 minutes),
        uint32(30 minutes),
        uint32(1 hours),
        uint32(2 hours),
        uint32(4 hours),
        uint32(8 hours),
        uint32(16 hours),
        uint32(1 days),
        uint32(2 days),
        uint32(4 days),
        uint32(7 days)
    ];
    
    function actionCooldownsLength() public view returns (uint)
    {
        return actionCooldowns.length;
    }
}