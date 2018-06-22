pragma solidity ^0.4.23;

import "./MonsterOwnership.sol";
import "./MonsterGeneticsInterface.sol";


/// @title A facet of MosterBitCore that manages Monster siring, gestation, and birth.
contract MonsterBreeding is MonsterOwnership {

    /// @dev The Pregnant event is fired when two monster successfully breed and the pregnancy
    ///  timer begins for the matron.
    event Pregnant(address owner, uint256 matronId, uint256 sireId, uint256 cooldownEndTimestamp);

    /// @notice The minimum payment required to use breedWithAuto(). This fee goes towards
    ///  the gas cost paid by whatever calls giveBirth(), and can be dynamically updated by
    ///  the COO role as the gas price changes.
    uint256 public autoBirthFee = 2 finney;
    
    

    

    /// @dev Update the address of the genetic contract, can only be called by the CEO.
    /// @param _address An address of a GeneScience contract instance to be used from this point forward.
    function setGeneScienceAddress(address _address) external onlyCEO {
        MonsterGeneticsInterface candidateContract = MonsterGeneticsInterface(_address);

        // NOTE: verify that a contract is what we expect
        require(candidateContract.isMonsterGenetics());

        // Set the new contract address
        geneScience = candidateContract;
    }
    
    function setSiringAuctionAddress(address _address) external onlyCEO {
        SiringClockAuction candidateContract = SiringClockAuction(_address);

        // NOTE: verify that a contract is what we expect - https://github.com/Lunyr/crowdsale-contracts/blob/cfadd15986c30521d8ba7d5b6f57b4fefcc7ac38/contracts/LunyrToken.sol#L117
        require(candidateContract.isSiringClockAuction());

        // Set the new contract address
        siringAuction = candidateContract;
    }

    /// @dev Checks that a given monster is able to breed. Requires that the
    ///  current cooldown is finished (for sires) and also checks that there is
    ///  no pending pregnancy.
    function _isReadyToBreed(MonsterLib.Monster _monster) internal view returns (bool) {
        // In addition to checking the cooldownEndTimestamp, we also need to check to see if
        // the cat has a pending birth; there can be some period of time between the end
        // of the pregnacy timer and the birth event.
        return (_monster.siringWithId == 0) && (_monster.cooldownEndTimestamp <= uint64(now) && (_monster.level > 1));
    }

    /// @dev Check if a sire has authorized breeding with this matron. True if both sire
    ///  and matron have the same owner, or if the sire has given siring permission to
    ///  the matron's owner (via approveSiring()).
    function _isSiringPermitted(uint256 _sireId, uint256 _matronId) internal view returns (bool) {
        address matronOwner = monsterStorage.monsterIndexToOwner(_matronId);
        address sireOwner = monsterStorage.monsterIndexToOwner(_sireId);

        // Siring is okay if they have same owner, or if the matron's owner was given
        // permission to breed with this sire.
        return (matronOwner == sireOwner || monsterStorage.sireAllowedToAddress(_sireId) == matronOwner);
    }

    /// @dev Set the cooldownEndTime for the given monster, based on its current cooldownIndex.
    ///  Also increments the cooldownIndex (unless it has hit the cap).
    /// @param _monster A reference to the monster in storage which needs its timer started.
    function _triggerCooldown(uint monsterId, MonsterLib.Monster memory _monster, uint increaseIndex) internal {

        uint cooldownEndTimestamp = uint64(actionCooldowns[_monster.cooldownIndex] + now);
        uint newCooldownIndex = _monster.cooldownIndex;
        // Increment the breeding count, clamping it at 13, which is the length of the
        // cooldowns array. We could check the array size dynamically, but hard-coding
        // this as a constant saves gas. Yay, Solidity!
        if(increaseIndex > 0)
        {
            if (newCooldownIndex < 13) {
                newCooldownIndex += 1;
            }
        }
        
        monsterStorage.setActionCooldown(monsterId, newCooldownIndex, cooldownEndTimestamp);
    }
    
    uint32[14] public actionCooldowns = [
        uint32(1 minutes),
        uint32(2 minutes),
        uint32(5 minutes),
        uint32(10 minutes),
        uint32(30 minutes),
        uint32(1 hours),
        uint32(2 hours),
        uint32(4 hours),
        uint32(8 hours),
        uint32(16 hours),
        uint32(1 days),
        uint32(2 days),
        uint32(4 days),
        uint32(7 days)
    ];

    /// @notice Grants approval to another user to sire with one of your monsters.
    /// @param _addr The address that will be able to sire with your monster. Set to
    ///  address(0) to clear all siring approvals for this monster.
    /// @param _sireId A monster that you own that _addr will now be able to sire with.
    function approveSiring(address _addr, uint256 _sireId)
        external
        whenNotPaused
    {
        require(_owns(msg.sender, _sireId));
        monsterStorage.setSireAllowedToAddress(_sireId, _addr);
    }

    /// @dev Updates the minimum payment required for calling giveBirthAuto(). Can only
    ///  be called by the COO address. (This fee is used to offset the gas cost incurred
    ///  by the autobirth daemon).
    function setAutoBirthFee(uint256 val) external onlyCOO {
        autoBirthFee = val;
    }

    /// @dev Checks to see if a given monster is pregnant and (if so) if the gestation
    ///  period has passed.
    function _isReadyToGiveBirth(MonsterLib.Monster _matron) private view returns (bool) {
        return (_matron.siringWithId != 0) && (_matron.cooldownEndTimestamp <= now);
    }

    /// @notice Checks that a given monster is able to breed (i.e. it is not pregnant or
    ///  in the middle of a siring cooldown).
    /// @param _monsterId reference the id of the monster, any user can inquire about it
    function isReadyToBreed(uint256 _monsterId)
        public
        view
        returns (bool)
    {
        require(_monsterId > 0);
        MonsterLib.Monster memory monster = readMonster(_monsterId);
        return _isReadyToBreed(monster);
    }

    /// @dev Checks whether a monster is currently pregnant.
    /// @param _monsterId reference the id of the monster, any user can inquire about it
    function isPregnant(uint256 _monsterId)
        public
        view
        returns (bool)
    {
        require(_monsterId > 0);
        // A monster is pregnant if and only if this field is set
        MonsterLib.Monster memory monster = readMonster(_monsterId);
        return monster.siringWithId != 0;
    }

    /// @dev Internal check to see if a given sire and matron are a valid mating pair. DOES NOT
    ///  check ownership permissions (that is up to the caller).
    /// @param _matron A reference to the monster struct of the potential matron.
    /// @param _matronId The matron's ID.
    /// @param _sire A reference to the monster struct of the potential sire.
    /// @param _sireId The sire's ID
    function _isValidMatingPair(
        MonsterLib.Monster _matron,
        uint256 _matronId,
        MonsterLib.Monster _sire,
        uint256 _sireId
    )
        private
        pure
        returns(bool)
    {
        // A monster can't breed with itself!
        if (_matronId == _sireId) {
            return false;
        }

        // monsters can't breed with their parents.
        if (_matron.matronId == _sireId || _matron.sireId == _sireId) {
            return false;
        }
        if (_sire.matronId == _matronId || _sire.sireId == _matronId) {
            return false;
        }

        // We can short circuit the sibling check (below) if either cat is
        // gen zero (has a matron ID of zero).
        if (_sire.matronId == 0 || _matron.matronId == 0) {
            return true;
        }

        // monster can't breed with full or half siblings.
        if (_sire.matronId == _matron.matronId || _sire.matronId == _matron.sireId) {
            return false;
        }
        if (_sire.sireId == _matron.matronId || _sire.sireId == _matron.sireId) {
            return false;
        }

        // Everything seems cool! Let's get DTF.
        return true;
    }

    /// @dev Internal check to see if a given sire and matron are a valid mating pair for
    ///  breeding via auction (i.e. skips ownership and siring approval checks).
    function _canBreedWithViaAuction(uint256 _matronId, uint256 _sireId)
        internal
        view
        returns (bool)
    {
        MonsterLib.Monster memory matron = readMonster(_matronId);
        MonsterLib.Monster memory sire = readMonster(_sireId);
        return _isValidMatingPair(matron, _matronId, sire, _sireId);
    }

    /// @notice Checks to see if two monsters can breed together, including checks for
    ///  ownership and siring approvals. Does NOT check that both cats are ready for
    ///  breeding (i.e. breedWith could still fail until the cooldowns are finished).
    /// @param _matronId The ID of the proposed matron.
    /// @param _sireId The ID of the proposed sire.
    function canBreedWith(uint256 _matronId, uint256 _sireId)
        external
        view
        returns(bool)
    {
        require(_matronId > 0);
        require(_sireId > 0);
        MonsterLib.Monster memory matron = readMonster(_matronId);
        MonsterLib.Monster memory sire = readMonster(_sireId);
        return _isValidMatingPair(matron, _matronId, sire, _sireId) &&
            _isSiringPermitted(_sireId, _matronId);
    }

    /// @dev Internal utility function to initiate breeding, assumes that all breeding
    ///  requirements have been checked.
    function _breedWith(uint256 _matronId, uint256 _sireId) internal {
        // Grab a reference to the Kitties from storage.
        MonsterLib.Monster memory sire = readMonster(_sireId);
        MonsterLib.Monster memory matron = readMonster(_matronId);

        // Mark the matron as pregnant, keeping track of who the sire is.
        monsterStorage.setSiringWith(_matronId, _sireId);
        

        // Trigger the cooldown for both parents.
        _triggerCooldown(_sireId, sire, 1);
        _triggerCooldown(_matronId, matron, 1);

        // Clear siring permission for both parents. This may not be strictly necessary
        // but it's likely to avoid confusion!
        monsterStorage.setSireAllowedToAddress(_matronId, address(0));
        monsterStorage.setSireAllowedToAddress(_sireId, address(0));

        uint pregnantMonsters = monsterStorage.pregnantMonsters();
        monsterStorage.setPregnantMonsters(pregnantMonsters + 1);

        // Emit the pregnancy event.
        emit Pregnant(monsterStorage.monsterIndexToOwner(_matronId), _matronId, _sireId, matron.cooldownEndTimestamp);
    }

    /// @notice Breed a monster you own (as matron) with a sire that you own, or for which you
    ///  have previously been given Siring approval. Will either make your monster pregnant, or will
    ///  fail entirely. Requires a pre-payment of the fee given out to the first caller of giveBirth()
    /// @param _matronId The ID of the monster acting as matron (will end up pregnant if successful)
    /// @param _sireId The ID of the monster acting as sire (will begin its siring cooldown if successful)
    function breedWithAuto(uint256 _matronId, uint256 _sireId)
        external
        payable
        whenNotPaused
    {
        // Checks for payment.
        require(msg.value >= autoBirthFee);

        // Caller must own the matron.
        require(_owns(msg.sender, _matronId));

        // Neither sire nor matron are allowed to be on auction during a normal
        // breeding operation, but we don't need to check that explicitly.
        // For matron: The caller of this function can't be the owner of the matron
        //   because the owner of a Kitty on auction is the auction house, and the
        //   auction house will never call breedWith().
        // For sire: Similarly, a sire on auction will be owned by the auction house
        //   and the act of transferring ownership will have cleared any oustanding
        //   siring approval.
        // Thus we don't need to spend gas explicitly checking to see if either cat
        // is on auction.

        // Check that matron and sire are both owned by caller, or that the sire
        // has given siring permission to caller (i.e. matron's owner).
        // Will fail for _sireId = 0
        require(_isSiringPermitted(_sireId, _matronId));

        // Grab a reference to the potential matron
        MonsterLib.Monster memory matron = readMonster(_matronId);

        // Make sure matron isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToBreed(matron));

        // Grab a reference to the potential sire
        MonsterLib.Monster memory sire = readMonster(_sireId);

        // Make sure sire isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToBreed(sire));

        // Test that these cats are a valid mating pair.
        require(_isValidMatingPair(
            matron,
            _matronId,
            sire,
            _sireId
        ));

        // All checks passed, kitty gets pregnant!
        _breedWith(_matronId, _sireId);
    }

    /// @notice Have a pregnant monster give birth!
    /// @param _matronId A monster ready to give birth.
    /// @return The monster ID of the new monster.
    /// @dev Looks at a given monster and, if pregnant and if the gestation period has passed,
    ///  combines the genes of the two parents to create a new monster. The new monster is assigned
    ///  to the current owner of the matron. Upon successful completion, both the matron and the
    ///  new monster will be ready to breed again. Note that anyone can call this function (if they
    ///  are willing to pay the gas!), but the new monster always goes to the mother's owner.
    function giveBirth(uint256 _matronId)
        external
        whenNotPaused
        returns(uint256)
    {
        // Grab a reference to the matron in storage.
        MonsterLib.Monster memory matron = readMonster(_matronId);

        // Check that the matron is a valid cat.
        require(matron.birthTime != 0);

        // Check that the matron is pregnant, and that its time has come!
        require(_isReadyToGiveBirth(matron));

        // Grab a reference to the sire in storage.
        uint256 sireId = matron.siringWithId;
        MonsterLib.Monster memory sire = readMonster(sireId);

        // Determine the higher generation number of the two parents
        uint16 parentGen = matron.generation;
        if (sire.generation > matron.generation) {
            parentGen = sire.generation;
        }

        // Call the sooper-sekret gene mixing operation.
        uint256 childGenes = geneScience.mixGenes(matron.genes, sire.genes, block.number - 1);
        uint256 childBattleGenes = geneScience.mixBattleGenes(matron.battleGenes, sire.battleGenes, block.number - 1);

        // Make the new kitten!
        address owner = monsterStorage.monsterIndexToOwner(_matronId);
        uint256 monsterId = _createMonster(_matronId, matron.siringWithId, parentGen + 1, childGenes, childBattleGenes, 0, owner);

        // Clear the reference to sire from the matron (REQUIRED! Having siringWithId
        // set is what marks a matron as being pregnant.)
        monsterStorage.setSiringWith(_matronId, 0);

        uint pregnantMonsters = monsterStorage.pregnantMonsters();
        monsterStorage.setPregnantMonsters(pregnantMonsters - 1);

        
        // Send the balance fee to the person who made birth happen.
        msg.sender.transfer(autoBirthFee);

        // return the new kitten's ID
        return monsterId;
    }
}