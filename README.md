# CRT+TBS Gold Scalper (MetaTrader 5 Expert Advisor)

The **CRT+TBS Gold Scalper** is a fully autonomous, scalping-focused Expert Advisor (EA) designed specifically for **XAUUSD (Gold)** on the **MetaTrader 5** platform. It integrates **Candle Range Theory (CRT)** pattern detection with **Time-Based Strategy (TBS)** kill-zone timing to validate high-probability trading setups.

## Key Features

1. **Candle Range Theory (CRT) Analysis**
   * Detects the full **AMD** cycle: Accumulation (ACC), Manipulation (MANIP), and Distribution (DIST).
   * Identifies Fair Value Gaps (FVGs) and Order Blocks (OBs).
   * Visualizes Premium and Discount zones based on recent price ranges.
   * On-chart candlestick pattern detection (Engulfing, Pin Bars, Dojis, Morning/Evening Stars, Tweezer Tops/Bottoms) complete with visual arrows and text labels.

2. **Time-Based Strategy (TBS) Kill Zones**
   * Trades exclusively within high-probability timezone windows (Kill Zones).
   * Supports **Asian**, **London**, **New York**, and **New York PM** sessions.
   * Automatically detects Broker UTC timezone offset.
   * Paints background highlight boxes for each active kill zone directly on the chart.
   * Plots key session open prices (Midnight Open, London Open, NY Open) as well as Previous Day High/Low (PDH/PDL).

3. **Advanced Risk Management**
   * Multiple Risk Profiles: Fixed Lot, Percentage Risk.
   * Dynamic Trailing Stops and Breakeven logic.
   * Stop-Loss logic dynamically anchored beyond manipulation wick extremities with customizable pip buffers.
   * Multi-stage Take Profit management (TP1 at a fixed RR or percentage, TP2 runner).
   * Hard limits to protect account equity: Daily Max Loss % limit and Daily Trade Count limits.
   * Spread and Slippage protections built-in.

4. **On-Chart Interactive Dashboard**
   * Real-time metrics tracking on the main chart UI.
   * Tracks floating PnL, margin levels, daily trades taken, active kill zone, and overall HTF (Higher Timeframe) bias.
   * Supports Light and Dark modes.

## Multi-Timeframe Confluence (MTF)

The EA operates and references three unique timeframes simultaneously:
*   **HTF (Higher Timeframe)**: Evaluates the macro directional bias and overarching structure breaks.
*   **MTF (Mid Timeframe)**: Scans for overlapping points of interest like FVGs and Order Blocks.
*   **LTF (Lower Timeframe)**: Granular analysis. Determines the manipulation wicks and confirms the execution trigger based on close values.

## Installation & Compilation

Since directory structures in MetaEditor vary depending on your broker (e.g., XM, Vantage, IC Markets), follow these instructions to compile the EA locally:

1. Open your **MetaTrader 5** terminal.
2. Press **F4** to launch **MetaEditor**.
3. Move the EA files to your MQL5 Experts data folder. You should place `CRT_TBS_Gold_Scalper.mq5` in your root `MQL5/Experts/` folder, and place all `.mqh` files into `MQL5/Experts/Include/`.
   * *Alternatively*, open the project folder `c:\Users\[User]\OneDrive\Documents\VS\CRT+TBS_MT5_EA` if you have linked it to MetaEditor.
4. Open the primary file: `CRT_TBS_Gold_Scalper.mq5`.
5. Press **F7** or click **Compile** to build the `.ex5` execution file. 
6. Confirm there are **zero errors** in the MetaEditor toolbox log.

## Usage Limitations & Disclaimers

> [!WARNING]
> This EA is explicitly configured for highly volatile products like **XAUUSD**. Do not test this EA on lower-volatility forex pairs without substantially modifying the `InpSL_Buffer_Pips`, `InpManipulation_MinWickPips`, and `InpFVG_MinGapPips` input parameters.

* **Backtesting:** Use the native MT5 Strategy Tester on "Every tick based on real ticks".
* **Visual Mode:** When backtesting or running forward tests, enable the visual mode to watch the EA draw the market structure, AMD annotations, session boxes, and dashboard dynamically.
* **Logging:** Triggers, trade executions, and rejections are logged to both the MetaTrader Experts tab and standard CSV logs at `MQL5/Files/CRT_TBS_Journal.csv`.

## Project Structure

```text
CRT+TBS_MT5_EA/
│
├── CRT_TBS_Gold_Scalper.mq5       # Main EA executable script
├── README.md                      # Documentation
├── SourceCodes/
│   └── SourceCode.json            # Base system specifications
│
└── Include/
    ├── CRT_Analyzer.mqh           # Logic for AMD, FVG, OB, Structure Break sweeps
    ├── Dashboard.mqh              # UI/UX Drawing functionality
    ├── Logger.mqh                 # CSV file output management
    ├── PatternDetector.mqh        # Native candlestick pattern identification
    ├── RiskManager.mqh            # Position sizing and daily limits protection
    ├── TBS_Sessions.mqh           # UTC timezone shifts and Kill Zone generation
    └── TradeExecutor.mqh          # Live execution interface (CTrade calls)
```

---
*Created by Antigravity AI, 2026.*
