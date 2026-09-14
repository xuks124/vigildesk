//+------------------------------------------------------------------+
//|                                        VigilDeskGuardFree.mq5    |
//|            VigilDesk — account-level daily loss & risk sentinel  |
//|                                                                  |
//|  Free, open and self-contained: no DLLs, no WebRequest, no       |
//|  external dependencies — MQL5 Market compliant.                  |
//|                                                                  |
//|  What it guards (whole ACCOUNT, not just this chart):            |
//|    * a daily loss cap, measured from the balance at the start of |
//|      the broker's trading day;                                   |
//|    * a per-trade risk warning for the positions you hold;        |
//|    * the state is written to disk (common folder), so closing    |
//|      MetaTrader, restarting the EA or switching charts does NOT  |
//|      reset the cap.                                              |
//|                                                                  |
//|  What it deliberately does NOT do, because an EA inside the      |
//|  terminal cannot: restart your terminal after a crash, watch     |
//|  several accounts at once, or review orders before they are      |
//|  sent. Those are the job of the VigilDesk desktop workstation —  |
//|  https://xuks124.github.io/vigildesk/                            |
//|                                                                  |
//|  Reporting rule: percentages only. This EA never prints your     |
//|  balance or currency amounts anywhere, so screenshots are safe.  |
//+------------------------------------------------------------------+
#property copyright "VigilDesk"
#property link      "https://xuks124.github.io/vigildesk/"
#property version   "1.00"
#property description "Account-level daily loss guard with restart-proof state."
#property description "VigilDesk Guard Free: stops the one trade that ends the account."
#property description "Percentages only - no balance amounts are ever shown."

#include <Trade\Trade.mqh>

//--- inputs ---------------------------------------------------------
input group "Risk limits ｜ 风控上限"
input double InpDailyLossPct    = 1.5;   // Daily loss cap (% of day-start balance)
input double InpPerTradePct     = 0.5;   // Per-trade risk budget (% of balance)
input group "Behaviour when the daily cap is hit ｜ 击穿后的动作"
input bool   InpAlertOnBreach   = true;  // Popup + sound alert
input bool   InpPushOnBreach    = true;  // Mobile push (if configured in MT5)
input bool   InpEmailOnBreach   = false; // Email (if configured in MT5)
input bool   InpCloseOnBreach   = false; // Close all positions when the cap is hit
input bool   InpPublishFlag     = true;  // Publish a "blocked" flag your own EA can read
input group "Warnings ｜ 预警"
input bool   InpWarnAtPct       = true;  // Warn when this share of the cap is used
input double InpWarnAtUsedPct   = 70.0;  // Warn at (% of the daily cap used)
input int    InpPerTradeWarnMin = 5;     // Re-check open-position risk every N minutes
input group "Display ｜ 显示"
input bool   InpShowPanel       = true;  // Draw the status panel
input int    InpPanelCorner     = 0;     // 0=top-left 1=top-right 2=bottom-left 3=bottom-right
input int    InpPanelX          = 12;
input int    InpPanelY          = 22;
input color  InpColorOk         = clrLimeGreen;
input color  InpColorWarn       = clrOrange;
input color  InpColorBad        = clrTomato;

//--- state ----------------------------------------------------------
struct GuardState
{
   long   day_stamp;        // trading day this state belongs to (yyyymmdd)
   double day_start_balance;
   double day_start_equity;
   double cap_amount;
   bool   blocked;          // cap already breached today
   bool   warned;
   int    breach_count;
};

GuardState  g_state;
CTrade      g_trade;
string      g_state_file;
long        g_login = 0;
int         g_last_trade_check = 0;
bool        g_have_panel_objects = false;
string      g_prefix = "VDGF_";

//+------------------------------------------------------------------+
int OnInit()
{
   g_login = (long)AccountInfoInteger(ACCOUNT_LOGIN);
   g_state_file = StringFormat("VigilDesk\\guard_%I64d.json", g_login);
   ResetLastError();
   LoadState();
   RollDayIfNeeded(true);
   EventSetTimer(5);
   if(InpShowPanel)
      DrawPanel();
   PrintFormat("[VigilDesk Guard] active on account %I64d | daily cap %.2f%% | per-trade %.2f%% | "
               "state file: %s", g_login, InpDailyLossPct, InpPerTradePct, g_state_file);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   SaveState();
   ObjectsDeleteAll(0, g_prefix);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   RollDayIfNeeded(false);
   Evaluate();
   if(InpShowPanel)
      DrawPanel();
}

//+------------------------------------------------------------------+
void OnTick()
{
   Evaluate();
}

//+------------------------------------------------------------------+
//| Trading day (broker server time), and the day's opening balance   |
//+------------------------------------------------------------------+
long TradingDayStamp()
{
   MqlDateTime t;
   TimeToStruct(TimeTradeServer(), t);
   return((long)t.year * 10000 + t.mon * 100 + t.day);
}

