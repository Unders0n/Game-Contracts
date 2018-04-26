pragma solidity ^0.4.11;

import "./MonsterBitSaleAuction.sol";


/// @title A facet of MonsterCore that manages special access privileges.
/// @dev See the MonsterCore contract documentation to understand how the various contract facets are arranged.
contract AccessControl {
    // This facet controls access control for MonsterBit. There are four roles managed here:
    //
    //     - The CEO: The CEO can reassign other roles and change the addresses of our dependent smart
    //         contracts. It is also the only role that can unpause the smart contract. It is initially
    //         set to the address that created the smart contract in the MonsterCore constructor.
    //
    //     - The CFO: The CFO can withdraw funds from MonsterCore and its auction contracts.
    //
    //     - The COO: The COO can release gen0 monsters to auction, and mint promo monsters.
    //
    // It should be noted that these roles are distinct without overlap in their access abilities, the
    // abilities listed for each role above are exhaustive. In particular, while the CEO can assign any
    // address to any role, the CEO address itself doesn't have the ability to act in those roles. This
    // restriction is intentional so that we aren't tempted to use the CEO address frequently out of
    // convenience. The less we use an address, the less likely it is that we somehow compromise the
    // account.

    /// @dev Emited when contract is upgraded - See README.md for updgrade plan
    event ContractUpgrade(address newContract);

    // The addresses of the accounts (or contracts) that can execute actions within each roles.
    address public ceoAddress;
    address public cfoAddress;
    address public cooAddress;

    // @dev Keeps track whether the contract is paused. When that is true, most actions are blocked
    bool public paused = false;

    /// @dev Access modifier for CEO-only functionality
    modifier onlyCEO() {
        require(msg.sender == ceoAddress);
        _;
    }

    /// @dev Access modifier for CFO-only functionality
    modifier onlyCFO() {
        require(msg.sender == cfoAddress);
        _;
    }

    /// @dev Access modifier for COO-only functionality
    modifier onlyCOO() {
        require(msg.sender == cooAddress);
        _;
    }

    modifier onlyCLevel() {
        require(
            msg.sender == cooAddress ||
            msg.sender == ceoAddress ||
            msg.sender == cfoAddress
        );
        _;
    }

    /// @dev Assigns a new address to act as the CEO. Only available to the current CEO.
    /// @param _newCEO The address of the new CEO
    function setCEO(address _newCEO) external onlyCEO {
        require(_newCEO != address(0));

        ceoAddress = _newCEO;
    }

    /// @dev Assigns a new address to act as the CFO. Only available to the current CEO.
    /// @param _newCFO The address of the new CFO
    function setCFO(address _newCFO) external onlyCEO {
        require(_newCFO != address(0));

        cfoAddress = _newCFO;
    }

    /// @dev Assigns a new address to act as the COO. Only available to the current CEO.
    /// @param _newCOO The address of the new COO
    function setCOO(address _newCOO) external onlyCEO {
        require(_newCOO != address(0));

        cooAddress = _newCOO;
    }

    /*** Pausable functionality adapted from OpenZeppelin ***/

    /// @dev Modifier to allow actions only when the contract IS NOT paused
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /// @dev Modifier to allow actions only when the contract IS paused
    modifier whenPaused {
        require(paused);
        _;
    }

    /// @dev Called by any "C-level" role to pause the contract. Used only when
    ///  a bug or exploit is detected and we need to limit damage.
    function pause() external onlyCLevel whenNotPaused {
        paused = true;
    }

    /// @dev Unpauses the smart contract. Can only be called by the CEO, since
    ///  one reason we may pause the contract is when CFO or COO accounts are
    ///  compromised.
    /// @notice This is public rather than external so it can be called by
    ///  derived contracts.
    function unpause() public onlyCEO whenPaused {
        // can't unpause if contract was upgraded
        paused = false;
    }
}




