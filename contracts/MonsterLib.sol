pragma solidity ^0.4.24;

library MonsterLib {
    
    //max uint constant for bit operations
    uint constant UINT_MAX = uint(2) ** 256 - 1;
    
    function getBits(uint256 source, uint offset, uint count) internal pure returns(uint256 bits_)
    {
        uint256 mask = (uint(2) ** count - 1) * uint(2) ** offset;
        return (source & mask) / uint(2) ** offset;
    }
    
    function setBits(uint target, uint bits, uint size, uint offset) internal pure returns(uint)
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
}