void RollDayIfNeeded(const bool first_run)
{
   long today = TradingDayStamp();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_state.day_stamp != today || g_state.day_start_balance <= 0.0)
   {
      g_state.day_stamp         = today;
      g_state.day_start_balance = balance;
      g_state.day_start_equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      g_state.cap_amount        = balance * InpDailyLossPct / 100.0;
      g_state.blocked           = false;
      g_state.warned            = false;
      g_state.breach_count      = 0;
      SaveState();
      PublishFlag(false);
      if(!first_run)
         PrintFormat("[VigilDesk Guard] new trading day %I64d — cap reset to %.2f%% of the "
                     "opening balance", today, InpDailyLossPct);
   }
}

//+------------------------------------------------------------------+
//| The guard itself                                                   |
//+------------------------------------------------------------------+
void Evaluate()
{
   if(g_state.cap_amount <= 0.0)
      return;

   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double used    = g_state.day_start_balance - equity;      // > 0 means we are down
   double used_pct = (used / g_state.day_start_balance) * 100.0;

   //--- 1. cap breached?
   if(!g_state.blocked && used >= g_state.cap_amount)
   {
      g_state.blocked = true;
      g_state.breach_count++;
      SaveState();
      PublishFlag(true);
      FireBreach(used_pct);
      if(InpCloseOnBreach)
         CloseEverything();
      return;
   }

   //--- 2. early warning
   if(InpWarnAtPct && !g_state.warned && used >= g_state.cap_amount * (InpWarnAtUsedPct / 100.0))
   {
      g_state.warned = true;
      SaveState();
      string msg = StringFormat("VigilDesk Guard: %.2f%% of the %.2f%% daily cap is used. "
                                "Remaining before a stop: %.2f%%.", used_pct, InpDailyLossPct,
                                InpDailyLossPct - used_pct);
      Alert(msg);
      if(InpPushOnBreach)
         SendNotification(msg);
   }

   //--- 3. per-trade risk of the positions currently open
   if(InpPerTradeWarnMin > 0)
   {
      int now_min = (int)(TimeCurrent() / 60);
      if(now_min - g_last_trade_check >= InpPerTradeWarnMin)
      {
         g_last_trade_check = now_min;
         CheckOpenRisk();
      }
   }
}

//+------------------------------------------------------------------+
//| Warn when a single position risks more than the per-trade budget   |
//+------------------------------------------------------------------+
void CheckOpenRisk()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double budget  = balance * InpPerTradePct / 100.0;
   if(budget <= 0.0)
      return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      double sl = PositionGetDouble(POSITION_SL);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol = PositionGetDouble(POSITION_VOLUME);
      long type = PositionGetInteger(POSITION_TYPE);
      if(sl <= 0.0 || open <= 0.0 || vol <= 0.0)
         continue;
      double tick_value = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_TRADE_TICK_VALUE);
      double tick_size  = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_TRADE_TICK_SIZE);
      if(tick_value <= 0.0 || tick_size <= 0.0)
         continue;
      double distance = MathAbs(open - sl);
      double risk = (distance / tick_size) * tick_value * vol;
      if(risk > budget)
      {
         double over_pct = (risk / balance) * 100.0;
         string msg = StringFormat("VigilDesk Guard: position #%I64u risks %.2f%% of balance, "
                                   "above the %.2f%% per-trade budget.", ticket, over_pct,
                                   InpPerTradePct);
         Alert(msg);
         if(InpPushOnBreach)
            SendNotification(msg);
      }
   }
}

//+------------------------------------------------------------------+
void FireBreach(const double used_pct)
{
   string msg = StringFormat("VigilDesk Guard: daily loss cap reached (%.2f%% of %.2f%%). "
                             "New entries should stop for the rest of the trading day.",
                             used_pct, InpDailyLossPct);
   if(InpAlertOnBreach)
   {
      Alert(msg);
      PlaySound("alert2.wav");
   }
   if(InpPushOnBreach)
      SendNotification(msg);
   if(InpEmailOnBreach)
      SendMail("VigilDesk Guard: daily loss cap reached", msg);
   PrintFormat("[VigilDesk Guard] %s", msg);
}

//+------------------------------------------------------------------+
void CloseEverything()
{
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("[VigilDesk Guard] cannot close positions: algo trading is disabled in the terminal");
      return;
   }
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
         g_trade.PositionClose(ticket);
   }
   Print("[VigilDesk Guard] all positions closed because the daily cap was reached");
}

//+------------------------------------------------------------------+
//| Persistence: the whole point of this EA                           |
//| The state lives in the terminal's COMMON folder, keyed by account, |
//| so a restart, a chart change or a terminal reinstall cannot reset  |
//| the daily cap.                                                     |
//+------------------------------------------------------------------+
//| Publish the "blocked" flag as a terminal global variable.         |
//|                                                                   |
//| Your OWN EA can respect the guard with one line — which is the     |
//| only way an in-terminal tool can stop other EAs from trading:      |
//|                                                                   |
//|     if(GlobalVariableGet("VDGF_BLOCKED_" + (string)AccountInfoInteger(ACCOUNT_LOGIN)) > 0.0)
//|        return;   // the daily cap is gone for today                |
//|                                                                   |
//| The flag is cleared automatically on the next trading day.          |
//+------------------------------------------------------------------+
string FlagName()
{
   return(StringFormat("VDGF_BLOCKED_%I64d", g_login));
}