/// @title Base contract for MonsterBit. Holds all common structs, events and base variables.
/// @dev See the MonsterCore contract documentation to understand how the various contract facets are arranged.
contract MonsterBase is AccessControl {
    /*** EVENTS ***/

    /// @dev The Birth event is fired whenever a new monster comes into existence. This obviously
    ///  includes any time a monster is created through the giveBirth method, but it is also called
    ///  when a new gen0 monster is created.
    event Birth(address owner, uint256 monsterId, uint256 genes);

    /// @dev Transfer event as defined in current draft of ERC721. Emitted every time a monster
    ///  ownership is assigned, including births.
    event Transfer(address from, address to, uint256 tokenId);

    /*** DATA TYPES ***/

    /// @dev The main Monster struct. Every monster in MonsterBit is represented by a copy
    ///  of this structure, so great care was taken to ensure that it fits neatly into
    ///  exactly two 256-bit words. Note that the order of the members in this structure
    ///  is important because of the byte-packing rules used by Ethereum.
    ///  Ref: http://solidity.readthedocs.io/en/develop/miscellaneous.html
    struct Monster {
        // The Monster's genetic code is packed into these 256-bits, the format is
        // sooper-sekret! A monster's genes never change.
        uint256 genes;
        
        // The timestamp from the block when this monster came into existence.
        uint64 birthTime;
        
        // The "generation number" of this monster. Monsters minted by the CK contract
        // for sale are called "gen0" and have a generation number of 0. The
        // generation number of all other monsters is the larger of the two generation
        // numbers of their parents, plus one.
        // (i.e. max(matron.generation, sire.generation) + 1)
        uint16 generation;
    }


    // An approximation of currently how many seconds are in between blocks.
    uint256 public secondsPerBlock = 15;

    /*** STORAGE ***/

    /// @dev An array containing the Monster struct for all Monsters in existence. The ID
    ///  of each monster is actually an index into this array. Note that ID 0 is a negamonster,
    ///  the unMonster, the mythical beast that is the parent of all gen0 monsters. A bizarre
    ///  creature that is both matron and sire... to itself! Has an invalid genetic code.
    ///  In other words, monster ID 0 is invalid... ;-)
    Monster[] monsters;

    /// @dev A mapping from monster IDs to the address that owns them. All monsters have
    ///  some valid owner address, even gen0 monsters are created with a non-zero owner.
    mapping (uint256 => address) public monsterIndexToOwner;

    // @dev A mapping from owner address to count of tokens that address owns.
    //  Used internally inside balanceOf() to resolve ownership count.
    mapping (address => uint256) ownershipTokenCount;

    /// @dev A mapping from MonsterIDs to an address that has been approved to call
    ///  transferFrom(). Each Monster can only have one approved address for transfer
    ///  at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public monsterIndexToApproved;

    /// @dev The address of the ClockAuction contract that handles sales of Monsters. This
    ///  same contract handles both peer-to-peer sales as well as the gen0 sales which are
    ///  initiated every 15 minutes.
    SaleClockAuction public saleAuction;


    /// @dev Assigns ownership of a specific Monster to an address.
    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        // Since the number of monsters is capped to 2^32 we can't overflow this
        ownershipTokenCount[_to]++;
        // transfer ownership
        monsterIndexToOwner[_tokenId] = _to;
        // When creating new monsters _from is 0x0, but we can't account that address.
        if (_from != address(0)) {
            ownershipTokenCount[_from]--;
            // clear any previously approved ownership exchange
            delete monsterIndexToApproved[_tokenId];
        }
        // Emit the transfer event.
        Transfer(_from, _to, _tokenId);
    }

    /// @dev An internal method that creates a new monster and stores it. This
    ///  method doesn't do any checking and should only be called when the
    ///  input data is known to be valid. Will generate both a Birth event
    ///  and a Transfer event.
    /// @param _generation The generation number of this monster, must be computed by caller.
    /// @param _genes The monster's genetic code.
    /// @param _owner The inital owner of this monster, must be non-zero (except for the unMonster, ID 0)
    function _createMonster(
        uint256 _generation,
        uint256 _genes,
        address _owner
    )
        internal
        returns (uint)
    {
        // These requires are not strictly necessary, our calling code should make
        // sure that these conditions are never broken. However! _createMonster() is already
        // an expensive call (for storage), and it doesn't hurt to be especially careful
        // to ensure our data structures are always valid.
        require(_generation == uint256(uint16(_generation)));

        // New monster starts with the same cooldown as parent gen/2
        uint16 cooldownIndex = uint16(_generation / 2);
        if (cooldownIndex > 13) {
            cooldownIndex = 13;
        }

        Monster memory _monster = Monster({
            genes: _genes,
            birthTime: uint64(now),
            generation: uint16(_generation)
        });
        uint256 newMonsterId = monsters.push(_monster) - 1;

        // It's probably never going to happen, 4 billion monsters is A LOT, but
        // let's just be 100% sure we never let this happen.
        require(newMonsterId == uint256(uint32(newMonsterId)));

        // emit the birth event
        Birth(
            _owner,
            newMonsterId,
            _monster.genes
        );

        // This will assign ownership, and also emit the Transfer event as
        // per ERC721 draft
        _transfer(0, _owner, newMonsterId);

        return newMonsterId;
    }

}




