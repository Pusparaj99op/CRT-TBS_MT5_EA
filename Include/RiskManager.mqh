//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                  Copyright 2026, Antigravity AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      ""
#property strict

#include "Logger.mqh"

extern CLogger *g_logger;

class CRiskManager
  {
private:
   int               m_risk_mode;
   double            m_fixed_lot;
   double            m_risk_percent;
   double            m_max_lot;
   
   double            m_max_spread_pips;
   int               m_max_slippage;
   int               m_max_daily_trades;
   double            m_max_daily_loss_pct;
   
   datetime          m_current_day;
   int               m_trades_today;
   double            m_start_of_day_balance;
   
   double            m_point;
   int               m_digits;
   double            m_tick_value;
   double            m_tick_size;

public:
                     CRiskManager(int risk_mode, double fixed_lot, double risk_percent, double max_lot,
                                  double max_spread, int max_slippage, int max_daily_trades, double max_daily_loss);
                    ~CRiskManager(void);

   void              UpdateDailyStats(void);
   
   double            CalculateLotSize(double entry_price, double sl_price);
   bool              IsSpreadAcceptable(void);
   bool              IsDailyLimitReached(void);
   bool              IsMarginSufficient(double lot_size);
   
   double            GetDailyPnL(void);
   int               GetDailyTradesCount(void) { return m_trades_today; }
   void              RegisterTrade(void) { m_trades_today++; }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(int risk_mode, double fixed_lot, double risk_percent, double max_lot,
                           double max_spread, int max_slippage, int max_daily_trades, double max_daily_loss)
  {
   m_risk_mode = risk_mode; // 0=FIXED, 1=PERCENT, 2=DOLLAR
   m_fixed_lot = fixed_lot;
   m_risk_percent = risk_percent;
   m_max_lot = max_lot;
   
   m_max_spread_pips = max_spread;
   m_max_slippage = max_slippage;
   m_max_daily_trades = max_daily_trades;
   m_max_daily_loss_pct = max_daily_loss;
   
   m_point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   m_digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   m_tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   m_tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   
   m_current_day = 0;
   m_trades_today = 0;
   m_start_of_day_balance = AccountInfoDouble(ACCOUNT_BALANCE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager(void)
  {
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CRiskManager::UpdateDailyStats(void)
  {
   datetime current_time = TimeCurrent();
   datetime day_start = current_time - (current_time % 86400);
   
   if(day_start != m_current_day)
     {
      // New day reset
      m_current_day = day_start;
      m_trades_today = 0;
      m_start_of_day_balance = AccountInfoDouble(ACCOUNT_BALANCE);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(double entry_price, double sl_price)
  {
   double lot = m_fixed_lot;
   
   if(m_risk_mode == 1) // PERCENT_RISK
     {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount = balance * (m_risk_percent / 100.0);
      
      double sl_distance_points = MathAbs(entry_price - sl_price) / m_point;
      if(sl_distance_points <= 0) return 0;
      
      // Calculate taking into account tick size
      double ticks = sl_distance_points * (m_point / m_tick_size);
      double loss_per_lot = ticks * m_tick_value;
      
      if(loss_per_lot > 0) lot = risk_amount / loss_per_lot;
     }
   
   // Normalize lot size
   double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max_lot_sym = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   
   lot = MathMax(lot, min_lot);
   lot = MathMin(lot, max_lot_sym);
   lot = MathMin(lot, m_max_lot);
   
   lot = MathRound(lot / lot_step) * lot_step;
   
   return lot;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CRiskManager::IsSpreadAcceptable(void)
  {
   long spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   
   double sym_point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   int sym_digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   double pip_val = (sym_digits == 3 || sym_digits == 5) ? sym_point * 10.0 : sym_point;
   if(StringFind(Symbol(), "XAU") >= 0 || StringFind(Symbol(), "GOLD") >= 0) pip_val = 0.1;

   double max_spread_points = m_max_spread_pips * (pip_val / sym_point);

   if(spread > max_spread_points)
     {
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CRiskManager::IsDailyLimitReached(void)
  {
   if(m_max_daily_trades > 0 && m_trades_today >= m_max_daily_trades)
     {
      return true;
     }
     
   if(m_max_daily_loss_pct > 0)
     {
      double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(current_equity < m_start_of_day_balance)
        {
         double loss_pct = ((m_start_of_day_balance - current_equity) / m_start_of_day_balance) * 100.0;
         if(loss_pct >= m_max_daily_loss_pct)
           {
            return true;
           }
        }
     }
     
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CRiskManager::IsMarginSufficient(double lot_size)
  {
   double margin_req = 0;
   
   if(OrderCalcMargin(ORDER_TYPE_BUY, Symbol(), lot_size, SymbolInfoDouble(Symbol(), SYMBOL_ASK), margin_req))
     {
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      return (free_margin > margin_req);
     }
   return false; // Calculation failed
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CRiskManager::GetDailyPnL(void)
  {
   return AccountInfoDouble(ACCOUNT_EQUITY) - m_start_of_day_balance;
  }
//+------------------------------------------------------------------+
