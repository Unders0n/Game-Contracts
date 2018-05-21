pragma solidity ^0.4.23;

/// @title SEKRETOOOO
contract MonsterGenetics {
    
    //size of a gene in bits. 6 bits provide 64 variants of gene
    uint8 constant geneBits = 6;
    uint8 constant battleGeneBits = 4;
    uint8 constant battleGenesGroupsCount = 3;
    
    //count of genes in a group. right-most gene is considered dominant and will 
    //have effect on the image. others are considered recessive. 
    //genes may get swapped in process of breeding so recessive ones have a chance
    //to jump to the dominant place and vice versa
    uint8 constant geneGroupSize = 3;
    
    //count of traits of the monster. each trait is represented as a genes group
    uint8 constant geneGroupsCount = 14;
    
    //max uint constant for bit operations
    uint constant UINT_MAX = uint(2) ** 256 - 1;
    
    /// @dev simply a boolean to indicate this is the contract we expect to be
    function isMonsterGenetics() public pure returns (bool _isMonsterGenetics)
    {
        _isMonsterGenetics = true;
    }
    
    function mixBattleGenes(uint256 genesMatron, uint256 genesSire, uint256 targetBlock) public view returns (uint256 _result)
    {
        return mixGenesInner(genesMatron, genesSire, targetBlock, battleGeneBits, geneGroupSize, battleGenesGroupsCount);
    }
    

    /// @dev given genes of monster 1 & 2, return a genetic combination - may have a random factor
    /// @param genesMatron genes of mom
    /// @param genesSire genes of sire
    /// @return the genes that are supposed to be passed down the child
    function mixGenes(uint256 genesMatron, uint256 genesSire, uint256 targetBlock) public view returns (uint256 _result)
    {
        return mixGenesInner(genesMatron, genesSire, targetBlock, geneBits, geneGroupSize, geneGroupsCount);
    }
    
    function swapInsideGroups(uint _genesMatron, 
    uint _genesSire,
    uint _randomSource,
    uint _randomIndex,
    uint _geneBits,
    uint _geneGroupSize,
    uint _geneGroupsCount) internal pure returns(uint genesMatron_, uint genesSire_, uint randomIndex_)
    {
        for(uint8 geneGroupIndex = 0; geneGroupIndex < _geneGroupsCount; geneGroupIndex++)
        {
        
            //processing each genes group separately
            uint geneGroupMatron = uint32(getBits(_genesMatron, uint8(_geneBits * _geneGroupSize * geneGroupIndex), uint8(_geneBits * _geneGroupSize)));
            uint geneGroupSire = uint32(getBits(_genesSire, uint8(_geneBits * _geneGroupSize * geneGroupIndex), uint8(_geneBits * _geneGroupSize)));

           
            (geneGroupMatron, _randomIndex) = processRecessiveGenes(geneGroupMatron, _randomSource, _randomIndex, _geneGroupSize, _geneBits);
            (geneGroupSire, _randomIndex) = processRecessiveGenes(geneGroupSire, _randomSource, _randomIndex, _geneGroupSize, _geneBits);
            
            
            //setting modified groups back in place
            _genesMatron = setBits(_genesMatron, geneGroupMatron, uint8(_geneBits * _geneGroupSize), _geneBits * _geneGroupSize * geneGroupIndex);
            _genesSire = setBits(_genesSire, geneGroupSire, uint8(_geneBits * _geneGroupSize), _geneBits * _geneGroupSize * geneGroupIndex);
        }
        
        genesMatron_ = _genesMatron;
        genesSire_ = _genesSire;
        randomIndex_ = _randomIndex;
    }
    
    function mixGenesInner(uint _genesMatron, 
    uint _genesSire,
    uint _targetBlock, 
    uint _geneBits,
    uint _geneGroupSize,
    uint _geneGroupsCount) internal view returns (uint256 _result)
    {
        //this hash is calculated from input data and it's bits will be used as random numbers
        uint randomSource = uint256(keccak256(abi.encodePacked(blockhash(_targetBlock), _genesMatron, _genesSire, _targetBlock)));
        uint randomIndex = 0;
        uint randomValue = 0;

        (_genesMatron, _genesSire, randomIndex) = swapInsideGroups(_genesMatron, _genesSire, randomSource, randomIndex, _geneBits, _geneGroupSize, _geneGroupsCount);
        
        _result = 0;
        
        uint gene = 0;
        
        //going for each gene position one by one
        for(uint geneIndex = 0; geneIndex < _geneGroupSize * _geneGroupsCount; geneIndex++)
        {
            randomValue = getBits(randomSource, randomIndex, 1);
            randomIndex += 1;
            
            //randomly taking gene from mom or dad
            if(randomValue == 0)
            {
                gene = getBits(_genesMatron, geneIndex * _geneBits, _geneBits);
            }
            else
            {
                gene = getBits(_genesSire, geneIndex * _geneBits, _geneBits);
            }
            
            //setting selected gene in it's place in the resulting set
            _result = setBits(_result, gene, _geneBits, geneIndex * _geneBits);
        }
    
    }
    
    function processRecessiveGenes(uint _geneGroup, uint _randomSource, uint _randomIndex, uint _geneGroupSize, uint _geneBits) private pure returns(uint geneGroup_, uint randomIndex_)
    {
        randomIndex_ = _randomIndex;
        geneGroup_ = _geneGroup;
        bool swapped = false;
        uint randomValue;
        for(uint geneIndex = _geneGroupSize-1; geneIndex > 0; geneIndex--)
        {
            swapped = false;
            randomValue = getBits(_randomSource, randomIndex_, 2);
            randomIndex_ += 2;
            if(randomValue == 0)
            {
                _geneGroup = swapGenes(_geneGroup, geneIndex, geneIndex - 1, _geneBits);
                swapped = true;
            }
        }
    }
    
    function swapGenes(uint _geneGroup, uint _geneIndex1, uint _geneIndex2, uint _geneBits) private pure returns(uint)
    {
        uint offset1 = _geneIndex1 * _geneBits;
        uint offset2 = _geneIndex2 * _geneBits;
        uint gene1 = getBits(_geneGroup, uint8(offset1), uint8(_geneBits));
        uint gene2 = getBits(_geneGroup, uint8(offset2), uint8(_geneBits));
        _geneGroup = setBits(_geneGroup, gene2, uint8(_geneBits), offset1);
        _geneGroup = setBits(_geneGroup, gene1, uint8(_geneBits), offset2);
        return _geneGroup;
    }
    
    
    
    
    function getBits(uint256 source, uint offset, uint count) private pure returns(uint256 bits_)
    {
        uint256 mask = (uint(2) ** count - 1) * uint(2) ** offset;
        return (source & mask) / uint(2) ** offset;
    }
    
    function setBits(uint target, uint bits, uint size, uint offset) private pure returns(uint)
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