/// @title The external contract that is responsible for generating metadata for the monsters,
///  it has one function that will return the data as bytes.
contract ERC721Metadata {
    /// @dev Given a token Id, returns a byte array that is supposed to be converted into string.
    function getMetadata(uint256 _tokenId, string) public view returns (bytes32[4] buffer, uint256 count) {
        if (_tokenId == 1) {
            buffer[0] = "Hello World! :D";
            count = 15;
        } else if (_tokenId == 2) {
            buffer[0] = "I would definitely choose a medi";
            buffer[1] = "um length string.";
            count = 49;
        } else if (_tokenId == 3) {
            buffer[0] = "Lorem ipsum dolor sit amet, mi e";
            buffer[1] = "st accumsan dapibus augue lorem,";
            buffer[2] = " tristique vestibulum id, libero";
            buffer[3] = " suscipit varius sapien aliquam.";
            count = 128;
        }
    }
}




/// @title The facet of the MonsterBit core contract that manages ownership, ERC-721 (draft) compliant.
/// @dev Ref: https://github.com/ethereum/EIPs/issues/721
///  See the MonsterCore contract documentation to understand how the various contract facets are arranged.
contract MonsterOwnership is MonsterBase, ERC721 {

    /// @notice Name and symbol of the non fungible token, as defined in ERC721.
    string public constant name = "MonsterBit";
    string public constant symbol = "MB";

    // The contract that will return monster metadata
    ERC721Metadata public erc721Metadata;

    bytes4 constant InterfaceSignature_ERC165 =
        bytes4(keccak256('supportsInterface(bytes4)'));

    bytes4 constant InterfaceSignature_ERC721 =
        bytes4(keccak256('name()')) ^
        bytes4(keccak256('symbol()')) ^
        bytes4(keccak256('totalSupply()')) ^
        bytes4(keccak256('balanceOf(address)')) ^
        bytes4(keccak256('ownerOf(uint256)')) ^
        bytes4(keccak256('approve(address,uint256)')) ^
        bytes4(keccak256('transfer(address,uint256)')) ^
        bytes4(keccak256('transferFrom(address,address,uint256)')) ^
        bytes4(keccak256('tokensOfOwner(address)')) ^
        bytes4(keccak256('tokenMetadata(uint256,string)'));

    /// @notice Introspection interface as per ERC-165 (https://github.com/ethereum/EIPs/issues/165).
    ///  Returns true for any standardized interfaces implemented by this contract. We implement
    ///  ERC-165 (obviously!) and ERC-721.
    function supportsInterface(bytes4 _interfaceID) external view returns (bool)
    {
        // DEBUG ONLY
        //require((InterfaceSignature_ERC165 == 0x01ffc9a7) && (InterfaceSignature_ERC721 == 0x9a20483d));

        return ((_interfaceID == InterfaceSignature_ERC165) || (_interfaceID == InterfaceSignature_ERC721));
    }

    /// @dev Set the address of the sibling contract that tracks metadata.
    ///  CEO only.
    function setMetadataAddress(address _contractAddress) public onlyCEO {
        erc721Metadata = ERC721Metadata(_contractAddress);
    }

    // Internal utility functions: These functions all assume that their input arguments
    // are valid. We leave it to public methods to sanitize their inputs and follow
    // the required logic.

    /// @dev Checks if a given address is the current owner of a particular Monster.
    /// @param _claimant the address we are validating against.
    /// @param _tokenId monster id, only valid when > 0
    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return monsterIndexToOwner[_tokenId] == _claimant;
    }

    /// @dev Checks if a given address currently has transferApproval for a particular Monster.
    /// @param _claimant the address we are confirming monster is approved for.
    /// @param _tokenId monster id, only valid when > 0
    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return monsterIndexToApproved[_tokenId] == _claimant;
    }

    /// @dev Marks an address as being approved for transferFrom(), overwriting any previous
    ///  approval. Setting _approved to address(0) clears all transfer approval.
    ///  NOTE: _approve() does NOT send the Approval event. This is intentional because
    ///  _approve() and transferFrom() are used together for putting Monsters on auction, and
    ///  there is no value in spamming the log with Approval events in that case.
    function _approve(uint256 _tokenId, address _approved) internal {
        monsterIndexToApproved[_tokenId] = _approved;
    }

    /// @notice Returns the number of Monsters owned by a specific address.
    /// @param _owner The owner address to check.
    /// @dev Required for ERC-721 compliance
    function balanceOf(address _owner) public view returns (uint256 count) {
        return ownershipTokenCount[_owner];
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
        Approval(msg.sender, _to, _tokenId);
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
        return monsters.length - 1;
    }

    /// @notice Returns the address currently assigned ownership of a given Monster.
    /// @dev Required for ERC-721 compliance.
    function ownerOf(uint256 _tokenId)
        external
        view
        returns (address owner)
    {
        owner = monsterIndexToOwner[_tokenId];

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
                if (monsterIndexToOwner[monsterId] == _owner) {
                    result[resultIndex] = monsterId;
                    resultIndex++;
                }
            }

            return result;
        }
    }

    /// @dev Adapted from memcpy() by @arachnid (Nick Johnson <arachnid@notdot.net>)
    ///  This method is licenced under the Apache License.
    ///  Ref: https://github.com/Arachnid/solidity-stringutils/blob/2f6ca9accb48ae14c66f1437ec50ed19a0616f78/strings.sol
    function _memcpy(uint _dest, uint _src, uint _len) private view {
        // Copy word-length chunks while possible
        for(; _len >= 32; _len -= 32) {
            assembly {
                mstore(_dest, mload(_src))
            }
            _dest += 32;
            _src += 32;
        }

        // Copy remaining bytes
        uint256 mask = 256 ** (32 - _len) - 1;
        assembly {
            let srcpart := and(mload(_src), not(mask))
            let destpart := and(mload(_dest), mask)
            mstore(_dest, or(destpart, srcpart))
        }
    }

    /// @dev Adapted from toString(slice) by @arachnid (Nick Johnson <arachnid@notdot.net>)
    ///  This method is licenced under the Apache License.
    ///  Ref: https://github.com/Arachnid/solidity-stringutils/blob/2f6ca9accb48ae14c66f1437ec50ed19a0616f78/strings.sol
    function _toString(bytes32[4] _rawBytes, uint256 _stringLength) private view returns (string) {
        var outputString = new string(_stringLength);
        uint256 outputPtr;
        uint256 bytesPtr;

        assembly {
            outputPtr := add(outputString, 32)
            bytesPtr := _rawBytes
        }

        _memcpy(outputPtr, bytesPtr, _stringLength);

        return outputString;
    }

    /// @notice Returns a URI pointing to a metadata package for this token conforming to
    ///  ERC-721 (https://github.com/ethereum/EIPs/issues/721)
    /// @param _tokenId The ID number of the Monster whose metadata should be returned.
    function tokenMetadata(uint256 _tokenId, string _preferredTransport) external view returns (string infoUrl) {
        require(erc721Metadata != address(0));
        bytes32[4] memory buffer;
        uint256 count;
        (buffer, count) = erc721Metadata.getMetadata(_tokenId, _preferredTransport);

        return _toString(buffer, count);
    }
}




