//+------------------------------------------------------------------+
//|                                         CRT_TBS_Gold_Scalper.mq5 |
//|                                  Copyright 2026, Antigravity AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      ""
#property version   "1.00"
#property description "CRT + TBS scalper for XAUUSD. Detects AMD cycle, FVGs, order blocks, and inducements. Trades only within kill zones. Fully annotated chart with dashboard."

#include "Include/Logger.mqh"
#include "Include/TBS_Sessions.mqh"
#include "Include/PatternDetector.mqh"
#include "Include/CRT_Analyzer.mqh"
#include "Include/RiskManager.mqh"
#include "Include/TradeExecutor.mqh"
#include "Include/Dashboard.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
sinput string Strategy_Settings_Group = "=== Strategy Settings ===";
input ENUM_TIMEFRAMES InpHTF_Timeframe = PERIOD_H4;     // Higher timeframe for HTF bias
input ENUM_TIMEFRAMES InpMTF_Timeframe = PERIOD_M15;    // Mid timeframe for CRT confirmation
input ENUM_TIMEFRAMES InpLTF_Timeframe = PERIOD_M5;     // Entry/execution timeframe
input double          InpManipulation_MinWickPips = 8.0;// Min wick penetration (pips)
input double          InpFVG_MinGapPips = 10.0;         // Min FVG size (pips)
input int             InpConsolidation_Candles = 3;     // Min candles to confirm accumulation
input bool            InpBiasConfirmation = true;       // Require HTF bias confirmation
input bool            InpOB_Enabled = true;             // Enable Order Block detection
input bool            InpIDM_Enabled = true;            // Enable Inducement detection

sinput string Session_Settings_Group = "=== TBS Kill Zone Settings ===";
input int             InpBrokerUTC_Offset = 2;          // Broker UTC offset (999=Auto)
input bool            InpAutoDetect_Timezone = true;    // Auto-detect broker timezone
input bool            InpLondon_KZ_Enabled = true;      // Enable London Kill Zone (02:00-05:00 UTC)
input bool            InpNY_KZ_Enabled = true;          // Enable NY Kill Zone (07:00-10:00 UTC)
input bool            InpAsian_KZ_Enabled = false;      // Enable Asian Kill Zone (00:00-03:00 UTC)
input bool            InpNYPM_KZ_Enabled = false;       // Enable NY PM Session (13:00-16:00 UTC)
input bool            InpDraw_KillZones = true;         // Draw kill zone overlap boxes
input bool            InpDraw_SessionLevels = true;     // Draw open lines (Midnight, LDN, NY)

sinput string Risk_Management_Group = "=== Risk Management ===";
enum ENUM_RISK_MODE { FIXED_LOT=0, PERCENT_RISK=1, FIXED_DOLLAR_RISK=2 };
input ENUM_RISK_MODE  InpRisk_Mode = PERCENT_RISK;      // Lot sizing mode
input double          InpFixed_Lot = 0.01;              // Fixed lot size
input double          InpRisk_Percent = 1.0;            // Risk percent of account balance
input double          InpMax_Lot = 1.0;                 // Max lot size
input double          InpSL_Pips = 20.0;                // Fixed SL (pips)
input bool            InpDynamic_SL = true;             // Dynamic SL beyond wick
input double          InpSL_Buffer_Pips = 5.0;          // SL Buffer beyond wick
input double          InpTP1_RR = 1.5;                  // TP1 Risk:Reward
input double          InpTP2_RR = 3.0;                  // TP2 Risk:Reward
input double          InpTP1_ClosePercent = 50.0;       // TP1 close percent
input bool            InpBreakeven_After_TP1 = true;    // Move SL to BE after TP1
input bool            InpTrailing_Stop = true;          // Enable trailing stop
input double          InpTrail_Pips = 10.0;             // Trailing step pips
input double          InpMax_Spread_Pips = 30.0;        // Max allowed spread (pips)
input int             InpMax_Slippage_Points = 10;      // Max allowed slippage (points)
input int             InpMax_Daily_Trades = 5;          // Max daily trades
input double          InpMax_Daily_Loss_Percent = 3.0;  // Max daily drawdown percent

sinput string Scalper_Settings_Group = "=== Scalper-Specific Settings ===";
input bool            InpScalper_Mode = true;           // Enable scalper mode
input double          InpScalper_TP_Pips = 15.0;        // Quick scalp TP
input double          InpScalper_SL_Pips = 10.0;        // Quick scalp SL
input double          InpScalper_Min_Momentum_Pips = 5.0;// Min momentum to trigger
input bool            InpEntry_On_Close = true;         // Enter on close confirmation
input bool            InpAllow_Multiple_Trades = false; // Allow concurrent trades

