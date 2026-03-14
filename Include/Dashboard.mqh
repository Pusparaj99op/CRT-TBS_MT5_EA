//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                                  Copyright 2026, Antigravity AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      ""
#property strict

#include "Logger.mqh"
#include "RiskManager.mqh"
#include "TBS_Sessions.mqh"

class CDashboard
  {
private:
   ENUM_BASE_CORNER  m_corner;
   color             m_bg_color;
   color             m_text_color;
   color             m_header_color;
   color             m_border_color;
   
   string            m_prefix;
   bool              m_visible;
   
   CRiskManager     *m_risk;
   CTBSSessions     *m_tbs;
   
   void              CreateLabel(string name, string text, int x, int y, color clr, int font_size, bool bold);
   void              CreateRectLabel(string name, int x, int y, int w, int h, color bg, color border);

public:
                     CDashboard(ENUM_BASE_CORNER corner, int theme, CRiskManager *risk, CTBSSessions *tbs);
                    ~CDashboard(void);

   void              DrawBase(void);
   void              Update(double next_lot, string active_zone, string bias);
   void              Remove(void);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDashboard::CDashboard(ENUM_BASE_CORNER corner, int theme, CRiskManager *risk, CTBSSessions *tbs)
  {
   m_corner = corner;
   m_prefix = "CRT_DB_";
   m_visible = true;
   
   m_risk = risk;
   m_tbs = tbs;
   
   if(theme == 0) // DARK theme
     {
      m_bg_color = C'20,20,20';
      m_text_color = clrWhiteSmoke;
      m_header_color = clrGoldenrod;
      m_border_color = clrDimGray;
     }
   else // LIGHT theme
     {
      m_bg_color = C'240,240,240';
      m_text_color = clrBlack;
      m_header_color = clrDarkBlue;
      m_border_color = clrDarkGray;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDashboard::~CDashboard(void)
  {
   Remove();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CDashboard::Remove(void)
  {
   ObjectsDeleteAll(0, m_prefix);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CDashboard::CreateRectLabel(string name, int x, int y, int w, int h, color bg, color border)
  {
   name = m_prefix + name;
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_COLOR, border);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CDashboard::CreateLabel(string name, string text, int x, int y, color clr, int font_size, bool bold)
  {
   name = m_prefix + name;
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
      ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
     }
   else
     {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr); // allow color updates
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CDashboard::DrawBase(void)
  {
   int base_x = 20;
   int base_y = 20;
   int width = 220;
   int height = 300;
   
   CreateRectLabel("BG", base_x, base_y, width, height, m_bg_color, m_border_color);
   
   CreateLabel("Title", "CRT+TBS GOLD SCALPER", base_x + 10, base_y + 10, m_header_color, 11, true);
   
   // Headers
   CreateLabel("H_Acct", "ACCOUNT", base_x + 10, base_y + 35, clrGray, 8, true);
   CreateLabel("L_Name", "Name:", base_x + 10, base_y + 50, m_text_color, 8, false);
   CreateLabel("L_Bal", "Balance:", base_x + 10, base_y + 65, m_text_color, 8, false);
   CreateLabel("L_Eq", "Equity:", base_x + 10, base_y + 80, m_text_color, 8, false);
   CreateLabel("L_Pl", "Floating:", base_x + 10, base_y + 95, m_text_color, 8, false);
   
   CreateLabel("H_Marg", "MARGIN", base_x + 10, base_y + 115, clrGray, 8, true);
   CreateLabel("L_FMarg", "Free Mgn:", base_x + 10, base_y + 130, m_text_color, 8, false);
   CreateLabel("L_MLvl", "Mgn Lvl:", base_x + 10, base_y + 145, m_text_color, 8, false);
   
   CreateLabel("H_Mkt", "MARKET & TRADE", base_x + 10, base_y + 165, clrGray, 8, true);
   CreateLabel("L_Sprd", "Spread:", base_x + 10, base_y + 180, m_text_color, 8, false);
   CreateLabel("L_Lot", "Next Lot:", base_x + 10, base_y + 195, m_text_color, 8, false);
   CreateLabel("L_DPnl", "Daily P&L:", base_x + 10, base_y + 210, m_text_color, 8, false);
   CreateLabel("L_Trds", "Daily Trds:", base_x + 10, base_y + 225, m_text_color, 8, false);
   
   CreateLabel("H_Sess", "SESSION & STRATEGY", base_x + 10, base_y + 245, clrGray, 8, true);
   CreateLabel("L_KZ", "Kill Zone:", base_x + 10, base_y + 260, m_text_color, 8, false);
   CreateLabel("L_Bias", "HTF Bias:", base_x + 10, base_y + 275, m_text_color, 8, false);
   
   // Values Placeholders - dynamic positions
   for(int i=0; i<12; i++)
     {
      CreateLabel("V_"+IntegerToString(i), "-", base_x + 80, base_y + 50, m_text_color, 8, true);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CDashboard::Update(double next_lot, string active_zone, string bias)
  {
   if(!m_visible) return;
   
   int base_x = 20;
   int base_y = 20;
   int val_x = base_x + 90;
   
   // Account
   CreateLabel("V_Name", AccountInfoString(ACCOUNT_NAME), val_x, base_y + 50, m_text_color, 8, true);
   CreateLabel("V_Bal", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY), val_x, base_y + 65, m_text_color, 8, true);
   CreateLabel("V_Eq", DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2), val_x, base_y + 80, m_text_color, 8, true);
   
   double pl = AccountInfoDouble(ACCOUNT_PROFIT);
   color pl_clr = pl > 0 ? C'29,158,117' : (pl < 0 ? C'216,90,48' : m_text_color); // #1D9E75 / #D85A30
   CreateLabel("V_Pl", DoubleToString(pl, 2), val_x, base_y + 95, pl_clr, 8, true);
   
   // Margin
   CreateLabel("V_FMarg", DoubleToString(AccountInfoDouble(ACCOUNT_FREEMARGIN), 2), val_x, base_y + 130, m_text_color, 8, true);
   double mlevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   color ml_clr = mlevel < 150.0 && mlevel > 0 ? C'216,90,48' : m_text_color;
   CreateLabel("V_MLvl", mlevel == 0 ? "N/A" : DoubleToString(mlevel, 2) + "%", val_x, base_y + 145, ml_clr, 8, true);
   
   // Market
   CreateLabel("V_Sprd", IntegerToString(SymbolInfoInteger(Symbol(), SYMBOL_SPREAD)), val_x, base_y + 180, m_text_color, 8, true);
   CreateLabel("V_Lot", DoubleToString(next_lot, 2), val_x, base_y + 195, m_text_color, 8, true);
   
   double daily_pnl = m_risk != NULL ? m_risk.GetDailyPnL() : 0;
   int dt = m_risk != NULL ? m_risk.GetDailyTradesCount() : 0;
   color dp_clr = daily_pnl > 0 ? C'29,158,117' : (daily_pnl < 0 ? C'216,90,48' : m_text_color);
   
   CreateLabel("V_DPnl", DoubleToString(daily_pnl, 2), val_x, base_y + 210, dp_clr, 8, true);
   CreateLabel("V_Trds", IntegerToString(dt), val_x, base_y + 225, m_text_color, 8, true);
   
   // Session
   CreateLabel("V_KZ", active_zone, val_x, base_y + 260, active_zone != "None" ? C'29,158,117' : m_text_color, 8, true);
   CreateLabel("V_Bias", bias, val_x, base_y + 275, bias == "BULLISH" ? C'29,158,117' : (bias == "BEARISH" ? C'216,90,48' : m_text_color), 8, true);
  }
//+------------------------------------------------------------------+