/// @title Handles creating auctions for sale and siring of monsters.
///  This wrapper of ReverseAuction exists only so that users can create
///  auctions with only one transaction.
contract MonsterAuction is MonsterOwnership {

    // @notice The auction contract variables are defined in MonsterBase to allow
    //  us to refer to them in MonsterOwnership to prevent accidental transfers.
    // `saleAuction` refers to the auction for gen0 and p2p sale of monsters.
    // `siringAuction` refers to the auction for siring rights of monsters.

    /// @dev Sets the reference to the sale auction.
    /// @param _address - Address of sale contract.
    function setSaleAuctionAddress(address _address) external onlyCEO {
        SaleClockAuction candidateContract = SaleClockAuction(_address);

        // NOTE: verify that a contract is what we expect - https://github.com/Lunyr/crowdsale-contracts/blob/cfadd15986c30521d8ba7d5b6f57b4fefcc7ac38/contracts/LunyrToken.sol#L117
        require(candidateContract.isSaleClockAuction());

        // Set the new contract address
        saleAuction = candidateContract;
    }


    /// @dev Put a monster up for auction.
    ///  Does some ownership trickery to create auctions in one tx.
    function createSaleAuction(
        uint256 _monsterId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration
    )
        external
        whenNotPaused
    {
        // Auction contract checks input sizes
        // If monster is already on any auction, this will throw
        // because it will be owned by the auction contract.
        require(_owns(msg.sender, _monsterId));
        // Ensure the monster is not pregnant to prevent the auction
        // contract accidentally receiving ownership of the child.
        // NOTE: the monster IS allowed to be in a cooldown.
        _approve(_monsterId, saleAuction);
        // Sale auction throws if inputs are invalid and clears
        // transfer and sire approval after escrowing the monster.
        saleAuction.createAuction(
            _monsterId,
            _startingPrice,
            _endingPrice,
            _duration,
            msg.sender
        );
    }


    /// @dev Transfers the balance of the sale auction contract
    /// to the MonsterCore contract. We use two-step withdrawal to
    /// prevent two transfer calls in the auction bid function.
    function withdrawAuctionBalances() external onlyCLevel {
        saleAuction.withdrawBalance();
    }
}




