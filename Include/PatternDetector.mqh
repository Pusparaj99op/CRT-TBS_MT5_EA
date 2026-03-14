//+------------------------------------------------------------------+
//|                                              PatternDetector.mqh |
//|                                  Copyright 2026, Antigravity AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      ""
#property strict

#include "Logger.mqh"

extern CLogger *g_logger;

enum ENUM_PATTERN_TYPE
  {
   PATTERN_NONE,
   PATTERN_DOJI,
   PATTERN_BULL_ENGULF,
   PATTERN_BEAR_ENGULF,
   PATTERN_HAMMER,
   PATTERN_SHOOTING_STAR,
   PATTERN_PIN_BAR,
   PATTERN_INSIDE_BAR,
   PATTERN_MORNING_STAR,
   PATTERN_EVENING_STAR,
   PATTERN_BULL_MARUBOZU,
   PATTERN_BEAR_MARUBOZU,
   PATTERN_TWEEZER_TOP,
   PATTERN_TWEEZER_BOTTOM
  };

class CPatternDetector
  {
private:
   ENUM_TIMEFRAMES   m_tf;
   bool              m_draw_labels;
   color             m_clr_bull;
   color             m_clr_bear;
   color             m_clr_neutral;
   
   double            m_point;
   int               m_digits;

   bool              IsDoji(double open, double high, double low, double close);
   bool              IsBullEngulfing(double open1, double high1, double low1, double close1, double open0, double high0, double low0, double close0);
   bool              IsBearEngulfing(double open1, double high1, double low1, double close1, double open0, double high0, double low0, double close0);
   bool              IsHammer(double open, double high, double low, double close);
   bool              IsShootingStar(double open, double high, double low, double close);
   bool              IsPinBar(double open, double high, double low, double close);
   bool              IsInsideBar(double high1, double low1, double high0, double low0);
   bool              IsBullMarubozu(double open, double high, double low, double close);
   bool              IsBearMarubozu(double open, double high, double low, double close);
   bool              IsTweezerTop(double high1, double close1, double open1, double high0, double close0, double open0);
   bool              IsTweezerBottom(double low1, double close1, double open1, double low0, double close0, double open0);
   bool              IsMorningStar(int index);
   bool              IsEveningStar(int index);

   void              DrawLabel(string name, string text, datetime time, double price, color clr, bool up);
   void              DrawArrow(string name, datetime time, double price, bool up);

public:
                     CPatternDetector(ENUM_TIMEFRAMES tf, bool draw_labels);
                    ~CPatternDetector(void);

   ENUM_PATTERN_TYPE DetectPattern(int index, string &pattern_name, int &score);
   void              ScanRecent(int bars);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPatternDetector::CPatternDetector(ENUM_TIMEFRAMES tf, bool draw_labels)
  {
   m_tf = tf;
   m_draw_labels = draw_labels;
   m_clr_bull = clrSeaGreen;
   m_clr_bear = clrIndianRed;
   m_clr_neutral = clrGray;
   
   m_point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   m_digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPatternDetector::~CPatternDetector(void)
  {
  }

//+------------------------------------------------------------------+
//| Helper Check Functions                                           |
//+------------------------------------------------------------------+
bool CPatternDetector::IsDoji(double open, double high, double low, double close)
  {
   double range = high - low;
   if(range == 0) return true;
   double body = MathAbs(open - close);
   return ((body / range) < 0.10);
  }

bool CPatternDetector::IsBullEngulfing(double open1, double high1, double low1, double close1, double open0, double high0, double low0, double close0)
  {
   bool prevBear = close1 < open1;
   bool currBull = close0 > open0;
   return (prevBear && currBull && close0 > open1 && open0 <= close1);
  }

bool CPatternDetector::IsBearEngulfing(double open1, double high1, double low1, double close1, double open0, double high0, double low0, double close0)
  {
   bool prevBull = close1 > open1;
   bool currBear = close0 < open0;
   return (prevBull && currBear && close0 < open1 && open0 >= close1);
  }

bool CPatternDetector::IsHammer(double open, double high, double low, double close)
  {
   if(close <= open) return false; // bullish required
   double range = high - low;
   if(range == 0) return false;
   double body = close - open;
   double lower_wick = open - low;
   double upper_wick = high - close;
   
   return (lower_wick >= 2 * body && upper_wick < body && (close - low) > (range * 0.66));
  }

bool CPatternDetector::IsShootingStar(double open, double high, double low, double close)
  {
   if(close >= open) return false; // bearish required
   double range = high - low;
   if(range == 0) return false;
   double body = open - close;
   double lower_wick = close - low;
   double upper_wick = high - open;
   
   return (upper_wick >= 2 * body && lower_wick < body && (high - open) > (range * 0.66));
  }

bool CPatternDetector::IsPinBar(double open, double high, double low, double close)
  {
   double range = high - low;
   if(range == 0) return false;
   double body = MathAbs(open - close);
   
   double max_body_high = MathMax(open, close);
   double min_body_low = MathMin(open, close);
   
   double upper_wick = high - max_body_high;
   double lower_wick = min_body_low - low;
   
   if(upper_wick > 2.5 * body && lower_wick < body) return true; // Bearish pin bar rejection
   if(lower_wick > 2.5 * body && upper_wick < body) return true; // Bullish pin bar rejection
   
   return false;
  }

bool CPatternDetector::IsInsideBar(double high1, double low1, double high0, double low0)
  {
   return (high0 < high1 && low0 > low1);
  }

bool CPatternDetector::IsBullMarubozu(double open, double high, double low, double close)
  {
   if(close <= open) return false;
   double range = high - low;
   if(range == 0) return false;
   double body = close - open;
   return ((body / range) > 0.85);
  }

bool CPatternDetector::IsBearMarubozu(double open, double high, double low, double close)
  {
   if(close >= open) return false;
   double range = high - low;
   if(range == 0) return false;
   double body = open - close;
   return ((body / range) > 0.85);
  }

bool CPatternDetector::IsTweezerTop(double high1, double close1, double open1, double high0, double close0, double open0)
  {
   bool prevBull = close1 > open1;
   bool currBear = close0 < open0;
   return (prevBull && currBear && MathAbs(high1 - high0) < 30 * m_point); // close highs
  }

bool CPatternDetector::IsTweezerBottom(double low1, double close1, double open1, double low0, double close0, double open0)
  {
   bool prevBear = close1 < open1;
   bool currBull = close0 > open0;
   return (prevBear && currBull && MathAbs(low1 - low0) < 30 * m_point); // close lows
  }

bool CPatternDetector::IsMorningStar(int index)
  {
   double o[3], h[3], l[3], c[3];
   if(CopyOpen(Symbol(), m_tf, index, 3, o) < 3) return false;
   if(CopyHigh(Symbol(), m_tf, index, 3, h) < 3) return false;
   if(CopyLow(Symbol(), m_tf, index, 3, l) < 3) return false;
   if(CopyClose(Symbol(), m_tf, index, 3, c) < 3) return false;

   // Index 0 is oldest, 1 is middle, 2 is newest (current 'index')
   bool cand1_bear = c[0] < o[0];
   double cand1_body = o[0] - c[0];
   
   bool cand2_doji = IsDoji(o[1], h[1], l[1], c[1]) || ((MathAbs(o[1] - c[1]) / (h[1]-l[1])) < 0.3);
   
   bool cand3_bull = c[2] > o[2];
   
   return (cand1_bear && cand1_body > 10*m_point && cand2_doji && cand3_bull && c[2] > (o[0]+c[0])/2.0);
  }

bool CPatternDetector::IsEveningStar(int index)
  {
   double o[3], h[3], l[3], c[3];
   if(CopyOpen(Symbol(), m_tf, index, 3, o) < 3) return false;
   if(CopyHigh(Symbol(), m_tf, index, 3, h) < 3) return false;
   if(CopyLow(Symbol(), m_tf, index, 3, l) < 3) return false;
   if(CopyClose(Symbol(), m_tf, index, 3, c) < 3) return false;

   // Index 0 is oldest, 1 is middle, 2 is newest (current 'index')
   bool cand1_bull = c[0] > o[0];
   double cand1_body = c[0] - o[0];
   
   bool cand2_doji = IsDoji(o[1], h[1], l[1], c[1]) || ((MathAbs(o[1] - c[1]) / (h[1]-l[1])) < 0.3);
   
   bool cand3_bear = c[2] < o[2];
   
   return (cand1_bull && cand1_body > 10*m_point && cand2_doji && cand3_bear && c[2] < (o[0]+c[0])/2.0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_PATTERN_TYPE CPatternDetector::DetectPattern(int index, string &pattern_name, int &score)
  {
   pattern_name = "";
   score = 0;
   
   double o[2], h[2], l[2], c[2];
   datetime t[2];
   if(CopyOpen(Symbol(), m_tf, index, 2, o) < 2) return PATTERN_NONE;
   if(CopyHigh(Symbol(), m_tf, index, 2, h) < 2) return PATTERN_NONE;
   if(CopyLow(Symbol(), m_tf, index, 2, l) < 2) return PATTERN_NONE;
   if(CopyClose(Symbol(), m_tf, index, 2, c) < 2) return PATTERN_NONE;
   if(CopyTime(Symbol(), m_tf, index, 2, t) < 2) return PATTERN_NONE;

   // candle 0 is oldest (index+1), candle 1 is newest (index) for ascending ordered Copy arrays
   double open1 = o[0], high1 = h[0], low1 = l[0], close1 = c[0]; // Prev candle
   double open0 = o[1], high0 = h[1], low0 = l[1], close0 = c[1]; // Cur candle
   datetime time0 = t[1];
   
   ENUM_PATTERN_TYPE ptype = PATTERN_NONE;
   color clr = m_clr_neutral;
   bool draw_arrow = false;
   bool arrow_up = false;
   double draw_price = low0 - 20 * m_point;

   if(IsMorningStar(index))
     {
      pattern_name = "MSTAR"; score = 1; clr = m_clr_bull; draw_arrow = true; arrow_up = true; ptype = PATTERN_MORNING_STAR; draw_price = low0 - 50*m_point;
     }
   else if(IsEveningStar(index))
     {
      pattern_name = "ESTAR"; score = 1; clr = m_clr_bear; draw_arrow = true; arrow_up = false; ptype = PATTERN_EVENING_STAR; draw_price = high0 + 50*m_point;
     }
   else if(IsTweezerTop(high1, close1, open1, high0, close0, open0))
     {
      pattern_name = "TWZR-T"; score = 1; clr = m_clr_bear; draw_arrow = true; arrow_up = false; ptype = PATTERN_TWEEZER_TOP; draw_price = high0 + 50*m_point;
     }
   else if(IsTweezerBottom(low1, close1, open1, low0, close0, open0))
     {
      pattern_name = "TWZR-B"; score = 1; clr = m_clr_bull; draw_arrow = true; arrow_up = true; ptype = PATTERN_TWEEZER_BOTTOM; draw_price = low0 - 50*m_point;
     }
   else if(IsBullEngulfing(open1, high1, low1, close1, open0, high0, low0, close0))
     {
      pattern_name = "BULL ENG"; score = 1; clr = m_clr_bull; draw_arrow = true; arrow_up = true; ptype = PATTERN_BULL_ENGULF; draw_price = low0 - 50*m_point;
     }
   else if(IsBearEngulfing(open1, high1, low1, close1, open0, high0, low0, close0))
     {
      pattern_name = "BEAR ENG"; score = 1; clr = m_clr_bear; draw_arrow = true; arrow_up = false; ptype = PATTERN_BEAR_ENGULF; draw_price = high0 + 50*m_point;
     }
   else if(IsPinBar(open0, high0, low0, close0))
     {
      pattern_name = "PIN"; score = 1; 
      if(open0 > close0) { clr = m_clr_bear; arrow_up = false; draw_price = high0 + 50*m_point; }
      else { clr = m_clr_bull; arrow_up = true; draw_price = low0 - 50*m_point; }
      draw_arrow = true; ptype = PATTERN_PIN_BAR;
     }
   else if(IsHammer(open0, high0, low0, close0))
     {
      pattern_name = "HAMMER"; score = 1; clr = m_clr_bull; draw_arrow = true; arrow_up = true; ptype = PATTERN_HAMMER; draw_price = low0 - 50*m_point;
     }
   else if(IsShootingStar(open0, high0, low0, close0))
     {
      pattern_name = "SHOOT*"; score = 1; clr = m_clr_bear; draw_arrow = true; arrow_up = false; ptype = PATTERN_SHOOTING_STAR; draw_price = high0 + 50*m_point;
     }
   else if(IsBullMarubozu(open0, high0, low0, close0))
     {
      pattern_name = "BULL MARU"; score = 1; clr = m_clr_bull; ptype = PATTERN_BULL_MARUBOZU; draw_price = low0 - 30*m_point;
     }
   else if(IsBearMarubozu(open0, high0, low0, close0))
     {
      pattern_name = "BEAR MARU"; score = 1; clr = m_clr_bear; ptype = PATTERN_BEAR_MARUBOZU; draw_price = high0 + 30*m_point;
     }
   else if(IsInsideBar(high1, low1, high0, low0))
     {
      pattern_name = "IB"; clr = m_clr_neutral; ptype = PATTERN_INSIDE_BAR; draw_price = low0 - 30*m_point;
     }
   else if(IsDoji(open0, high0, low0, close0))
     {
      pattern_name = "DOJI"; clr = m_clr_neutral; ptype = PATTERN_DOJI; draw_price = high0 + 30*m_point;
     }

   if(m_draw_labels && ptype != PATTERN_NONE)
     {
      string id = "CRT_Pat_" + TimeToString(time0) + "_" + pattern_name;
      DrawLabel(id, pattern_name, time0, draw_price, clr, arrow_up);
      if(draw_arrow) DrawArrow(id+"_A", time0, draw_price + (arrow_up ? -20*m_point : 20*m_point), arrow_up);
     }

   return ptype;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPatternDetector::DrawLabel(string name, string text, datetime time, double price, color clr, bool up)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPatternDetector::DrawArrow(string name, datetime time, double price, bool up)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, up ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, time, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, up ? m_clr_bull : m_clr_bear);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, up ? 233 : 234);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPatternDetector::ScanRecent(int bars)
  {
   string name;
   int score;
   for(int i = bars; i >= 1; i--)
     {
      DetectPattern(i, name, score);
     }
  }
//+------------------------------------------------------------------+
