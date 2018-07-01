pragma solidity ^0.4.23;

import "./ERC721.sol";
import "./Pausable.sol";

contract MonsterBattles is Pausable {
    // Reference to contract tracking NFT ownership
    ERC721 public nonFungibleContract;
    
    bool public isBattleContract = true;
    address public backendAddress;
    address public ownerAddress;
    
    constructor(address _nftAddress) public {
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
        backendAddress = msg.sender;
    }
    
    /// @dev Access modifier for CFO-only functionality
    modifier onlyBackend() {
        require(msg.sender == backendAddress);
        _;
    }
    
    modifier onlyProxy() {
        require(msg.sender == address(nonFungibleContract));
        _;
    }
    
    function setTokenContract(address _nftAddress) external onlyOwner
    {
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
    }
    
    function withdrawBalance() external {
        address nftAddress = address(nonFungibleContract);

        require(
            msg.sender == ownerAddress ||
            msg.sender == nftAddress
        );
        // We are using this boolean method to make sure that even if one fails it will still work
        nftAddress.transfer(address(this).balance);
    }
    
    /// @dev Returns true if the claimant owns the token.
    /// @param _claimant - Address claiming to own the token.
    /// @param _tokenId - ID of token whose ownership to verify.
    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return (nonFungibleContract.ownerOf(_tokenId) == _claimant);
    }
    
    function prepareForBattle(address _originalCaller, uint _param1, uint _param2, uint _param3) public payable onlyProxy whenNotPaused returns(uint){
        require(_param1 > 0);
        require(_param2 > 0);
        require(_param3 > 0);
        
        //param1 0-160 reserved for monster ids (5 items)
        
        require(_originalCaller != 0);
    }
    
    function withdrawFromBattle(address _originalCaller, uint _param1, uint _param2, uint _param3) onlyProxy public returns(uint){
        require(_param1 > 0);
        require(_param2 > 0);
        require(_param3 > 0);
        require(_originalCaller != 0);
        nonFungibleContract.transfer(_originalCaller, 0);
    }
    
    function finishBattle(address _originalCaller, uint _param1, uint _param2, uint _param3) public onlyProxy returns(uint return1, uint return2, uint return3) {
        require(_originalCaller == backendAddress);
        require(_param1 > 0);
        require(_param2 > 0);
        require(_param3 > 0);
        require(_originalCaller != 0);
        //return1 reserved for monster ids (8 items)
        //return2 0-64 reserved for monster ids (2 items)
        return1 = _param1;
        return2 = _param2; 
        return3 = _param3;
        nonFungibleContract.transfer(_originalCaller, 0);
    }
    
    
}