/// @title all functions related to creating monsters
contract MonsterMinting is MonsterAuction {

    // Limits the number of monsters the contract owner can ever create.
    uint256 public constant PROMO_CREATION_LIMIT = 1000;


    // Constants for gen0 auctions.
    uint256 public constant GEN0_BATMAN_STARTING_PRICE = 10 ether;
    uint256 public constant GEN0_BATMAN_ENDING_PRICE = 1 ether;

    uint256 public constant GEN0_STARTING_PRICE = 1 ether;
    uint256 public constant GEN0_ENDING_PRICE = 0.1 ether;
    uint256 public constant GEN0_AUCTION_DURATION = 30 days;


    // Counts the number of monsters the contract owner has created.
    uint256 public promoCreatedCount;


    /// @dev we can create promo monsters, up to a limit. Only callable by COO
    /// @param _genes the encoded genes of the monster to be created, any value is accepted
    /// @param _owner the future owner of the created monsters. Default to contract COO
    function createPromoMonster(uint256 _genes, address _owner) external onlyCOO {
        address monsterOwner = _owner;
        if (monsterOwner == address(0)) {
             monsterOwner = cooAddress;
        }
        require(promoCreatedCount < PROMO_CREATION_LIMIT);

        promoCreatedCount++;
        _createMonster(0, _genes, monsterOwner);
    }

    /// @dev Creates a new gen0 monster with the given genes and
    ///  creates an auction for it.
    function createGen0AuctionBatman() external onlyCOO {
        require(promoCreatedCount < PROMO_CREATION_LIMIT);

        uint256 monsterId = _createMonster(0, 1, address(this));
        _approve(monsterId, saleAuction);

        saleAuction.createAuction(
            monsterId,
            GEN0_BATMAN_STARTING_PRICE,
            GEN0_BATMAN_ENDING_PRICE,
            GEN0_AUCTION_DURATION,
            address(this)
        );

        promoCreatedCount++;
    }

    /// @dev Creates a new gen0 monster with the given genes and
    ///  creates an auction for it.
    function createGen0Auction(uint256 _genes) external onlyCOO {
        require(promoCreatedCount < PROMO_CREATION_LIMIT);

        uint256 monsterId = _createMonster(0, _genes, address(this));
        _approve(monsterId, saleAuction);

        saleAuction.createAuction(
            monsterId,
            GEN0_STARTING_PRICE,
            GEN0_ENDING_PRICE,
            GEN0_AUCTION_DURATION,
            address(this)
        );

        promoCreatedCount++;
    }

        /// @dev Creates a new gen0 monster with the given genes and
    ///  creates an auction for it.
    function createGen0AuctionsN( uint256 _startingN, uint256 _endingN) external onlyCOO {
        require(promoCreatedCount < PROMO_CREATION_LIMIT);


        for (uint256 i = _startingN; i < _endingN; i++) {
            
            uint256 monsterId = _createMonster(0, i, address(this));
            _approve(monsterId, saleAuction);

            saleAuction.createAuction(
                monsterId,
                GEN0_STARTING_PRICE,
                GEN0_ENDING_PRICE,
                GEN0_AUCTION_DURATION,
                address(this)
            );

            promoCreatedCount++;
        }
    }
}




