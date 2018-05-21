pragma solidity ^0.4.23;

contract MonsterGeneticsInterface {
    /// @dev simply a boolean to indicate this is the contract we expect to be
    function isMonsterGenetics() public pure returns (bool);

    /// @dev given genes of monster 1 & 2, return a genetic combination - may have a random factor
    /// @param genesMatron genes of mom
    /// @param genesSire genes of sire
    /// @return the genes that are supposed to be passed down the child
    function mixGenes(uint256 genesMatron, uint256 genesSire, uint256 targetBlock) public view returns (uint256 _result);
    
    function mixBattleGenes(uint256 genesMatron, uint256 genesSire, uint256 targetBlock) public view returns (uint256 _result);
}