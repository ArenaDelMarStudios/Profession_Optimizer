# Profession Optimizer

World of Warcraft Retail addon for profession tracking, gathering statistics, Auction House market history, sales tracking, and profession optimization.

## Current Version

0.1.5

## Features

- Profession detection
- Gathering session timer and history
- Loot, item classification, and gathered-item tracking
- Minimap button and main addon interface
- Persistent per-character settings
- Optional junk vendor value tracking
- Manual Auction House price scanning
- Per-unit Auction House pricing and available quantity
- Persistent Auction House price history
- 24-hour, 7-day, and all-time median/low/high market statistics
- Profession Optimizer market data in item tooltips
- Mailbox-confirmed Auction House sales history
- Quantity sold and average realized sale price per unit
- Gross and net Auction House sales tracking
- Realized net gold per gathering hour
- Combined Sales / Market item view

## Auction House Tracking

Auction House scans are manual only. Opening the Auction House does not automatically query prices.

To update market data, open the Auction House, open Profession Optimizer, and press **Scan AH Prices**. The addon scans gathered items already known to its database and stores per-unit prices and available quantities as local historical market samples.

Repeated manual scans build the local history used for 24-hour, 7-day, and all-time market statistics.

## Item Tooltips

When **Show Profession Optimizer Item Tooltips** is enabled, tracked items can display cached Profession Optimizer data including current AH price per unit, 24-hour/7-day/all-time medians, available quantity, last manual scan age, gathered quantity, sold quantity, and average realized sale price per unit.

Tooltip market values are cached from the user's own manual Auction House scans and are not live until a new scan is performed.

## Sales Tracking

Completed Auction House sales are tracked separately from market scans. Profession Optimizer reads Auction House seller invoices from the mailbox and stores confirmed sales.

Tracked sales include item, quantity sold, gross value, Auction House consignment/fee, net value, average realized price per unit, and sale time.

## Realized Net Gold Per Hour

**Realized Net Gold/Hour** is calculated from confirmed net Auction House sales matched to gathered items divided by completed gathering-session time.

## Sales / Market View

The combined table displays:

- Item
- Gathered quantity
- Current AH price per unit
- Quantity sold
- Average sold price per unit
- 7-day median market price
- Net realized sales

Selecting an item shows detailed market statistics, recent sales, and recent AH price samples.

## Slash Commands

- `/po start` — Start a gathering session
- `/po stop` — Stop the current gathering session
- `/po status` — Display current session statistics
- `/po prof` — Display detected professions
- `/po salescan` — Scan available mailbox seller invoices for completed AH sales

Auction House price scanning is intentionally controlled from the UI.

## Data Storage

Profession Optimizer uses the SavedVariable `ProfessionOptimizerDB`.

It stores per-character settings, gathering history, the gathered-item index, completed AH sales, mail snapshots for duplicate protection, current AH prices, and historical AH price samples.

## Development Status

Profession Optimizer is in active development. The current milestone combines gathering-session tracking, manual AH market tracking, historical pricing, item tooltips, mailbox-confirmed sales, and realized gold-per-hour analysis.

Planned work includes inventory analysis, crafting profitability, disenchanting/prospecting valuation, improved history navigation, additional profession metrics, and data export.
