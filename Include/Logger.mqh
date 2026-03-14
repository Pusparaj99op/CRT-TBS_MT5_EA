//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                  Copyright 2026, Antigravity AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      ""
#property strict

class CLogger
  {
private:
   bool              m_csv_enabled;
   string            m_file_name;
   int               m_file_handle;
   
   void              InitCSV(void);
   
public:
                     CLogger(bool enable_csv=true, string file_name="CRT_TBS_Journal.csv");
                    ~CLogger(void);
                    
   void              Log(string event, string symbol="", string timeframe="", 
                         double signal_score=0, string direction="", double lot=0, 
                         double entry=0, double sl=0, double tp1=0, double tp2=0, 
                         int spread=0, int slippage=0, double result_pips=0, 
                         double balance_after=0);
   void              LogSimple(string event);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLogger::CLogger(bool enable_csv=true, string file_name="CRT_TBS_Journal.csv")
  {
   m_csv_enabled = enable_csv;
   m_file_name = file_name;
   m_file_handle = INVALID_HANDLE;
   
   if(m_csv_enabled)
     {
      InitCSV();
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLogger::~CLogger(void)
  {
   if(m_file_handle != INVALID_HANDLE)
     {
      FileClose(m_file_handle);
      m_file_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLogger::InitCSV(void)
  {
   bool write_header = false;
   if(!FileIsExist(m_file_name))
     {
      write_header = true;
     }
     
   m_file_handle = FileOpen(m_file_name, FILE_CSV|FILE_READ|FILE_WRITE|FILE_ANSI, ',');
   if(m_file_handle != INVALID_HANDLE)
     {
      FileSeek(m_file_handle, 0, SEEK_END);
      if(write_header)
        {
         string header = "Timestamp,Event,Symbol,Timeframe,Signal_Score,Direction,Lot,Entry,SL,TP1,TP2,Spread,Slippage,Result_Pips,Balance_After";
         FileWrite(m_file_handle, header);
         FileFlush(m_file_handle);
        }
     }
   else
     {
      Print("Failed to open journal file: ", m_file_name, " Error: ", GetLastError());
      m_csv_enabled = false;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLogger::Log(string event, string symbol="", string timeframe="", 
                  double signal_score=0, string direction="", double lot=0, 
                  double entry=0, double sl=0, double tp1=0, double tp2=0, 
                  int spread=0, int slippage=0, double result_pips=0, 
                  double balance_after=0)
  {
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   
   // Formulate simple console log
   string console_msg = StringFormat("[%s] %s | %s | %s", timestamp, event, symbol, direction);
   Print(console_msg);
   
   if(m_csv_enabled && m_file_handle != INVALID_HANDLE)
     {
      FileSeek(m_file_handle, 0, SEEK_END);
      
      // Timestamp,Event,Symbol,Timeframe,Signal_Score,Direction,Lot,Entry,SL,TP1,TP2,Spread,Slippage,Result_Pips,Balance_After
      string line = StringFormat("%s,%s,%s,%s,%.1f,%s,%.2f,%.5f,%.5f,%.5f,%.5f,%d,%d,%.1f,%.2f",
         timestamp,
         event,
         symbol,
         timeframe,
         signal_score,
         direction,
         lot,
         entry,
         sl,
         tp1,
         tp2,
         spread,
         slippage,
         result_pips,
         balance_after
      );
      
      FileWriteString(m_file_handle, line + "\n");
      FileFlush(m_file_handle);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLogger::LogSimple(string event)
  {
   Log(event, Symbol(), EnumToString(Period()), 0, "", 0, 0, 0, 0, 0, 0, 0, 0, AccountInfoDouble(ACCOUNT_BALANCE));
  }
//+------------------------------------------------------------------+
