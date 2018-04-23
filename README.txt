MonsterBitCore:
Ownable
ERC721
AccessControl
MonsterBase is AccessControl
Pausable is Ownable
ClockAuctionBase
ClockAuction is Pausable, ClockAuctionBase
SaleClockAuction is ClockAuction
ERC721Metadata
MonsterOwnership is MonsterBase, ERC721
MonsterAuction is MonsterOwnership
MonsterMinting is MonsterAuction
MonsterCore is MonsterMinting


MonsterBitSaleAuction:
Ownable
ERC721
Pausable is Ownable
ClockAuctionBase
ClockAuction is Pausable, ClockAuctionBase
SaleClockAuction is ClockAuction
