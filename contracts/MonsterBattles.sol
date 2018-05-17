pragma solidity ^0.4.23;

import "./ERC721.sol";

contract MonsterBattles {
    // Reference to contract tracking NFT ownership
    ERC721 public nonFungibleContract;
    
    bool public isBattleContract = true;
    address public backendAddress;
    address public ownerAddress;
    
    constructor(address _nftAddress) public {
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
        ownerAddress = msg.sender;
        backendAddress = msg.sender;
    }
    
    /// @dev Access modifier for CEO-only functionality
    modifier onlyOwner() {
        require(msg.sender == ownerAddress);
        _;
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
    
    function prepareForBattle(address _originalCaller, uint _param1, uint _param2, uint _param3) public payable onlyProxy returns(uint){
        require(_param1 > 0);
        require(_param2 > 0);
        require(_param3 > 0);
        require(_originalCaller != 0);
    }
    
    function withdrawFromBattle(address _originalCaller, uint _param1, uint _param2, uint _param3) onlyProxy public returns(uint){
        require(_param1 > 0);
        require(_param2 > 0);
        require(_param3 > 0);
        require(_originalCaller != 0);
        nonFungibleContract.transfer(_originalCaller, 0);
    }
    
    function finishBattle(address _originalCaller, uint _param1, uint _param2, uint _param3) public onlyProxy returns(uint) {
        require(_originalCaller == backendAddress);
        require(_param1 > 0);
        require(_param2 > 0);
        require(_param3 > 0);
        require(_originalCaller != 0);
        nonFungibleContract.transfer(_originalCaller, 0);
    }
    
    function setOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));

        ownerAddress = _newOwner;
    }
    
}