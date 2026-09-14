# VigilDesk Guard Free (MQL5)

An account-level daily loss guard for MetaTrader 5 with **restart-proof state** —
the one thing most in-terminal guardians get wrong.

    VigilDeskGuardFree.mq5   source (compile with MetaEditor)
    VigilDeskGuardFree.ex5   compiled, ready to attach

## What it does

* **Daily loss cap** (default 1.5% of the balance at the start of the broker's
  trading day). When it trips: alert, optional mobile push / email, optional
  close-all-positions, and the day is *blocked*.
* **Per-trade risk warning** — recomputes the risk of your open positions against
  a budget (default 0.5% of balance) and speaks up when one is over.
* **Early warning** at 70% of the cap used, so you hear it before it is too late.
* **An on-chart panel** showing cap used / remaining / state — percentages only.

## Why the state is written to disk

Close MetaTrader, restart the EA, switch charts, recompile, reinstall the
terminal: the cap does **not** reset. Most guardians keep that state in memory, so
a restart quietly hands you back the full day's risk — exactly when things are
going badly.

The state lives in the terminal's common folder, keyed by account number:

    %APPDATA%\MetaQuotes\Terminal\Common\Files\VigilDesk\guard_<login>.json

## Let your own EA respect the guard

When the cap trips the EA publishes a terminal global variable. Your own code can
honour it with one line:

```mql5
if(GlobalVariableGet("VDGF_BLOCKED_" +
   (string)AccountInfoInteger(ACCOUNT_LOGIN)) > 0.0)
   return;                       // the daily cap is gone for today
```

## Privacy

It never prints or stores your balance, equity or currency amounts anywhere —
every number you see is a percentage. Screenshots and logs are safe to share.

## What it cannot do (by design)

This is an Expert Advisor: it runs *inside* MetaTrader. It therefore cannot

* restart your terminal after a crash or a hang (if the terminal is dead, so is
  the EA — and your positions sit there unprotected),
* watch several accounts from one screen,
* review an order before another EA or a Python strategy sends it.

Those need a process outside the terminal, which is what the VigilDesk desktop
workstation does: **https://xuks124.github.io/vigildesk/**

## Verification

* Compiles with **0 errors, 0 warnings** on MetaEditor build 6182.
* Strategy tester, XAUUSDm M5, 2026.08.01–09.12: 164,716 ticks / 8,250 bars, test
  passed; the daily roll fires correctly on every trading day.
* Restore path tested by seeding a `blocked=true` state file: a fresh process
  refuses to un-block the day and logs *"the daily cap was already reached"*.

Risk-management software. Not investment advice, and it promises no trading
result.
