# VigilDesk — Your strategy is the steering wheel. VigilDesk is the brake.

> 你的策略是方向盘，VigilDesk 是刹车。/ Your strategy. Our safety layer. We sell the brake, not the wheel.

## 背景 / Why this exists

和很多朋友一样，我写策略脚本是为了把重复劳动自动化。但真正的教训来自一次断线重连——脚本报了错，仓位却还挂着。从那天起我把精力从"让策略更聪明"转到"让失控更可控"，做成了 VigilDesk 这个工作站。

Sharing a lesson learned the hard way: my strategy script crashed on a reconnect, logged an error — and my order was still live. That incident shifted my focus from "making my strategy smarter" to "making failure recoverable", and eventually into VigilDesk, a local-first safety layer for algo traders.

## 它做什么 / What the brake layer does

- **全局断线/异常监测**：行情断、订单通道断，先停再说 / Kill-switch on connectivity loss & API errors (halt first, diagnose later)
- **仓位与频率硬上限**：策略再疯，也越不过你设定的护栏 / Hard caps on position size and order frequency
- **异常行为熔断**：成交回报异常、滑点突变，自动进入保护状态 / Anomaly circuit breakers (erratic fills, abnormal slippage)
- **全程本地日志**：出了问题有据可查，不用翻交易所后台 / Full local audit log; account data stays on your machine

技术栈：Python 桌面应用，本地运行，持仓与账户数据不经过我们的服务器。Tech stack: Python desktop app, runs locally.

## 它不能做的事 / What it is NOT

不产生信号、不推荐标的、不代客操作、不承诺任何收益——它是给已经想清楚策略的交易者用的安全层。

No signals, no trade recommendations, no managed accounts, and zero performance claims. It is for traders who already have a strategy — this is the safety layer.

## 风险提示 / Risk disclosure

程序化交易存在技术故障与市场双重风险，任何工具都不能消除亏损可能。本页不构成投资建议。

Algorithmic trading carries both technical and market risk; no tool eliminates the possibility of loss. Not financial advice.

## 链接 / Links

- 项目主页 / Project page: <https://xuks124.github.io>
- 在线文档 / Docs: <https://xuks124.github.io/faq.html> · <https://xuks124.github.io/tutorial.html>
- 下载 / Download: <https://xuks124.github.io/free.html>

欢迎拍砖（Discussions），尤其欢迎"你们为什么不做 XX"这类问题。Roast it — especially the parts you'd design differently.
