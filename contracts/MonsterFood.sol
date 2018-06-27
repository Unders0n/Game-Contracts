pragma solidity ^0.4.23;

import "./ERC721.sol";
import "./MonsterLib.sol";

contract MonsterFood {
    
    ERC721 public nonFungibleContract;
    
    bool public isMonsterFood = true;
    uint32 freeFoodCooldown = uint32(60 minutes);
    uint32 potionDuration = uint32(6 hours);
    
    event FoodCreated(uint code);
    event FoodDeleted(uint code);
    
    constructor(address _nftAddress) public {
        ownerAddress = msg.sender;
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
    }
    
    modifier onlyOwner() {
        require(msg.sender == ownerAddress);
        _;
    }
    
    modifier onlyCore() {
        require(msg.sender == address(nonFungibleContract));
        _;
    }
    
    function setTokenContract(address _nftAddress) external onlyOwner
    {
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
    }
    
    //application bits by offset:
    //0 (1) - cheeper
    //1 (2) - mom
    //2 (4) - mature (not mom)
    
    struct Food {
        uint16 code;
        uint16 feedingScore;
        uint64 cdReduction; //seconds
        uint256 priceWei;
        uint16 application;
        uint8 potionEffect;
        bool exists;
    }
    
    address public ownerAddress;
    
    mapping (uint16 => Food) codeToFoodIndex;
    
    function setOwner(address newOwner) public onlyOwner{
        require(newOwner != address(0));
        ownerAddress = newOwner;
    }
    
    function setFreeFoodCooldown(uint newCooldown) external onlyOwner{
        require(newCooldown > 0);
        freeFoodCooldown = uint32(newCooldown);
    }
    
    function setPotionDuration(uint newDuration) external onlyOwner{
        require(newDuration > 0);
        potionDuration = uint32(newDuration);
    }
    
    function createFood(uint _feedingScore, uint _priceWei, uint _code, uint _cdReduction, uint _application, uint _potionEffect) external onlyOwner returns(uint) {
        require(_feedingScore > 0 || _cdReduction > 0 || _potionEffect > 0);
        require(_application > 0);
        require(_code == uint(uint16(_code)));
        
        Food memory _food = Food({
            feedingScore: uint16(_feedingScore),
            priceWei: _priceWei,
            code: uint16(_code),
            cdReduction: uint64(_cdReduction),
            application: uint16(_application),
            potionEffect: uint8(_potionEffect),
            exists: true
        });
        
        //uint256 newFoodIndex = foodArray.push(_food) - 1;
        //require(newFoodIndex == uint256(uint32(newFoodIndex)));
        codeToFoodIndex[uint16(_code)] = _food;
        
        emit FoodCreated(_food.code);
        return _food.code;
    }
    
    function feedMonster(address originalCaller, uint foodCode, uint p1, uint p2, uint p3) onlyCore public payable
    returns(uint p1_, uint p2_, uint p3_)
    {
        require(originalCaller != address(0));
        Food storage _food = codeToFoodIndex[uint16(foodCode)];
        require(msg.value >= _food.priceWei);
        
        MonsterLib.Monster memory mon = MonsterLib.decodeMonsterBits(p1, p2, p3);
        
        require(checkFood(_food, mon));

        applyFoodCooldown(_food, mon);
        applyGrowScore(_food, mon);
        applyCDR(_food, mon);
        applyPotion(_food, mon);

        (p1_, p2_, p3_) = MonsterLib.encodeMonsterBits(mon);
        uint _return = msg.value - _food.priceWei;
        originalCaller.transfer(_return);
    }
    
    function applyPotion(Food food, MonsterLib.Monster monster) internal view
    {
        if(food.potionEffect == 0)
        {
            return;
        }
        
        monster.potionExpire = uint64(now + potionDuration);
        monster.potionEffect = food.potionEffect;
    }
    
    function applyCDR(Food food, MonsterLib.Monster monster) internal pure
    {
        if(food.cdReduction == 0)
        {
            return;
        }
        
        if(monster.cooldownEndTimestamp < food.cdReduction)
        {
            monster.cooldownEndTimestamp = 0;
        }
        else
        {
            monster.cooldownEndTimestamp -= food.cdReduction;
        }
    }
    
    function applyGrowScore(Food food, MonsterLib.Monster monster) internal pure 
    {
        if(food.feedingScore == 0)
        {
            return;
        }
        
        if(monster.level >= 1)
        {
            return;
        }
        
        uint reqiredScore = getLevelupScoreRequired(monster.level, monster.generation);
        monster.growScore = uint16(monster.growScore + food.feedingScore);
        
        if(monster.growScore >= reqiredScore)
        {
            monster.growScore = uint16(monster.growScore - reqiredScore);
            monster.level += 1;
        }
        
        
    }
    
    function getLevelupScoreRequired(uint level, uint generation) public pure returns(uint)
    {
        if(level >= 1)
        {
            return 0;
        }
        
        if(generation > 13)
        {
            generation = 13;
        }
        
        uint divider = 25;
        
        uint scoreRequired = uint(10) * generation * generation / divider + 1;
        return scoreRequired;
    }
    
    function applyFoodCooldown(Food food, MonsterLib.Monster monster) internal view 
    {
        if(food.priceWei > 0)
        {
            return;
        }
        monster.foodCooldownEndTimestamp = uint64(now + freeFoodCooldown);
    }
    
    function checkFood(Food food, MonsterLib.Monster monster) internal view returns(bool)
    {
        //check monster can eat it
        if(!checkApplication(monster.level, monster.siringWithId, food.application))
        {
            return false;
        }
        
        //if it's free check free food cooldown
        if(food.priceWei == 0 && monster.foodCooldownEndTimestamp > now)
        {
            return false;
        }
        
        //if it's exclusively CDR food then check if we have an actionCooldown
        //otherwise there's no point in using it
        if(food.feedingScore == 0 && food.potionEffect == 0)
        {
            if(monster.cooldownEndTimestamp < now)
            {
                return false;
            }
        }
        
        //if the food is a potion then we require that previous potion has expired
        if(food.potionEffect > 0)
        {
            if(monster.potionExpire > now)
            {
                return false;
            }
        }
        
        return true;
    }
    
    function checkApplication(uint level, uint siringWithId, uint foodApplication) public pure returns(bool)
    {
        uint application;
        if(level == 0)
        {
            application = 1;
        }
        else if (siringWithId > 0)
        {
            application = 2;
        }
        else
        {
            application = 4;
        }
        
        return application & foodApplication > 0;
        
    }
    

    function getFood(uint256 _foodCode)
        external
        view
        returns (
        uint256 feedingScore,
        uint256 priceWei,
        uint256 cdReduction,
        uint256 application,
        uint256 potionEffect,
        bool exists
    ) {
        Food storage _food = codeToFoodIndex[uint16(_foodCode)];
        require(_food.exists);
        feedingScore = uint(_food.feedingScore);
        exists = _food.exists;
        priceWei = _food.priceWei;
        cdReduction = _food.cdReduction;
        application = _food.application;
        potionEffect = _food.potionEffect;
    }
    
    
    function deleteFood(uint _code) public onlyOwner {
        delete codeToFoodIndex[uint16(_code)];
        emit FoodDeleted(_code);
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
}
    
    
