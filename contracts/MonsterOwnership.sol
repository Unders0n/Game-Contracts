pragma solidity ^0.4.23;

import "./MonsterBase.sol";
import "./ERC721.sol";
import "./ERC721Metadata.sol";

/// @title The facet of the MonsterBit core contract that manages ownership, ERC-721 (draft) compliant.
/// @dev Ref: https://github.com/ethereum/EIPs/issues/721
///  See the MonsterCore contract documentation to understand how the various contract facets are arranged.
contract MonsterOwnership is MonsterBase, ERC721 {

    /// @notice Name and symbol of the non fungible token, as defined in ERC721.
    string public constant name = "MonsterBit";
    string public constant symbol = "MB";

    /// @dev Checks if a given address is the current owner of a particular Monster.
    /// @param _claimant the address we are validating against.
    /// @param _tokenId monster id, only valid when > 0
    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return monsterStorage.monsterIndexToOwner(_tokenId) == _claimant;
    }

    /// @dev Checks if a given address currently has transferApproval for a particular Monster.
    /// @param _claimant the address we are confirming monster is approved for.
    /// @param _tokenId monster id, only valid when > 0
    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return monsterStorage.monsterIndexToApproved(_tokenId) == _claimant;
    }

    /// @dev Marks an address as being approved for transferFrom(), overwriting any previous
    ///  approval. Setting _approved to address(0) clears all transfer approval.
    ///  NOTE: _approve() does NOT send the Approval event. This is intentional because
    ///  _approve() and transferFrom() are used together for putting Monsters on auction, and
    ///  there is no value in spamming the log with Approval events in that case.
    function _approve(uint256 _tokenId, address _approved) internal {
        monsterStorage.setMonsterIndexToApproved(_tokenId, _approved);
    }

    /// @notice Returns the number of Monsters owned by a specific address.
    /// @param _owner The owner address to check.
    /// @dev Required for ERC-721 compliance
    function balanceOf(address _owner) public view returns (uint256 count) {
        return monsterStorage.ownershipTokenCount(_owner);
    }

    /// @notice Transfers a Monster to another address. If transferring to a smart
    ///  contract be VERY CAREFUL to ensure that it is aware of ERC-721 (or
    ///  MonsterBit specifically) or your Monster may be lost forever. Seriously.
    /// @param _to The address of the recipient, can be a user or contract.
    /// @param _tokenId The ID of the Monster to transfer.
    /// @dev Required for ERC-721 compliance.
    function transfer(
        address _to,
        uint256 _tokenId
    )
        external
        whenNotPaused
    {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        // Disallow transfers to this contract to prevent accidental misuse.
        // The contract should never own any monsters (except very briefly
        // after a gen0 monster is created and before it goes on auction).
        require(_to != address(this));
        // Disallow transfers to the auction contracts to prevent accidental
        // misuse. Auction contracts should only take ownership of monsters
        // through the allow + transferFrom flow.
        require(_to != address(saleAuction));

        // You can only send your own monster.
        require(_owns(msg.sender, _tokenId));

        // Reassign ownership, clear pending approvals, emit Transfer event.
        _transfer(msg.sender, _to, _tokenId);
    }

    /// @notice Grant another address the right to transfer a specific Monster via
    ///  transferFrom(). This is the preferred flow for transfering NFTs to contracts.
    /// @param _to The address to be granted transfer approval. Pass address(0) to
    ///  clear all approvals.
    /// @param _tokenId The ID of the Monster that can be transferred if this call succeeds.
    /// @dev Required for ERC-721 compliance.
    function approve(
        address _to,
        uint256 _tokenId
    )
        external
        whenNotPaused
    {
        // Only an owner can grant transfer approval.
        require(_owns(msg.sender, _tokenId));

        // Register the approval (replacing any previous approval).
        _approve(_tokenId, _to);

        // Emit approval event.
        emit Approval(msg.sender, _to, _tokenId);
    }

    /// @notice Transfer a Monster owned by another address, for which the calling address
    ///  has previously been granted transfer approval by the owner.
    /// @param _from The address that owns the Monster to be transfered.
    /// @param _to The address that should take ownership of the Monster. Can be any address,
    ///  including the caller.
    /// @param _tokenId The ID of the Monster to be transferred.
    /// @dev Required for ERC-721 compliance.
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    )
        external
        whenNotPaused
    {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        // Disallow transfers to this contract to prevent accidental misuse.
        // The contract should never own any monsters (except very briefly
        // after a gen0 monster is created and before it goes on auction).
        require(_to != address(this));
        // Check for approval and valid ownership
        require(_approvedFor(msg.sender, _tokenId));
        require(_owns(_from, _tokenId));

        // Reassign ownership (also clears pending approvals and emits Transfer event).
        _transfer(_from, _to, _tokenId);
    }

    /// @notice Returns the total number of Monsters currently in existence.
    /// @dev Required for ERC-721 compliance.
    function totalSupply() public view returns (uint) {
        return monsterStorage.getMonstersCount() - 1;
    }

    /// @notice Returns the address currently assigned ownership of a given Monster.
    /// @dev Required for ERC-721 compliance.
    function ownerOf(uint256 _tokenId)
        external
        view
        returns (address owner)
    {
        owner = monsterStorage.monsterIndexToOwner(_tokenId);

        require(owner != address(0));
    }

    /// @notice Returns a list of all Monster IDs assigned to an address.
    /// @param _owner The owner whose Monsters we are interested in.
    /// @dev This method MUST NEVER be called by smart contract code. First, it's fairly
    ///  expensive (it walks the entire Monster array looking for monsters belonging to owner),
    ///  but it also returns a dynamic array, which is only supported for web3 calls, and
    ///  not contract-to-contract calls.
    function tokensOfOwner(address _owner) external view returns(uint256[] ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalMonsters = totalSupply();
            uint256 resultIndex = 0;

            // We count on the fact that all monsters have IDs starting at 1 and increasing
            // sequentially up to the totalMonsters count.
            uint256 monsterId;

            for (monsterId = 1; monsterId <= totalMonsters; monsterId++) {
                if (monsterStorage.monsterIndexToOwner(monsterId) == _owner) {
                    result[resultIndex] = monsterId;
                    resultIndex++;
                }
            }

            return result;
        }
    }

 
}