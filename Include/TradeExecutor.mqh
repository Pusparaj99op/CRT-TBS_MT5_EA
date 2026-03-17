//+------------------------------------------------------------------+
//|                                                TradeExecutor.mqh |
//|                                  Copyright 2026, Antigravity AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      ""
#property strict

#include <Trade/Trade.mqh>
#include "Logger.mqh"
#include "RiskManager.mqh"
#include "TBS_Sessions.mqh"

extern CLogger *g_logger;

class CTradeExecutor
  {
private:
   CTrade            m_trade;
   CRiskManager     *m_risk;
   CTBSSessions     *m_tbs;
   
   ulong             m_magic;
   bool              m_entry_on_close;
   bool              m_allow_multiple;
   
   double            m_tp1_rr;
   double            m_tp2_rr;
   double            m_tp1_pct;
   bool              m_breakeven;
   bool              m_trailing;
   double            m_trail_pips;
   
   int               m_max_slippage;
   
   double            m_point;
   int               m_digits;

   bool              PlaceOrder(ENUM_ORDER_TYPE type, double vol, double price, double sl, double tp, string comment);

public:
                     CTradeExecutor(ulong magic, CRiskManager *risk, CTBSSessions *tbs,
                                    bool allow_multiple, bool entry_on_close,
                                    double tp1_rr, double tp2_rr, double tp1_pct,
                                    bool breakeven, bool trailing, double trail_pips, int max_slip);
                    ~CTradeExecutor(void);

   void              ExecuteSignal(int direction, double entry_price, double sl_price, int score, string pattern_name);
   
   void              ManageOpenPositions(void);
   void              CloseAllPositions(string reason);
   
   int               GetOpenPositionsCount(void);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTradeExecutor::CTradeExecutor(ulong magic, CRiskManager *risk, CTBSSessions *tbs,
                               bool allow_multiple, bool entry_on_close,
                               double tp1_rr, double tp2_rr, double tp1_pct,
                               bool breakeven, bool trailing, double trail_pips, int max_slip)
  {
   m_magic = magic;
   m_risk = risk;
   m_tbs = tbs;
   
   m_allow_multiple = allow_multiple;
   m_entry_on_close = entry_on_close;
   
   m_tp1_rr = tp1_rr;
   m_tp2_rr = tp2_rr;
   m_tp1_pct = tp1_pct;
   
   m_breakeven = breakeven;
   m_trailing = trailing;
   m_trail_pips = trail_pips;
   
   m_max_slippage = max_slip;
   
   m_point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   m_digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   
   m_trade.SetExpertMagicNumber(m_magic);
   m_trade.SetDeviationInPoints(m_max_slippage);
   // Let CTrade automatically handle the filling mode
   // m_trade.SetTypeFilling(ORDER_FILLING_FOK);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTradeExecutor::~CTradeExecutor(void)
  {
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CTradeExecutor::GetOpenPositionsCount(void)
  {
   int count = 0;
   for(int i=0; i<PositionsTotal(); i++)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol == Symbol() && PositionGetInteger(POSITION_MAGIC) == m_magic)
        {
         count++;
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::PlaceOrder(ENUM_ORDER_TYPE type, double vol, double price, double sl, double tp, string comment)
  {
   bool res = false;
   if(type == ORDER_TYPE_BUY)
     {
      res = m_trade.Buy(vol, Symbol(), price, sl, tp, comment);
      if (!res && g_logger != NULL) g_logger.LogSimple("Buy Order Failed! Vol: " + DoubleToString(vol, 2) + " Code: " + IntegerToString(m_trade.ResultRetcode()));
     }
   else
     {
      res = m_trade.Sell(vol, Symbol(), price, sl, tp, comment);
      if (!res && g_logger != NULL) g_logger.LogSimple("Sell Order Failed! Vol: " + DoubleToString(vol, 2) + " Code: " + IntegerToString(m_trade.ResultRetcode()));
     }
     
   if(res && g_logger != NULL)
     {
      g_logger.Log("TRADE_OPENED", Symbol(), "", 0, type==ORDER_TYPE_BUY?"BUY":"SELL", vol, price, sl, tp, 0, (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD), 0, 0, AccountInfoDouble(ACCOUNT_BALANCE));
      m_risk.RegisterTrade();
     }
   return res;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTradeExecutor::ExecuteSignal(int direction, double entry_price, double sl_price, int score, string pattern_name)
  {
   if(!m_allow_multiple && GetOpenPositionsCount() > 0) return;
   
   if(!m_risk.IsSpreadAcceptable())
     {
      if(g_logger != NULL) g_logger.LogSimple("Signal Rejected: Spread too high: " + IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_SPREAD)));
      return;
     }
     
   if(m_risk.IsDailyLimitReached())
     {
      if(g_logger != NULL) g_logger.LogSimple("Signal Rejected: Daily limits reached");
      return;
     }

   double lot = m_risk.CalculateLotSize(entry_price, sl_price);
   if(lot <= 0 || !m_risk.IsMarginSufficient(lot))
     {
      if(g_logger != NULL) g_logger.LogSimple("Signal Rejected: Lot/Margin issue. Lot=" + DoubleToString(lot, 2));
      return;
     }

   double risk_pips = MathAbs(entry_price - sl_price);
   
   double tp1_price = 0, tp2_price = 0;
   if(direction == -1) // Buy
     {
      tp1_price = entry_price + (risk_pips * m_tp1_rr);
      if(m_tp2_rr > 0) tp2_price = entry_price + (risk_pips * m_tp2_rr);
      
      string comm = "T1|"+pattern_name+"|B";
      
      // If TP2 enabled, split into two positions
      if(m_tp2_rr > 0)
        {
         double lot1 = NormalizeDouble(lot * (m_tp1_pct / 100.0), 2);
         double lot2 = NormalizeDouble(lot - lot1, 2);
         
         double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         if(lot1 > 0) PlaceOrder(ORDER_TYPE_BUY, lot1, ask, sl_price, tp1_price, comm);
         if(lot2 > 0) PlaceOrder(ORDER_TYPE_BUY, lot2, ask, sl_price, tp2_price, "T2|"+pattern_name+"|B");
        }
      else
        {
         double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         PlaceOrder(ORDER_TYPE_BUY, lot, ask, sl_price, tp1_price, comm);
        }
     }
   else // Sell
     {
      tp1_price = entry_price - (risk_pips * m_tp1_rr);
      if(m_tp2_rr > 0) tp2_price = entry_price - (risk_pips * m_tp2_rr);
      
      string comm = "T1|"+pattern_name+"|S";
      
      if(m_tp2_rr > 0)
        {
         double lot1 = NormalizeDouble(lot * (m_tp1_pct / 100.0), 2);
         double lot2 = NormalizeDouble(lot - lot1, 2);
         
         double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         if(lot1 > 0) PlaceOrder(ORDER_TYPE_SELL, lot1, bid, sl_price, tp1_price, comm);
         if(lot2 > 0) PlaceOrder(ORDER_TYPE_SELL, lot2, bid, sl_price, tp2_price, "T2|"+pattern_name+"|S");
        }
      else
        {
         double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         PlaceOrder(ORDER_TYPE_SELL, lot, bid, sl_price, tp1_price, comm);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageOpenPositions(void)
  {
   // Handle trailing stops and breakeven
   if(!m_breakeven && !m_trailing) return;
   
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == m_magic)
        {
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         long type = PositionGetInteger(POSITION_TYPE);
         double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         
         double profit_pips = 0;
         if(type == POSITION_TYPE_BUY) profit_pips = (current_price - open_price) / m_point;
         else profit_pips = (open_price - current_price) / m_point;
         
         double risk_pips = MathAbs(open_price - sl) / m_point; // Initial risk if SL hasn't been modified heavily
         if(sl == 0) continue; // Safety
         
         // Basic breakeven logic: if we reached 1R profit, move SL to open
         bool modified = false;
         double new_sl = sl;
         
         if(m_breakeven && profit_pips >= risk_pips)
           {
            if(type == POSITION_TYPE_BUY && sl < open_price) 
              { new_sl = open_price + (20 * m_point); modified = true; }
            if(type == POSITION_TYPE_SELL && sl > open_price) 
              { new_sl = open_price - (20 * m_point); modified = true; }
           }
           
         // Trailing Stop logic
         if(m_trailing && profit_pips >= risk_pips)
           {
            double sym_point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            int sym_digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
            double pip_val = (sym_digits == 3 || sym_digits == 5) ? sym_point * 10.0 : sym_point;
            if(StringFind(Symbol(), "XAU") >= 0 || StringFind(Symbol(), "GOLD") >= 0) pip_val = 0.1;

            double trail = m_trail_pips * pip_val;
            if(type == POSITION_TYPE_BUY && current_price - trail > new_sl)
              { new_sl = current_price - trail; modified = true; }
            if(type == POSITION_TYPE_SELL && current_price + trail < new_sl && new_sl > 0)
              { new_sl = current_price + trail; modified = true; }
           }
           
         if(modified && new_sl != sl)
           {
            m_trade.PositionModify(ticket, new_sl, tp);
            if(g_logger != NULL) g_logger.LogSimple("Modified SL for ticket " + IntegerToString(ticket));
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTradeExecutor::CloseAllPositions(string reason)
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == m_magic)
        {
         m_trade.PositionClose(ticket);
         if(g_logger != NULL) g_logger.LogSimple("Closed position " + IntegerToString(ticket) + " Reason: " + reason);
        }
     }
  }
//+------------------------------------------------------------------+
