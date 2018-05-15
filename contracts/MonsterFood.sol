pragma solidity ^0.4.23;


contract MonsterFood {
    
    constructor() public {
        ownerAddress = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == ownerAddress);
        _;
    }
    
    struct Food {
        uint16 cooldownSeconds;
        uint16 feedingScore;
        uint256 priceWei;
        bool exists;
    }
    
    address public ownerAddress;
    Food[] food;
    
    function setOwner(address newOwner) public onlyOwner{
        require(newOwner != address(0));
        ownerAddress = newOwner;
    }
    
    function createFood(uint _cooldownSeconds, uint _feedingScore, uint _priceWei) public onlyOwner returns(uint) {
        require(_cooldownSeconds > 0);
        require(_feedingScore > 0);
        require(_priceWei > 0);
        Food memory _food = Food({
            cooldownSeconds: uint16(_cooldownSeconds),
            feedingScore: uint16(_feedingScore),
            priceWei: _priceWei,
            exists: true
        });
        
        uint256 newFoodIndex = food.push(_food) - 1;
        return newFoodIndex;
    }
    
    function getFood(uint256 _id)
        external
        view
        returns (
        uint256 cooldownSeconds,
        uint256 feedingScore,
        uint256 priceWei,
        bool exists
    ) {
        Food storage _food = food[_id];
        cooldownSeconds = uint256(_food.cooldownSeconds);
        feedingScore = uint(_food.feedingScore);
        exists = _food.exists;
        priceWei = _food.priceWei;
    }
    
    function getFoodCount() public constant returns(uint count) {
        return food.length;
    }
    
    function deleteFood(uint _id) public onlyOwner {
        delete food[_id];
    }
}
    
    
