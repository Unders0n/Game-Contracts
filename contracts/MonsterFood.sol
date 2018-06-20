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
    
    function setTokenContract(address _nftAddress) external onlyOwner
    {
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
    }
    
    //application bits by offset:
    //0 - cheeper
    //1 - cub
    //2 - mom
    //3 - mature (not mom)
    
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
    
    function feedMonster(address originalCaller, uint foodCode, uint generation, uint growScore, uint level, uint cooldowns, uint siringWithId, uint potionEffect) public payable
    returns(uint growScore_, uint level_, uint potionEffect_, uint cooldowns_)
    {
        require(originalCaller != address(0));
        Food storage _food = codeToFoodIndex[uint16(foodCode)];
        
        require(msg.value >= _food.priceWei);
        require(checkFood(_food, level, siringWithId, cooldowns));

        cooldowns_ = cooldowns;
        
        cooldowns_ = applyFoodCooldown(_food, cooldowns_);
        (level_, growScore_) = applyGrowScore(_food, level, generation, growScore);
        cooldowns_ = applyCDR(_food, cooldowns_);
        (potionEffect_, cooldowns_) = applyPotion(_food, cooldowns_, potionEffect);
    }
    
    function applyPotion(Food food, uint cooldowns, uint potionEffect) internal view returns(uint newPotionEffect, uint newCooldowns)
    {
        newPotionEffect = potionEffect;
        newCooldowns = cooldowns;
        
        if(food.potionEffect == 0)
        {
            return;
        }
        
        uint potionExpire = now + potionDuration;
        newCooldowns = MonsterLib.setBits(newCooldowns, potionExpire, 64, 64);
    }
    
    function applyCDR(Food food, uint cooldowns) internal pure returns(uint newCooldowns)
    {
        newCooldowns = cooldowns;
        if(food.cdReduction == 0)
        {
            return;
        }
        
        uint actionCooldown = uint64(MonsterLib.getBits(cooldowns, 0, 64));
        if(actionCooldown < food.cdReduction)
        {
            actionCooldown = 0;
        }
        else
        {
            actionCooldown -= food.cdReduction;
        }
        
        newCooldowns = MonsterLib.setBits(cooldowns, actionCooldown, 64, 0);
    }
    
    function applyGrowScore(Food food, uint level, uint generation, uint growScore) internal pure 
        returns(uint newLevel, uint newGrowScore)
    {
        newLevel = level;
        newGrowScore = growScore;
        
        if(food.feedingScore == 0)
        {
            return;
        }
        
        if(newLevel >= 2)
        {
            return;
        }
        
        uint reqiredScore = getLevelupScoreRequired(newLevel, generation);
        newGrowScore = growScore + food.feedingScore;
        
        if(newGrowScore >= reqiredScore)
        {
            newGrowScore = newGrowScore - reqiredScore;
            newLevel += 1;
        }
        
        if(newLevel < 2)
        {
            reqiredScore = getLevelupScoreRequired(newLevel, generation);
            if(newGrowScore >= reqiredScore)
            {
                newGrowScore = newGrowScore - reqiredScore;
                newLevel += 1;
            }
        }
    }
    
    function getLevelupScoreRequired(uint level, uint generation) public pure returns(uint)
    {
        if(level >= 2)
        {
            return 0;
        }
        
        if(generation > 13)
        {
            generation = 13;
        }
        
        uint divider = 1;
        if(level == 0)
        {
            divider = 35;
        }
        else if (level == 1)
        {
            divider = 25;
        }
        
        uint scoreRequired = uint(10) * generation * generation / divider + 1;
        return scoreRequired;
    }
    
    function applyFoodCooldown(Food food, uint cooldowns) internal view returns(uint newCooldowns)
    {
        newCooldowns = cooldowns;
        if(food.priceWei > 0)
        {
            return;
        }
        
        uint newFoodCooldown = now + freeFoodCooldown;
        newCooldowns = MonsterLib.setBits(newCooldowns, newFoodCooldown, 64, 128);
    }
    
    function checkFood(Food food, uint level, uint siringWithId, uint cooldowns) internal view returns(bool)
    {
        //check monster can eat it
        if(!checkApplication(level, siringWithId, food.application))
        {
            return false;
        }
        
        //if it's free check free food cooldown
        uint foodCooldownEndTimestamp = uint64(MonsterLib.getBits(cooldowns, 128, 64));
        if(food.priceWei == 0 && foodCooldownEndTimestamp > now)
        {
            return false;
        }
        
        //if it's exclusively CDR food then check if we have an actionCooldown
        //otherwise there's no point in using it
        if(food.feedingScore == 0 && food.potionEffect == 0)
        {
            uint actionCooldown = uint64(MonsterLib.getBits(cooldowns, 0, 64));
            if(actionCooldown < now)
            {
                return false;
            }
        }
        
        //if the food is a potion then we require that previous potion has expired
        if(food.potionEffect > 0)
        {
            uint potionExpire = uint64(MonsterLib.getBits(cooldowns, 64, 64));
            if(potionExpire > now)
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
        else if(level == 1)
        {
            application = 2;
        }
        else if (siringWithId > 0)
        {
            application = 4;
        }
        else
        {
            application = 8;
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
    
    
