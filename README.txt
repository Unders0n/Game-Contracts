MonsterBitCore contracts:
AccessControl
MonsterBase is AccessControl
ERC721Metadata
MonsterOwnership is MonsterBase, ERC721
MonsterAuction(SaleClockAuction address) is MonsterOwnership
MonsterMinting is MonsterAuction
MonsterCore is MonsterMinting


MonsterBitSaleAuction contracts:
ClockAuctionBase
ClockAuction is Pausable, ClockAuctionBase
SaleClockAuction is ClockAuction


How to set up:
- create MonsterCore()
- create SaleClockAuction(MonsterCore address, _cut)   // 0xbbf289d846208c16edc8474705c748aff07732db, 2000  (20%)
- MonsterCore.setSaleAuctionAddress(SaleClockAuction address)
- MonsterCore.unpause() \\ ??