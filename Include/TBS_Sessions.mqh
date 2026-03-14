//+------------------------------------------------------------------+
//|                                                 TBS_Sessions.mqh |
//|                                  Copyright 2026, Antigravity AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      ""
#property strict

#include "Logger.mqh"

extern CLogger *g_logger;

class CTBSSessions
  {
private:
   int               m_utc_offset;
   bool              m_auto_detect;
   
   bool              m_asian_kz;
   bool              m_london_kz;
   bool              m_ny_kz;
   bool              m_nypm_kz;
   
   bool              m_draw_zones;
   bool              m_draw_levels;
   
   datetime          m_current_day;
   
   double            m_midnight_open;
   double            m_london_open;
   double            m_ny_open;
   double            m_pdh;
   double            m_pdl;
   
   void              CalculateUTCOffset(void);
   void              DrawRectangle(string name, datetime time1, datetime time2, double price1, double price2, color clr);
   void              DrawHLine(string name, double price, color clr, ENUM_LINE_STYLE style, string label);
   void              DrawZonesForDay(datetime day_start);
   void              UpdateLevels(datetime current_time);
   datetime          GetBrokerTimeFromUTC(datetime day_start, int utc_hour, int utc_minute);

public:
                     CTBSSessions(int manual_offset, bool auto_detect,
                                  bool asian_kz, bool london_kz, bool ny_kz, bool nypm_kz,
                                  bool draw_zones, bool draw_levels);
                    ~CTBSSessions(void);
                    
   void              Init(void);
   void              Update(void);
   
   bool              IsAnyKillZoneActive(void);
   bool              IsKillZoneActive(string &zone_name, int &score);
   
   double            GetMidnightOpen() { return m_midnight_open; }
   double            GetLondonOpen()   { return m_london_open; }
   double            GetNYOpen()       { return m_ny_open; }
   double            GetPDH()          { return m_pdh; }
   double            GetPDL()          { return m_pdl; }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTBSSessions::CTBSSessions(int manual_offset, bool auto_detect,
                           bool asian_kz, bool london_kz, bool ny_kz, bool nypm_kz,
                           bool draw_zones, bool draw_levels)
  {
   m_utc_offset = manual_offset;
   m_auto_detect = auto_detect;
   m_asian_kz = asian_kz;
   m_london_kz = london_kz;
   m_ny_kz = ny_kz;
   m_nypm_kz = nypm_kz;
   m_draw_zones = draw_zones;
   m_draw_levels = draw_levels;
   
   m_current_day = 0;
   m_midnight_open = 0;
   m_london_open = 0;
   m_ny_open = 0;
   m_pdh = 0;
   m_pdl = 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTBSSessions::~CTBSSessions(void)
  {
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTBSSessions::Init(void)
  {
   CalculateUTCOffset();
   Update();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTBSSessions::CalculateUTCOffset(void)
  {
   if(m_auto_detect || m_utc_offset == 999)
     {
      // Broker time = Server time. TimeCurrent() returns Server Time
      datetime server_time = TimeCurrent();
      datetime gmt_time = TimeGMT();
      m_utc_offset = (int)MathRound((double)(server_time - gmt_time) / 3600.0);
      if(g_logger != NULL)
        {
         g_logger.LogSimple("CTBSSessions: Auto-detected UTC offset = " + IntegerToString(m_utc_offset) + " hours.");
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime CTBSSessions::GetBrokerTimeFromUTC(datetime day_start, int utc_hour, int utc_minute)
  {
   // day_start is aligned to 00:00:00 of broker server day.
   // Wait, if day_start is broker local, 00:00 broker time = (0 - offset) UTC time.
   // To get a target UTC time translated to broker time on the SAME active trading day:
   // Example: UTC 02:00 -> Broker Time = 02:00 + offset
   int broker_hour = utc_hour + m_utc_offset;
   
   // Normalize hours (not handling full weekend logic here, assuming standard weekday offset)
   if(broker_hour >= 24) broker_hour -= 24;
   if(broker_hour < 0) broker_hour += 24;
   
   return day_start + (broker_hour * 3600) + (utc_minute * 60);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTBSSessions::Update(void)
  {
   datetime current_time = TimeCurrent();
   datetime day_start = current_time - (current_time % 86400); // 00:00:00 of current broker day
   
   if(day_start != m_current_day)
     {
      m_current_day = day_start;
      UpdateLevels(current_time);
      if(m_draw_zones)
        {
         DrawZonesForDay(m_current_day);
        }
     }
   
   // Check session price openings if they act as reference and time has passed
   datetime ldn_time = GetBrokerTimeFromUTC(m_current_day, 2, 0); // 02:00 UTC
   datetime ny_time = GetBrokerTimeFromUTC(m_current_day, 7, 0);  // 07:00 UTC
   datetime midnight_time = GetBrokerTimeFromUTC(m_current_day, 0, 0); // 00:00 UTC
   
   if(m_london_open == 0 && current_time >= ldn_time)
     {
      double open[];
      if(CopyOpen(Symbol(), PERIOD_M1, ldn_time, 1, open) > 0)
        {
         m_london_open = open[0];
         if(m_draw_levels) DrawHLine("CRT_LDN_Open", m_london_open, clrCornflowerBlue, STYLE_DASH, "LDN Open");
        }
     }
     
   if(m_ny_open == 0 && current_time >= ny_time)
     {
      double open[];
      if(CopyOpen(Symbol(), PERIOD_M1, ny_time, 1, open) > 0)
        {
         m_ny_open = open[0];
         if(m_draw_levels) DrawHLine("CRT_NY_Open", m_ny_open, clrGoldenrod, STYLE_DASH, "NY Open");
        }
     }

   if(m_midnight_open == 0 && current_time >= midnight_time)
     {
      double open[];
      if(CopyOpen(Symbol(), PERIOD_M1, midnight_time, 1, open) > 0)
        {
         m_midnight_open = open[0];
         if(m_draw_levels) DrawHLine("CRT_Midnight_Open", m_midnight_open, clrGray, STYLE_DASH, "Zero Open");
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTBSSessions::UpdateLevels(datetime current_time)
  {
   // Reset daily open levels
   m_midnight_open = 0;
   m_london_open = 0;
   m_ny_open = 0;
   
   // Fetch PDH and PDL
   double high[], low[];
   if(CopyHigh(Symbol(), PERIOD_D1, 1, 1, high) > 0) m_pdh = high[0];
   if(CopyLow(Symbol(), PERIOD_D1, 1, 1, low) > 0) m_pdl = low[0];
   
   if(m_draw_levels)
     {
      if(m_pdh > 0) DrawHLine("CRT_PDH", m_pdh, clrAquamarine, STYLE_DOT, "PDH");
      if(m_pdl > 0) DrawHLine("CRT_PDL", m_pdl, clrLightCoral, STYLE_DOT, "PDL");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTBSSessions::DrawZonesForDay(datetime day_start)
  {
   string prefix = "CRT_KZ_" + TimeToString(day_start, TIME_DATE) + "_";
   double top = 0; // We will use a reasonably large box for background
   double bot = 0;
   
   // Try to get max min of the day
   double high[], low[];
   if(CopyHigh(Symbol(), PERIOD_D1, 0, 1, high) > 0 && CopyLow(Symbol(), PERIOD_D1, 0, 1, low) > 0)
     {
      top = high[0] + 50.0; // extended slightly
      bot = low[0] - 50.0;
     }

   if(m_asian_kz)
     {
      datetime t1 = GetBrokerTimeFromUTC(day_start, 0, 0);
      datetime t2 = GetBrokerTimeFromUTC(day_start, 3, 0);
      DrawRectangle(prefix + "Asian", t1, t2, top, bot, clrThistle);
     }
     
   if(m_london_kz)
     {
      datetime t1 = GetBrokerTimeFromUTC(day_start, 2, 0);
      datetime t2 = GetBrokerTimeFromUTC(day_start, 5, 0);
      DrawRectangle(prefix + "London", t1, t2, top, bot, clrLightSkyBlue);
     }
     
   if(m_ny_kz)
     {
      datetime t1 = GetBrokerTimeFromUTC(day_start, 7, 0);
      datetime t2 = GetBrokerTimeFromUTC(day_start, 10, 0);
      DrawRectangle(prefix + "NY", t1, t2, top, bot, clrNavajoWhite);
     }
     
   if(m_nypm_kz)
     {
      datetime t1 = GetBrokerTimeFromUTC(day_start, 13, 0);
      datetime t2 = GetBrokerTimeFromUTC(day_start, 16, 0);
      DrawRectangle(prefix + "NYPM", t1, t2, top, bot, clrPaleGreen);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTBSSessions::DrawRectangle(string name, datetime time1, datetime time2, double price1, double price2, color clr)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true); // Hide from object list
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
     }
   else
     {
      ObjectMove(0, name, 0, time1, price1);
      ObjectMove(0, name, 1, time2, price2);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTBSSessions::DrawHLine(string name, double price, color clr, ENUM_LINE_STYLE style, string label)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetString(0, name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
     }
   else
     {
      ObjectMove(0, name, 0, 0, price);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTBSSessions::IsKillZoneActive(string &zone_name, int &score)
  {
   datetime current = TimeCurrent();
   datetime day_start = current - (current % 86400);
   
   zone_name = "None";
   score = 0;
   
   if(m_asian_kz)
     {
      datetime t1 = GetBrokerTimeFromUTC(day_start, 0, 0);
      datetime t2 = GetBrokerTimeFromUTC(day_start, 3, 0);
      if(current >= t1 && current <= t2)
        {
         zone_name = "Asian";
         score = 1;
         return true;
        }
     }
     
   if(m_london_kz)
     {
      datetime t1 = GetBrokerTimeFromUTC(day_start, 2, 0);
      datetime t2 = GetBrokerTimeFromUTC(day_start, 5, 0);
      if(current >= t1 && current <= t2)
        {
         zone_name = "London";
         score = 1;
         return true;
        }
     }
     
   if(m_ny_kz)
     {
      datetime t1 = GetBrokerTimeFromUTC(day_start, 7, 0);
      datetime t2 = GetBrokerTimeFromUTC(day_start, 10, 0);
      if(current >= t1 && current <= t2)
        {
         zone_name = "New York";
         score = 1;
         return true;
        }
     }
     
   if(m_nypm_kz)
     {
      datetime t1 = GetBrokerTimeFromUTC(day_start, 13, 0);
      datetime t2 = GetBrokerTimeFromUTC(day_start, 16, 0);
      if(current >= t1 && current <= t2)
        {
         zone_name = "NY PM";
         score = 1;
         return true;
        }
     }
     
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CTBSSessions::IsAnyKillZoneActive(void)
  {
   string name;
   int score;
   return IsKillZoneActive(name, score);
  }
//+------------------------------------------------------------------+
