//+------------------------------------------------------------------+
//|                                                 CRT_Analyzer.mqh |
//|                                  Copyright 2026, Antigravity AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      ""
#property strict

#include "Logger.mqh"

extern CLogger *g_logger;

enum ENUM_AMD_PHASE
  {
   AMD_NONE,
   AMD_ACCUMULATION,
   AMD_MANIPULATION,
   AMD_DISTRIBUTION
  };

struct SAccumulationRange
  {
   bool      active;
   datetime  start_time;
   datetime  end_time;
   double    high_price;
   double    low_price;
   int       candles_count;
  };

struct SZone
  {
   bool      active;
   double    high_price;
   double    low_price;
   datetime  time;
  };

class CCRTAnalyzer
  {
private:
   ENUM_TIMEFRAMES   m_htf;
   ENUM_TIMEFRAMES   m_mtf;
   ENUM_TIMEFRAMES   m_ltf;
   
   double            m_min_wick_pips;
   double            m_fvg_min_pips;
   int               m_min_acc_candles;
   bool              m_ob_enabled;
   bool              m_idm_enabled;
   
   double            m_point;
   int               m_digits;
   double            m_pip_value;

   bool              m_draw_fvg;
   bool              m_draw_ob;
   bool              m_draw_pd;
   bool              m_draw_bos;
   bool              m_draw_labels;

   SAccumulationRange m_acc_range;
   
   SZone             m_last_bull_fvg;
   SZone             m_last_bear_fvg;
   SZone             m_last_bull_ob;
   SZone             m_last_bear_ob;
   
   // Drawing helpers
   void              DrawFVGBox(string name, datetime t1, double p1, double p2, color clr);
   void              DrawOBBox(string name, datetime t1, double p1, double p2, color clr);
   void              DrawPDZones(string name, datetime t1, datetime t2, double high, double low);
   void              DrawText(string name, string text, datetime t, double p, color clr, int anchor);
   void              DrawTrendLine(string name, datetime t1, double p1, datetime t2, double p2, color clr, string text);

public:
                     CCRTAnalyzer(ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES mtf, ENUM_TIMEFRAMES ltf,
                                  double min_wick, double min_fvg, int min_acc,
                                  bool ob_on, bool idm_on,
                                  bool draw_fvg, bool draw_ob, bool draw_pd, bool draw_bos, bool draw_labels);
                    ~CCRTAnalyzer(void);

   // Analysis
   void              AnalyzeFVG(int index, ENUM_TIMEFRAMES tf);
   void              AnalyzeOB(int index, ENUM_TIMEFRAMES tf);
   ENUM_AMD_PHASE    UpdateAMD(int index, ENUM_TIMEFRAMES tf, int &manip_direction);
   void              AnalyzeStructure(ENUM_TIMEFRAMES tf);
   
   double            GetAccumulationHigh() { return m_acc_range.high_price; }
   double            GetAccumulationLow()  { return m_acc_range.low_price; }
   
   bool              IsInsideFVG(double price, int direction);
   bool              IsInsideOB(double price, int direction);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCRTAnalyzer::CCRTAnalyzer(ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES mtf, ENUM_TIMEFRAMES ltf,
                           double min_wick, double min_fvg, int min_acc,
                           bool ob_on, bool idm_on,
                           bool draw_fvg, bool draw_ob, bool draw_pd, bool draw_bos, bool draw_labels)
  {
   m_htf = htf;
   m_mtf = mtf;
   m_ltf = ltf;
   
   m_min_wick_pips = min_wick;
   m_fvg_min_pips = min_fvg;
   m_min_acc_candles = min_acc;
   
   m_ob_enabled = ob_on;
   m_idm_enabled = idm_on;
   
   m_draw_fvg = draw_fvg;
   m_draw_ob = draw_ob;
   m_draw_pd = draw_pd;
   m_draw_bos = draw_bos;
   m_draw_labels = draw_labels;
   
   m_point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   m_digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   m_pip_value = (m_digits == 3 || m_digits == 5) ? m_point * 10.0 : m_point;
   if(StringFind(Symbol(), "XAU") >= 0 || StringFind(Symbol(), "GOLD") >= 0) m_pip_value = 0.1; // 1 pip = 10 cents for Gold
   
   m_acc_range.active = false;
   m_acc_range.high_price = 0;
   m_acc_range.low_price = 0;
   m_acc_range.candles_count = 0;
   
   m_last_bull_fvg.active = false;
   m_last_bear_fvg.active = false;
   m_last_bull_ob.active = false;
   m_last_bear_ob.active = false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCRTAnalyzer::~CCRTAnalyzer(void)
  {
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CCRTAnalyzer::AnalyzeFVG(int index, ENUM_TIMEFRAMES tf)
  {
   // FVG requires 3 candles (index+2, index+1, index) - older to newer
   double h[3], l[3];
   datetime t[3];
   if(CopyHigh(Symbol(), tf, index, 3, h) < 3) return;
   if(CopyLow(Symbol(), tf, index, 3, l) < 3) return;
   if(CopyTime(Symbol(), tf, index, 3, t) < 3) return;
   
   // Index 0: candle[-1], Index 1: candle[0], Index 2: candle[1]
   double candle_minus_1_high = h[0];
   double candle_minus_1_low = l[0];
   double candle_plus_1_high = h[2];
   double candle_plus_1_low = l[2];
   datetime event_time = t[1]; // middle candle forms the gap
   
   double min_gap = m_fvg_min_pips * m_pip_value; 
   
   // Bullish FVG: candle[1].Low > candle[-1].High
   if(candle_plus_1_low > candle_minus_1_high && (candle_plus_1_low - candle_minus_1_high) >= min_gap)
     {
      m_last_bull_fvg.active = true;
      m_last_bull_fvg.high_price = candle_plus_1_low;
      m_last_bull_fvg.low_price = candle_minus_1_high;
      m_last_bull_fvg.time = event_time;
      if(m_draw_fvg)
        {
         string name = "CRT_FVG_BULL_" + TimeToString(event_time);
         DrawFVGBox(name, event_time, candle_plus_1_low, candle_minus_1_high, clrPaleGreen); // #EAF3DE equivalent
        }
     }
     
   // Bearish FVG: candle[1].High < candle[-1].Low
   if(candle_plus_1_high < candle_minus_1_low && (candle_minus_1_low - candle_plus_1_high) >= min_gap)
     {
      m_last_bear_fvg.active = true;
      m_last_bear_fvg.high_price = candle_minus_1_low;
      m_last_bear_fvg.low_price = candle_plus_1_high;
      m_last_bear_fvg.time = event_time;
      if(m_draw_fvg)
        {
         string name = "CRT_FVG_BEAR_" + TimeToString(event_time);
         DrawFVGBox(name, event_time, candle_minus_1_low, candle_plus_1_high, clrMistyRose); // #FCEBEB equivalent
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CCRTAnalyzer::AnalyzeOB(int index, ENUM_TIMEFRAMES tf)
  {
   if(!m_ob_enabled) return;
   // Very simplified Order Block detection based on strong impulse.
   // Real OB requires identifying breaks of structure. Here we look for momentum engulfing.
   double o[2], c[2], h[2], l[2];
   datetime t[2];
   if(CopyOpen(Symbol(), tf, index, 2, o) < 2) return;
   if(CopyHigh(Symbol(), tf, index, 2, h) < 2) return;
   if(CopyLow(Symbol(), tf, index, 2, l) < 2) return;
   if(CopyClose(Symbol(), tf, index, 2, c) < 2) return;
   if(CopyTime(Symbol(), tf, index, 2, t) < 2) return;
   
   bool prevBear = c[0] < o[0];
   bool currBull = c[1] > o[1];
   double currBody = c[1] - o[1];
   
   // Bullish OB: last bearish candle before strong bullish impulse
   if(prevBear && currBull && currBody > 20 * m_pip_value && c[1] > h[0])
     {
      m_last_bull_ob.active = true;
      m_last_bull_ob.high_price = h[0];
      m_last_bull_ob.low_price = l[0];
      m_last_bull_ob.time = t[0];
      if(m_draw_ob)
        {
         string name = "CRT_OB_BULL_" + TimeToString(t[0]);
         DrawOBBox(name, t[0], h[0], l[0], clrLightGreen);
        }
     }
     
   bool prevBull = c[0] > o[0];
   bool currBear = c[1] < o[1];
   currBody = o[1] - c[1];
   
   // Bearish OB: last bullish candle before strong bearish impulse
   if(prevBull && currBear && currBody > 20 * m_pip_value && c[1] < l[0])
     {
      m_last_bear_ob.active = true;
      m_last_bear_ob.high_price = h[0];
      m_last_bear_ob.low_price = l[0];
      m_last_bear_ob.time = t[0];
      if(m_draw_ob)
        {
         string name = "CRT_OB_BEAR_" + TimeToString(t[0]);
         DrawOBBox(name, t[0], h[0], l[0], clrLightCoral);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_AMD_PHASE CCRTAnalyzer::UpdateAMD(int index, ENUM_TIMEFRAMES tf, int &manip_direction)
  {
   manip_direction = 0; // 1 = sweep high (sell signal), -1 = sweep low (buy signal)
   
   double o[1], h[1], l[1], c[1];
   datetime t[1];
   if(CopyOpen(Symbol(), tf, index, 1, o) < 1) return AMD_NONE;
   if(CopyHigh(Symbol(), tf, index, 1, h) < 1) return AMD_NONE;
   if(CopyLow(Symbol(), tf, index, 1, l) < 1) return AMD_NONE;
   if(CopyClose(Symbol(), tf, index, 1, c) < 1) return AMD_NONE;
   if(CopyTime(Symbol(), tf, index, 1, t) < 1) return AMD_NONE;
   
   double cur_h = h[0], cur_l = l[0], cur_c = c[0], cur_o = o[0];
   
   // 1. Check Accumulation maintenance / creation
   // For a robust implementation, we would scan past N candles. Here we simulate it.
   // If we don't have an active acc range, try to form one by checking past candles.
   if(!m_acc_range.active)
     {
      double max_h = 0, min_l = 999999;
      double highs[], lows[], opens[], closes[];
      if(CopyHigh(Symbol(), tf, index, m_min_acc_candles, highs) == m_min_acc_candles &&
         CopyLow(Symbol(), tf, index, m_min_acc_candles, lows) == m_min_acc_candles &&
         CopyOpen(Symbol(), tf, index, m_min_acc_candles, opens) == m_min_acc_candles &&
         CopyClose(Symbol(), tf, index, m_min_acc_candles, closes) == m_min_acc_candles)
        {
         for(int i=0; i<m_min_acc_candles; i++)
           {
            if(highs[i] > max_h) max_h = highs[i];
            if(lows[i] < min_l) min_l = lows[i];
           }
         double range = max_h - min_l;
         // Adjusting range check for consolidation: 50 pips is a good universal threshold
         double max_acc_range = 50.0 * m_pip_value;
         if(range < max_acc_range) // Range is appropriately tight
           {
            m_acc_range.active = true;
            m_acc_range.high_price = max_h;
            m_acc_range.low_price = min_l;
            m_acc_range.start_time = t[0] - PeriodSeconds(tf)*m_min_acc_candles;
            m_acc_range.candles_count = m_min_acc_candles;
            if(m_draw_labels) DrawText("CRT_AMD_ACC_" + TimeToString(t[0]), "ACC", t[0], max_h + 10*m_point, clrLightBlue, ANCHOR_LOWER);
            return AMD_ACCUMULATION;
           }
        }
     }
   else
     {
      // We have an active accumulation. Check for Manipulation sweep.
      // Make wick requirement robust for Gold (treat 1 pip as 0.1 for XAUUSD strictly)
      double wick_req = m_min_wick_pips * m_pip_value;
      
      // Sweep Highs
      if(cur_h > m_acc_range.high_price + wick_req && cur_c < m_acc_range.high_price)
        {
         if(m_draw_labels) DrawText("CRT_AMD_MANIP_H_" + TimeToString(t[0]), "MANIP", t[0], cur_h + 10*m_point, clrSalmon, ANCHOR_LOWER);
         if(m_draw_pd) DrawPDZones("CRT_PD_" + TimeToString(t[0]), m_acc_range.start_time, t[0], cur_h, m_acc_range.low_price);
         manip_direction = 1; // Swept high, prepare to sell
         
         // After manipulation, range resets or transitions to distribution
         m_acc_range.active = false;
         return AMD_MANIPULATION;
        }
        
      // Sweep Lows
      if(cur_l < m_acc_range.low_price - wick_req && cur_c > m_acc_range.low_price)
        {
         if(m_draw_labels) DrawText("CRT_AMD_MANIP_L_" + TimeToString(t[0]), "MANIP", t[0], cur_l - 10*m_point, clrSalmon, ANCHOR_UPPER);
         if(m_draw_pd) DrawPDZones("CRT_PD_" + TimeToString(t[0]), m_acc_range.start_time, t[0], m_acc_range.high_price, cur_l);
         manip_direction = -1; // Swept low, prepare to buy
         
         m_acc_range.active = false;
         return AMD_MANIPULATION;
        }
        
      // Contained within range? Accumulation continues
      if(cur_h <= m_acc_range.high_price && cur_l >= m_acc_range.low_price)
        {
         m_acc_range.candles_count++;
         return AMD_ACCUMULATION;
        }
        
      // Breakout without rejection (Distribution start or invalid)
      if(cur_c > m_acc_range.high_price || cur_c < m_acc_range.low_price)
        {
         if(m_draw_labels) DrawText("CRT_AMD_DIST_" + TimeToString(t[0]), "DIST", t[0], cur_c, clrMediumAquamarine, ANCHOR_LEFT);
         m_acc_range.active = false;
         return AMD_DISTRIBUTION; // True breakout
        }
     }
     
   return AMD_NONE;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CCRTAnalyzer::AnalyzeStructure(ENUM_TIMEFRAMES tf)
  {
   // Basic ZigZag-like swing detection
   if(!m_draw_bos) return;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CCRTAnalyzer::IsInsideFVG(double price, int direction)
  {
   if(direction == -1) // Buy setup - check Bullish FVG
     {
      return (m_last_bull_fvg.active && price <= m_last_bull_fvg.high_price && price >= m_last_bull_fvg.low_price);
     }
   else if(direction == 1) // Sell setup - check Bearish FVG
     {
      return (m_last_bear_fvg.active && price <= m_last_bear_fvg.high_price && price >= m_last_bear_fvg.low_price);
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CCRTAnalyzer::IsInsideOB(double price, int direction)
  {
   if(direction == -1) // Buy setup - check Bullish OB
     {
      return (m_last_bull_ob.active && price <= m_last_bull_ob.high_price && price >= m_last_bull_ob.low_price);
     }
   else if(direction == 1) // Sell setup - check Bearish OB
     {
      return (m_last_bear_ob.active && price <= m_last_bear_ob.high_price && price >= m_last_bear_ob.low_price);
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
void CCRTAnalyzer::DrawFVGBox(string name, datetime t1, double p1, double p2, color clr)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t1 + PeriodSeconds(m_htf)*5, p2); // extended to right
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
     }
  }

void CCRTAnalyzer::DrawOBBox(string name, datetime t1, double p1, double p2, color clr)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t1 + PeriodSeconds(m_htf)*5, p2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
     }
  }

void CCRTAnalyzer::DrawPDZones(string name, datetime t1, datetime t2, double high, double low)
  {
   double eq = (high + low) / 2.0;
   
   string name_prem = name + "_PREM";
   string name_disc = name + "_DISC";
   string name_eq = name + "_EQ";
   
   if(ObjectFind(0, name_prem) < 0)
     {
      ObjectCreate(0, name_prem, OBJ_RECTANGLE, 0, t1, high, t2, eq);
      ObjectSetInteger(0, name_prem, OBJPROP_COLOR, clrMistyRose);
      ObjectSetInteger(0, name_prem, OBJPROP_BACK, true);
      ObjectSetInteger(0, name_prem, OBJPROP_FILL, true);
      ObjectSetInteger(0, name_prem, OBJPROP_HIDDEN, true);
     }
     
   if(ObjectFind(0, name_disc) < 0)
     {
      ObjectCreate(0, name_disc, OBJ_RECTANGLE, 0, t1, eq, t2, low);
      ObjectSetInteger(0, name_disc, OBJPROP_COLOR, clrPaleGreen);
      ObjectSetInteger(0, name_disc, OBJPROP_BACK, true);
      ObjectSetInteger(0, name_disc, OBJPROP_FILL, true);
      ObjectSetInteger(0, name_disc, OBJPROP_HIDDEN, true);
     }
     
   if(ObjectFind(0, name_eq) < 0)
     {
      ObjectCreate(0, name_eq, OBJ_TREND, 0, t1, eq, t2, eq);
      ObjectSetInteger(0, name_eq, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, name_eq, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name_eq, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name_eq, OBJPROP_HIDDEN, true);
     }
  }

void CCRTAnalyzer::DrawText(string name, string text, datetime t, double p, color clr, int anchor)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
  }

void CCRTAnalyzer::DrawTrendLine(string name, datetime t1, double p1, datetime t2, double p2, color clr, string text)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
  }
//+------------------------------------------------------------------+