/// @title MonsterBit: Collectible, breedable, and monsters on the Ethereum blockchain.
/// @dev The main MonsterBit contract, keeps track of monsters so they don't wander around and get lost.
contract MonsterCore is MonsterMinting {

    // This is the main MonsterBit contract. In order to keep our code seperated into logical sections,
    // we've broken it up in two ways. First, we have several seperately-instantiated sibling contracts
    // that handle auctions and our super-top-secret genetic combination algorithm. The auctions are
    // seperate since their logic is somewhat complex and there's always a risk of subtle bugs. By keeping
    // them in their own contracts, we can upgrade them without disrupting the main contract that tracks
    // monster ownership. The genetic combination algorithm is kept seperate so we can open-source all of
    // the rest of our code without making it _too_ easy for folks to figure out how the genetics work.
    // Don't worry, I'm sure someone will reverse engineer it soon enough!
    //
    // Secondly, we break the core contract into multiple files using inheritence, one for each major
    // facet of functionality of CK. This allows us to keep related code bundled together while still
    // avoiding a single giant file with everything in it. The breakdown is as follows:
    //
    //      - MonsterBase: This is where we define the most fundamental code shared throughout the core
    //             functionality. This includes our main data storage, constants and data types, plus
    //             internal functions for managing these items.
    //
    //      - MonsterAccessControl: This contract manages the various addresses and constraints for operations
    //             that can be executed only by specific roles. Namely CEO, CFO and COO.
    //
    //      - MonsterOwnership: This provides the methods required for basic non-fungible token
    //             transactions, following the draft ERC-721 spec (https://github.com/ethereum/EIPs/issues/721).
    //
    //      - MonsterBreeding: This file contains the methods necessary to breed monsters together, including
    //             keeping track of siring offers, and relies on an external genetic combination contract.
    //
    //      - MonsterAuctions: Here we have the public methods for auctioning or bidding on monsters or siring
    //             services. The actual auction functionality is handled in two sibling contracts (one
    //             for sales and one for siring), while auction creation and bidding is mostly mediated
    //             through this facet of the core contract.
    //
    //      - MonsterMinting: This final facet contains the functionality we use for creating new gen0 monsters.
    //             We can make up to 5000 "promo" monsters that can be given away (especially important when
    //             the community is new), and all others can only be created and then immediately put up
    //             for auction via an algorithmically determined starting price. Regardless of how they
    //             are created, there is a hard limit of 50k gen0 monsters. After that, it's all up to the
    //             community to breed, breed, breed!

    // Set in case the core contract is broken and an upgrade is required
    address public newContractAddress;

    /// @notice Creates the main MonsterBit smart contract instance.
    function MonsterCore() public {
        // Starts paused.
        paused = true;

        // the creator of the contract is the initial CEO
        ceoAddress = msg.sender;

        // the creator of the contract is also the initial COO
        cooAddress = msg.sender;

        // start with the mythical monster 0 - so we don't have generation-0 parent issues
        _createMonster(0, uint256(-1), address(0));
    }

    /// @dev Used to mark the smart contract as upgraded, in case there is a serious
    ///  breaking bug. This method does nothing but keep track of the new contract and
    ///  emit a message indicating that the new address is set. It's up to clients of this
    ///  contract to update to the new contract address in that case. (This contract will
    ///  be paused indefinitely if such an upgrade takes place.)
    /// @param _v2Address new address
    function setNewAddress(address _v2Address) external onlyCEO whenPaused {
        // See README.md for updgrade plan
        newContractAddress = _v2Address;
        ContractUpgrade(_v2Address);
    }

    /// @notice No tipping!
    /// @dev Reject all Ether from being sent here, unless it's from one of the
    ///  two auction contracts. (Hopefully, we can prevent user accidents.)
    function() external payable {
        require(
            msg.sender == address(saleAuction)
        );
    }

    /// @notice Returns all the relevant information about a specific monster.
    /// @param _id The ID of the monster of interest.
    function getMonster(uint256 _id)
        external
        view
        returns (
        uint256 birthTime,
        uint256 generation,
        uint256 genes
    ) {
        Monster storage mon = monsters[_id];

        birthTime = uint256(mon.birthTime);
        generation = uint256(mon.generation);
        genes = mon.genes;
    }

    /// @dev Override unpause so it requires all external contract addresses
    ///  to be set before contract can be unpaused. Also, we can't have
    ///  newContractAddress set either, because then the contract was upgraded.
    /// @notice This is public rather than external so we can call super.unpause
    ///  without using an expensive CALL.
    function unpause() public onlyCEO whenPaused {
        require(saleAuction != address(0));
        require(newContractAddress == address(0));

        // Actually unpause the contract.
        super.unpause();
    }

    // @dev Allows the CFO to capture the balance available to the contract.
    function withdrawBalance() external onlyCFO {
        uint256 balance = this.balance;
        cfoAddress.send(balance);
    }
}




