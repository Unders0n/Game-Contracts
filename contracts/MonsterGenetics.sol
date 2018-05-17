pragma solidity ^0.4.23;

/// @title SEKRETOOOO
contract MonsterGenetics {
    
    //size of a gene in bits. 6 bits provide 64 variants of gene
    uint8 constant geneBits = 6;
    
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
    

    /// @dev given genes of monster 1 & 2, return a genetic combination - may have a random factor
    /// @param genesMatron genes of mom
    /// @param genesSire genes of sire
    /// @return the genes that are supposed to be passed down the child
    function mixGenes(uint256 genesMatron, uint256 genesSire, uint256 targetBlock) public view returns (uint256 _result)
    {
        //this hash is calculated from input data and it's bits will be used as random numbers
        uint randomSource = uint256(keccak256(abi.encodePacked(blockhash(targetBlock), genesMatron, genesSire, targetBlock)));
        uint8 randomIndex = 0;
        uint randomValue = 0;

        
        for(uint8 geneGroupIndex = 0; geneGroupIndex < geneGroupsCount; geneGroupIndex++)
        {
            uint8 geneGroupBitsLength = geneBits * geneGroupSize;
            uint8 geneGroupOffset = geneBits * geneGroupSize * geneGroupIndex;
            
            //processing each genes group separately
            uint geneGroupMatron = getGenesGroup(genesMatron, geneGroupIndex);
            uint geneGroupSire = getGenesGroup(genesSire, geneGroupIndex);

            //processing each gen in group swapping them with a chance
            for(uint8 geneIndex = geneGroupSize-1; geneIndex > 0; geneIndex--)
            {
                (geneGroupMatron, randomIndex) = processRecessiveGenes(geneGroupMatron, randomSource, randomIndex);
                (genesSire, randomIndex) = processRecessiveGenes(genesSire, randomSource, randomIndex);
            }
            
            //setting modified groups back in place
            genesMatron = setBits(genesMatron, geneGroupMatron, geneGroupBitsLength, geneGroupOffset);
            genesSire = setBits(genesSire, geneGroupSire, geneGroupBitsLength, geneGroupOffset);
        }
        
        _result = 0;
        
        uint gene = 0;
        
        //going for each gene position one by one
        for(geneIndex = 0; geneIndex < geneGroupSize * geneGroupsCount; geneIndex++)
        {
            uint8 offset = geneIndex * geneBits;
            randomValue = getBits(randomSource, randomIndex, 1);
            randomIndex += 1;
            
            //randomly taking gene from mom or dad
            if(randomValue == 0)
            {
                gene = getBits(genesMatron, offset, geneBits);
            }
            else
            {
                gene = getBits(genesSire, offset, geneBits);
            }
            
            //setting selected gene in it's place in the resulting set
            _result = setBits(_result, gene, geneBits, offset);
        }
    
    }
    
    function processRecessiveGenes(uint geneGroup, uint randomSource, uint8 randomIndex) private pure returns(uint geneGroup_, uint8 randomIndex_)
    {
        randomIndex_ = randomIndex;
        geneGroup_ = geneGroup;
        bool swapped = false;
        uint randomValue;
        for(uint8 geneIndex = geneGroupSize-1; geneIndex > 0; geneIndex--)
        {
            swapped = false;
            randomValue = getBits(randomSource, randomIndex_, 2);
            randomIndex_ += 2;
            if(randomValue == 0)
            {
                geneGroup_ = swapGenes(geneGroup_, geneIndex, geneIndex - 1);
                swapped = true;
            }
        }
    }
    
    function swapGenes(uint geneGroup, uint8 geneIndex1, uint8 geneIndex2) private pure returns(uint)
    {
        uint8 offset1 = geneIndex1 * geneBits;
        uint8 offset2 = geneIndex2 * geneBits;
        uint gene1 = getBits(geneGroup, offset1, geneBits);
        uint gene2 = getBits(geneGroup, offset2, geneBits);
        geneGroup = setBits(geneGroup, gene2, geneBits, offset1);
        geneGroup = setBits(geneGroup, gene1, geneBits, offset2);
        return geneGroup;
    }
    
    
    
    function getGenesGroup(uint256 genes, uint8 groupIndex) private pure returns (uint32 genesGroup_)
    {
        uint8 offset = groupIndex * geneGroupSize * geneBits;
        uint8 count = geneBits * geneGroupSize;
        return uint32(getBits(genes, offset, count));
    }
    
    function getBits(uint256 source, uint8 offset, uint8 count) private pure returns(uint256 bits_)
    {
        uint256 mask = (uint(2) ** count - 1) * uint(2) ** offset;
        return (source & mask) / uint(2) ** offset;
    }
    
    function setBits(uint target, uint bits, uint8 size, uint8 offset) private pure returns(uint)
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