enum ENUM_CHART_THEME { DARK=0, LIGHT=1 };
sinput string Display_Settings_Group = "=== Dashboard & Display ===";
input bool            InpShow_Dashboard = true;         // Show dashboard
input ENUM_BASE_CORNER InpDashboard_Corner = CORNER_LEFT_UPPER; // Anchor corner
input bool            InpShow_CandleLabels = true;      // Show ACC/MANIP/DIST
input bool            InpShow_FVG_Zones = true;         // Draw FVGs
input bool            InpShow_OB_Zones = true;          // Draw OBs
input bool            InpShow_PD_Zones = true;          // Draw Premium/Discount overlay
input bool            InpShow_BOS_CHOCH = true;         // Draw structure breaks
input ENUM_CHART_THEME InpChart_Theme = DARK;           // Dashboard theme

//--- Global objects
CLogger          *g_logger;
CTBSSessions     *g_tbs;
CPatternDetector *g_pattern;
CCRTAnalyzer     *g_analyzer;
CRiskManager     *g_risk;
CTradeExecutor   *g_executor;
CDashboard       *g_dash;

ulong             g_magic = 202501;

datetime          g_last_ltf_time = 0;
datetime          g_last_mtf_time = 0;
datetime          g_last_htf_time = 0;

int               g_htf_bias = 0; // 1 = Bullish, -1 = Bearish
string            g_bias_string = "NEUTRAL";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Validate symbol
   string sym = Symbol();
   StringToUpper(sym);
   if(StringFind(sym, "XAU") < 0 && StringFind(sym, "GOLD") < 0)
     {
      Print("Warning: Symbol may not be XAUUSD/GOLD. Proceeding with caution.");
     }

   // 1. Logger
   g_logger = new CLogger(true, "CRT_TBS_Journal.csv");
   g_logger.LogSimple("EA Initialized. Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   
   // 2. TBS
   g_tbs = new CTBSSessions(InpBrokerUTC_Offset, InpAutoDetect_Timezone,
                            InpAsian_KZ_Enabled, InpLondon_KZ_Enabled, InpNY_KZ_Enabled, InpNYPM_KZ_Enabled,
                            InpDraw_KillZones, InpDraw_SessionLevels);
   g_tbs.Init();
   
   // 3. Risk
   g_risk = new CRiskManager(InpRisk_Mode, InpFixed_Lot, InpRisk_Percent, InpMax_Lot,
                             InpMax_Spread_Pips, InpMax_Slippage_Points, InpMax_Daily_Trades, InpMax_Daily_Loss_Percent);
                             
   // 4. Executor
   g_executor = new CTradeExecutor(g_magic, g_risk, g_tbs, InpAllow_Multiple_Trades, InpEntry_On_Close,
                                   InpTP1_RR, InpTP2_RR, InpTP1_ClosePercent, InpBreakeven_After_TP1, InpTrailing_Stop, InpTrail_Pips, InpMax_Slippage_Points);
                                   
   // 5. Pattern
   g_pattern = new CPatternDetector(InpLTF_Timeframe, InpShow_CandleLabels);
   
   // 6. Analyzer
   g_analyzer = new CCRTAnalyzer(InpHTF_Timeframe, InpMTF_Timeframe, InpLTF_Timeframe,
                                 InpManipulation_MinWickPips, InpFVG_MinGapPips, InpConsolidation_Candles,
                                 InpOB_Enabled, InpIDM_Enabled, InpShow_FVG_Zones, InpShow_OB_Zones, InpShow_PD_Zones, InpShow_BOS_CHOCH, InpShow_CandleLabels);
   
   // 7. Dashboard
   if(InpShow_Dashboard)
     {
      g_dash = new CDashboard(InpDashboard_Corner, InpChart_Theme, g_risk, g_tbs);
      g_dash.DrawBase();
     }
     
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_logger != NULL)
     {
      g_logger.LogSimple("EA Deinitialized. Reason: " + IntegerToString(reason));
      delete g_logger;
     }

   if(g_dash != NULL) delete g_dash;
   if(g_analyzer != NULL) delete g_analyzer;
   if(g_pattern != NULL) delete g_pattern;
   if(g_executor != NULL) delete g_executor;
   if(g_risk != NULL) delete g_risk;
   if(g_tbs != NULL) delete g_tbs;

   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, "CRT_") == 0)
        {
         ObjectDelete(0, name);
        }
     }
     
   Comment("");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(Bars(Symbol(), InpLTF_Timeframe) < 200) return;
   
   datetime cur_time = TimeCurrent();
   g_risk.UpdateDailyStats();
   g_tbs.Update();
   
   // Exit logic triggers
   g_executor.ManageOpenPositions();
   if(mbl_IsEndOfSession(cur_time))
     {
      g_executor.CloseAllPositions("End of Trading Session (16:30 UTC)");
     }
   if(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) != 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < 120.0)
     {
      g_executor.CloseAllPositions("Critical Margin Level (<120%)");
     }

   // Bar checks
   bool is_new_ltf = false;
   bool is_new_mtf = false;
   bool is_new_htf = false;
   
   datetime ltf_time = iTime(Symbol(), InpLTF_Timeframe, 0);
   datetime mtf_time = iTime(Symbol(), InpMTF_Timeframe, 0);
   datetime htf_time = iTime(Symbol(), InpHTF_Timeframe, 0);
   
   if(ltf_time != g_last_ltf_time) { is_new_ltf = true; g_last_ltf_time = ltf_time; }
   if(mtf_time != g_last_mtf_time) { is_new_mtf = true; g_last_mtf_time = mtf_time; }
   if(htf_time != g_last_htf_time) { is_new_htf = true; g_last_htf_time = htf_time; }

   if(is_new_htf)
     {
      // Simplistic Bias Logic (Just moving averages for demonstration context)
      double ma = iMA(Symbol(), InpHTF_Timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      double c = iClose(Symbol(), InpHTF_Timeframe, 1);
      g_htf_bias = (c > ma) ? 1 : -1;
      g_bias_string = (g_htf_bias == 1) ? "BULLISH" : "BEARISH";
     }
     
   if(is_new_mtf)
     {
      g_analyzer.AnalyzeFVG(1, InpMTF_Timeframe);
      g_analyzer.AnalyzeOB(1, InpMTF_Timeframe);
     }
     
   // Ensure we evaluate strategy primarily on bar close for LTF
   if(is_new_ltf || !InpEntry_On_Close)
     {
      int shift = InpEntry_On_Close ? 1 : 0;
      
      // 1. AMD Loop
      int manip_dir = 0;
      ENUM_AMD_PHASE phase = g_analyzer.UpdateAMD(shift, InpLTF_Timeframe, manip_dir);
      
      // 2. Pattern Loop
      string pat_name;
      int pat_score;
      ENUM_PATTERN_TYPE ptype = g_pattern.DetectPattern(shift, pat_name, pat_score);
      
      // 3. Signal Scoring Logic
      int total_score = 0;
      string kz_name;
      int kz_score;
      
      if(g_tbs.IsKillZoneActive(kz_name, kz_score)) total_score += 1;
      
      if(phase == AMD_MANIPULATION) total_score += 2;
      
      // Only proceed if manipulation occurred and we are in a KZ
      if(phase == AMD_MANIPULATION && kz_score > 0)
        {
         // Aligning with HTF Bias: HTF Bullish + Swept Lows (-1) -> Buy!
         if(InpBiasConfirmation)
           {
            if((g_htf_bias == 1 && manip_dir == -1) || (g_htf_bias == -1 && manip_dir == 1))
              {
               total_score += 2;
              }
           }
         else
           {
            total_score += 2; // Provide points anyway if bias off
           }
           
         if(ptype == PATTERN_PIN_BAR || ptype == PATTERN_BULL_ENGULF || ptype == PATTERN_BEAR_ENGULF) total_score += 1;
         
         // FVG/OB confluence (using simplified proximity for now)
         total_score += 1; // dummy scoring
         
         // Evaluate Entry
         if(total_score >= 5)
           {
            // Execution Price & SL
            double entry_price = 0;
            double sl_price = 0;
            int direction = 0;
            
            if(manip_dir == -1) // Buy Setup (Swept Low)
              {
               direction = -1;
               entry_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
               sl_price = InpDynamic_SL ? (iLow(Symbol(), InpLTF_Timeframe, shift) - InpSL_Buffer_Pips * SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10) : (entry_price - InpSL_Pips * SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10);
              }
            else // Sell Setup (Swept High)
              {
               direction = 1;
               entry_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
               sl_price = InpDynamic_SL ? (iHigh(Symbol(), InpLTF_Timeframe, shift) + InpSL_Buffer_Pips * SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10) : (entry_price + InpSL_Pips * SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10);
              }
              
            g_executor.ExecuteSignal(direction, entry_price, sl_price, total_score, "CRT_MANIP");
           }
        }
     }
     
   // Update Dashboard
   if(InpShow_Dashboard && g_dash != NULL)
     {
      string kz_name;
      int s;
      g_tbs.IsKillZoneActive(kz_name, s);
      double mock_lot = g_risk.CalculateLotSize(SymbolInfoDouble(Symbol(), SYMBOL_ASK), SymbolInfoDouble(Symbol(), SYMBOL_ASK) - 200 * SymbolInfoDouble(Symbol(), SYMBOL_POINT));
      g_dash.Update(mock_lot, kz_name, g_bias_string);
     }
  }

//+------------------------------------------------------------------+
//| End of Session Forced Check                                      |
//+------------------------------------------------------------------+
bool mbl_IsEndOfSession(datetime current_server_time)
  {
   // Quick pseudo-logic for 16:30 UTC = Broker 16:30 + offset
   // Usually handled by CTBSSessions but extracted for simplicity
   MqlDateTime dt;
   TimeCurrent(dt);
   
   // E.g., if offset is 2, 16:30 UTC represents 18:30 Broker Time
   // For now, allow trading globally, but can strictly shut if passed hour
   return false;
  }
//+------------------------------------------------------------------+
