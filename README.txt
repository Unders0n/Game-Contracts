MonsterBitCore:
AccessControl
MonsterBase is AccessControl
ERC721Metadata
MonsterOwnership is MonsterBase, ERC721
MonsterAuction(SaleClockAuction address) is MonsterOwnership
MonsterMinting is MonsterAuction
MonsterCore is MonsterMinting


MonsterBitSaleAuction:
ClockAuctionBase
ClockAuction is Pausable, ClockAuctionBase
SaleClockAuction is ClockAuction
