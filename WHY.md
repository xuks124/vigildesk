# Why we build VigilDesk

*Short version: our own trading automation hurt us three times, in three ways that all looked like "nothing is wrong". We built the tool we wished we had, and we publish the failures because they are the reason the tool exists.*

---

## What problem this solves, in one paragraph

You have a strategy. It might even be decent. But somewhere between your code and your broker, there are a dozen things that can go wrong quietly: a connection drops and your position stays open, a limit you configured gets overwritten by a default, a restart rebuilds your position without the numbers your protection depends on. None of these announce themselves. **VigilDesk is a brake for that gap** — a local program that watches the account and stops trading when something looks wrong, plus a record of what it did that survives restarts. It does not decide what to trade. It decides when to stop.

## Three real incidents

These are ours. Real dates, real numbers, taken from our own account and code. We lose money in public because that is the only kind of proof that means anything.

### 1. The position that outlived the script

The founding one. A strategy script logged an error while holding an open position. The log said something went wrong; the market did not care. **The order was still live and nothing was managing it.**

That incident moved our attention from *"make the strategy smarter"* to *"make failure recoverable."* In trading, the two seconds after something breaks are the only two seconds that matter.

### 2. The loss limit that was never running

We set a hard daily loss limit of **$50**. The code computed its own limit — **1.5% of balance, about $142** — and assigned it over ours, unconditionally, every tick. Our rule file was read and then discarded.

Result: across **42 trading days**, **5 days closed below the limit we believed in** (−$81.45, −$62.92, −$70.25, −$100.26, −$77.68). The cap fired **zero times**, because the worst day was still inside the number we had not chosen. Nothing crashed and nothing alerted us, because a guard with nothing to do and a guard that is switched off look exactly the same from the outside.

The fix: when a rule and a default disagree, take the stricter one — a rule may tighten the cap, never loosen it.

**In plain numbers:** this account is **down −5.07% overall** (−$506.65 on a $10,000 deposit, MT5 server records, 2026-10-08). Finding that bug did not make it profitable, and we are not claiming otherwise. The account was losing while the guard was off — which is exactly why the guard being off mattered.

### 3. The restart that silently killed the trailing stop

When the bot restarts, it adopts positions that are already open. To do that it rebuilds its own picture of each position — and it did not carry over the stop-loss distance, so that field fell back to `0.0`. Every later calculation divides by it, and a guard written earlier ("if the distance is zero, skip the trailing stop") turned the answer into a permanent, silent *no*.

So for any position adopted after a restart, **the trailing stop could never arm** — not late, never, for the rest of that position's life. The process was alive, the position was open, and the log was clean.

The worst part is the sequence: on 2026-09-10 that same spot had crashed the bot with a divide-by-zero, and we fixed it the fast way — skip the broken case. The crash disappeared, the protection disappeared with it, and the line that would have reported it became unreachable. **We converted a loud failure into a silent one and called it a fix.**

Measured against how far each trade ran before it turned, trades that reached 2R of unrealised gain gave it back to about **+1.03R**, and **7 trades that touched 2R closed as losers** (our own analysis of 186 trades, single method, not independently audited).

Root cause fixed 2026-10-08: recovery now reads the stop distance back out of the trade ledger by ticket, and keeps the cautious behaviour when the ledger has no record instead of inventing a number.

## What we stand for

- **Honesty is the product.** We publish our own bugs, with dates and numbers, because a risk tool that will not admit its own failures is asking for trust it has not earned. Our position page is a verifiable risk record, not a marketing page: <https://xuks124.github.io/vigildesk/proof/>
- **We do not sell signals, advice, or managed accounts.** VigilDesk does not tell you what to trade and never places an order on its own initiative. It is read-only by default.
- **No performance claims, ever.** Any tool that promises you returns is lying to you, and we would rather have no customers than be that tool. A brake is not a profit feature; its job is to bound the damage on the day it is needed.
- **A limit you have not seen fire is a hypothesis, not a protection.** This is the single lesson all three incidents teach. Config is not behaviour. Zero triggers is a suspicious number. "The logs look fine" is not evidence of health — it is also the default state of a dead guard.
- **Local-first, and quiet about your data.** No accounts, no cloud, no outbound account data. Everything runs on your machine and the audit log is yours.

## What we would tell you to check on your own setup

1. Does your daily loss cap come from you, or from a formula nobody wrote down?
2. How often has each of your guards actually fired? If the answer is "never", find out which of the two reasons it is.
3. When your process restarts, which fields does it rebuild from scratch — and which of your protections depend on them?
4. If a guard breaks tomorrow, what exactly tells you? If the answer is the log, remember that silence is also what a working guard looks like.

## The writing

Longer notes on the same theme, including the two incidents above in full:

- [Our code silently replaced our own $50 daily loss limit with $142](https://dev.to/xuks124/our-code-silently-replaced-our-own-50-daily-loss-limit-with-142-226k) — the cap that never armed, and how we found it by comparing config against outcomes.
- [Your daily loss limit resets when MetaTrader restarts. Here is the fix.](https://xuks124.github.io/vigildesk/blog/restart-proof-daily-loss-guard.html)
- [Silent failures in trading automation: the three that cost the most](https://xuks124.github.io/vigildesk/blog/silent-failures-in-trading-automation.html)

---

## 中文（给中文读者）

**为什么做 VigilDesk：** 我们自己的交易自动化在三个地方伤过我们，而三次的共同点是——**表面上一切正常**：①脚本报错但订单还活着、没人管；②我们自己设的 $50 日亏损上限被代码无条件覆盖成约 $142（余额×1.5%），42 个交易日里有 5 天跌破我们以为在生效的那条线，最差一天 −$100.26，而这个上限**一次都没触发过**；③重启接管持仓时漏传了一个字段，导致追踪止损对恢复后的持仓**永久失效**——进程活着、仓位在、日志干净。

这个账户本身是亏的：**入金 10,000 美元，现余额 9,493.35，累计 −5.07%**（MT5 服务端记录，2026-10-08）。找到这个 bug 并没有让它变成盈利，我们也不这么宣称——正因为账户在亏，那个失效的风控才格外要命。

我们主张：诚实就是产品本身；不卖信号、不卖建议、不代客操作；不做任何收益承诺；**没见它触发过的风控只是假设，不是保护**。数据不出本机。

可核查的风控记录页（英文）：<https://xuks124.github.io/vigildesk/proof/>

---

## Risk disclosure

Algorithmic trading carries both technical and market risk. No tool eliminates the possibility of loss. VigilDesk is a safety layer, not a source of returns. Nothing in this repository or on the linked pages is investment advice. The numbers quoted above come from our own account and our own records and describe failures, not a track record.