void PublishFlag(const bool blocked)
{
   if(!InpPublishFlag)
      return;
   GlobalVariableSet(FlagName(), blocked ? (double)TimeCurrent() : 0.0);
}

//+------------------------------------------------------------------+
void SaveState()
{
   int h = FileOpen(g_state_file, FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI);
   if(h == INVALID_HANDLE)
   {
      PrintFormat("[VigilDesk Guard] state save failed (%d) — the cap will not survive a restart",
                  GetLastError());
      return;
   }
   FileWriteString(h, StringFormat("{\"day\":%I64d,\"start_balance\":%.2f,\"start_equity\":%.2f,"
                                   "\"cap\":%.2f,\"blocked\":%s,\"warned\":%s,\"breaches\":%d}\n",
                                   g_state.day_stamp, g_state.day_start_balance,
                                   g_state.day_start_equity, g_state.cap_amount,
                                   g_state.blocked ? "true" : "false",
                                   g_state.warned ? "true" : "false", g_state.breach_count));
   FileClose(h);
}

void LoadState()
{
   if(!FileIsExist(g_state_file, FILE_COMMON))
      return;
   int h = FileOpen(g_state_file, FILE_READ | FILE_TXT | FILE_COMMON | FILE_ANSI);
   if(h == INVALID_HANDLE)
      return;
   string raw = "";
   while(!FileIsEnding(h))
      raw += FileReadString(h);
   FileClose(h);

   // Whitespace-insensitive: a state file written by another tool, hand-edited,
   // or produced by a JSON library ("blocked": true with a space) must still be
   // read correctly. Found by testing the restore path with a seeded file.
   string compact = "";
   int len = StringLen(raw);
   for(int i = 0; i < len; i++)
   {
      ushort c = StringGetCharacter(raw, i);
      if(c != ' ' && c != '\t' && c != '\n' && c != '\r')
         compact += ShortToString(c);
   }

   g_state.day_stamp         = (long)JsonNum(compact, "day");
   g_state.day_start_balance = JsonNum(compact, "start_balance");
   g_state.day_start_equity  = JsonNum(compact, "start_equity");
   g_state.cap_amount        = JsonNum(compact, "cap");
   g_state.blocked           = (StringFind(compact, "\"blocked\":true") >= 0);
   g_state.warned            = (StringFind(compact, "\"warned\":true") >= 0);
   g_state.breach_count      = (int)JsonNum(compact, "breaches");

   if(g_state.blocked && g_state.day_stamp == TradingDayStamp())
      PrintFormat("[VigilDesk Guard] restored state for today: the daily cap was already "
                  "reached (%.2f%%). Still blocked until the next trading day.", InpDailyLossPct);
   else if(g_state.day_stamp == TradingDayStamp())
      PrintFormat("[VigilDesk Guard] restored today's state: %.2f%% cap active.",
                  InpDailyLossPct);
   PublishFlag(g_state.blocked && g_state.day_stamp == TradingDayStamp());
}

double JsonNum(const string src, const string key)
{
   string needle = "\"" + key + "\":";
   int p = StringFind(src, needle);
   if(p < 0)
      return(0.0);
   p += StringLen(needle);
   int e = p;
   while(e < StringLen(src))
   {
      ushort c = StringGetCharacter(src, e);
      if(c == ',' || c == '}')
         break;
      e++;
   }
   return(StringToDouble(StringSubstr(src, p, e - p)));
}

//+------------------------------------------------------------------+
//| Chart panel — percentages only, never amounts                      |
//+------------------------------------------------------------------+
void DrawPanel()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double used = g_state.day_start_balance - equity;
   double used_pct = (g_state.day_start_balance > 0.0)
                     ? (used / g_state.day_start_balance) * 100.0 : 0.0;
   double left_pct = InpDailyLossPct - used_pct;
   color  c = g_state.blocked ? InpColorBad
              : (used_pct >= InpDailyLossPct * InpWarnAtUsedPct / 100.0 ? InpColorWarn
                                                                       : InpColorOk);

   string lines[6];
   lines[0] = "VigilDesk Guard  (free)";
   lines[1] = StringFormat("daily cap   %.2f%%", InpDailyLossPct);
   lines[2] = StringFormat("used today  %.2f%%", used_pct);
   lines[3] = StringFormat("remaining   %.2f%%", left_pct);
   lines[4] = StringFormat("state       %s", g_state.blocked ? "BLOCKED (cap hit)" : "guarding");
   lines[5] = StringFormat("per-trade   %.2f%% budget", InpPerTradePct);

   for(int i = 0; i < 6; i++)
   {
      string name = g_prefix + "L" + IntegerToString(i);
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, InpPanelCorner);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpPanelX);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpPanelY + i * 15);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (i == 0) ? 10 : 9);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
      ObjectSetString(0, name, OBJPROP_TEXT, lines[i]);
      ObjectSetInteger(0, name, OBJPROP_COLOR, (i == 0 || i == 4) ? c : clrSilver);
   }
   g_have_panel_objects = true;
   ChartRedraw();
}
//+------------------------------------------------------------------+
