pragma solidity ^0.4.23;


contract MonsterFood {
    bool public isMonsterFood = true;
    
    event FoodCreated(uint id, uint code, uint feedingScore, uint price);
    event FoodDeleted(uint code);
    
    constructor() public {
        ownerAddress = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == ownerAddress);
        _;
    }
    
    struct Food {
        uint16 code;
        uint16 feedingScore;
        uint256 priceWei;
        bool exists;
    }
    
    address public ownerAddress;
    Food[] food;
    mapping (uint16 => uint32) codeToFoodIndex;
    
    function setOwner(address newOwner) public onlyOwner{
        require(newOwner != address(0));
        ownerAddress = newOwner;
    }
    
    function createFood(uint _feedingScore, uint _priceWei, uint _code) public onlyOwner returns(uint) {
        require(_feedingScore >= 10);
        require(_priceWei > 0);
        
        Food memory _food = Food({
            feedingScore: uint16(_feedingScore),
            priceWei: _priceWei,
            code: uint16(_code),
            exists: true
        });
        
        uint256 newFoodIndex = food.push(_food) - 1;
        require(newFoodIndex == uint256(uint32(newFoodIndex)));
        codeToFoodIndex[uint16(_code)] = uint32(newFoodIndex);
        
        emit FoodCreated(newFoodIndex, _food.code, _food.feedingScore, _food.priceWei);
        return newFoodIndex;
    }
    
    function getFood(uint256 _foodCode)
        external
        view
        returns (
        uint256 feedingScore,
        uint256 priceWei,
        bool exists
    ) {
        uint32 foodId = codeToFoodIndex[uint16(_foodCode)];
        Food storage _food = food[foodId];
        require(_food.exists);
        feedingScore = uint(_food.feedingScore);
        exists = _food.exists;
        priceWei = _food.priceWei;
    }
    
    
    function deleteFood(uint _code) public onlyOwner {
        uint _id = codeToFoodIndex[uint16(_code)];
        delete codeToFoodIndex[uint16(_code)];
        delete food[_id];
        emit FoodDeleted(_code);
    }
}
    
    
