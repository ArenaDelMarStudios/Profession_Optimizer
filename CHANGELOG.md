# Changelog

## v0.1.5

- Added Oribos-style local Auction House market history
- Added persistent per-unit Auction House price samples
- Added current AH price and available quantity tracking
- Added 24-hour median, low, high, and sample-count statistics
- Added 7-day median, low, high, and sample-count statistics
- Added all-time median, low, high, and sample-count statistics
- Added Profession Optimizer market data to item tooltips
- Added optional tooltip-data setting
- Added gathered, sold, and average realized sale price data to tooltips
- Updated Sales / Market table with 7-day median pricing
- Expanded selected-item market details
- Increased retained AH price-history capacity with a per-item cap
- Improved available-quantity tracking
- Kept AH price scanning strictly manual through the UI
- Preserved mailbox-confirmed sales and realized net gold/hour tracking
- Updated database schema for expanded market history

## v0.1.4

- Removed automatic Auction House price scanning
- Made AH scans manual through the Scan AH Prices UI button
- Removed the obsolete automatic-scan setting
- Added Realized Net Gold/Hour tracking
- Added realized gold/hour to Session and Sales / Market UI
- Calculated realized gold/hour from matched confirmed net AH sales and completed gathering-session time
- Preserved per-unit pricing and mailbox-confirmed sales

## v0.1.3

- Added Auction House market-price tracking foundation
- Added per-unit pricing and persistent price history
- Added available AH quantity tracking
- Added gathered-item AH scan queue and throttled queries
- Added combined Sales / Market interface
- Added recent AH price samples
- Added mailbox seller-invoice sales tracking
- Separated market observations from confirmed sales

## v0.1.2

- Added mailbox seller-invoice tracking as authoritative completed-sale source
- Added persistent AH sales history
- Added quantity, gross, consignment, and net sale tracking
- Added duplicate-import protection using mailbox snapshots
- Added Sales History interface
- Added gathered/sold item summaries
- Removed dependency on owned-auction reconstruction for completed-sale detection

## v0.1.1

- Added minimap button and persistent positioning
- Added main Profession Optimizer window
- Added Start/Stop session controls
- Added live session status, elapsed time, item count, and junk value
- Added persistent per-character settings
- Added optional junk vendor value tracking
- Fixed SavedVariables initialization across `/reload`
- Replaced obsolete World Map widget refresh logic

## v0.1.0

- Added profession detection
- Added gathering session timer
- Added loot tracking
- Added item classification
- Added gathering session history
