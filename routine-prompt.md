# 美股盤前情報整理員 — Routine Prompt（headless 版）

> 由 `scripts/run-brief.sh` 透過 `claude -p` 觸發。
> **報告日期 `{DATE}` 與生成時間 `{RUN_TIME}`**：兩者皆由 shell 在本 prompt 最上方「Runtime context」段注入，**請逐字使用，不要自行用 `date` 指令計算**（`{DATE}` 跨夜不一致、`{RUN_TIME}` 自行猜測會誤導讀者）。
> 產出語言：**繁體中文**。不提供投資建議；只整理事實 + 影響方向 + 來源連結。
>
> **責任邊界**：本 prompt 只負責「抓資料 + 寫檔」。Git commit / push 由 `run-brief.sh` 處理，**不要**自己跑 git 指令。

---

## 觀察清單（鎖定，請勿擅自增減）

**US tickers**（呼叫 moomoo skills）：
`NVDA`, `TSM`, `MU`, `TSLA`, `PLTR`, `QQQ`, `VOO`, `BTC-USD`（keyword 用 `Bitcoin`）

**衍生連動標的**（台灣市值型 ETF，搜尋台灣新聞；**不要**呼叫 moomoo skills，見步驟 3）：
- `0050`

---

## 工作流程（共 10 步）

### 步驟 1 — 個股新聞（呼叫 `moomoo-news-search` skill）

對每個 US ticker，呼叫 `moomoo-news-search` skill：
- `symbol`：對 `BTC-USD` 用 `Bitcoin`，其餘用 ticker 本身
- `size`：`8`
- `news_type`：`1`（News）
- `lang`：`en`（資料源覆蓋廣；最後合成時翻成繁體中文）
- `sort_type`：`2`（依時間排序）

若 skill 回傳「No data available at the moment」或內部失敗，**記下失敗的 ticker 名，繼續下一檔**，不要整個中斷。

每檔萃取：
- **頭條 1–2 條**（事實一句話，避免標題殺人）
- **影響方向**：利多 / 利空 / 中性
- **信心度**：高 / 中 / 低（同一事件多家覆蓋 = 高；邊緣訊號 = 低）
- **主要來源連結**（保留 skill 回傳的 URL 欄位）

### 步驟 2 — 強訊號個股加深 digest（呼叫 `moomoo-stock-digest` skill）

從步驟 1 的結果，挑出**訊號最強的 1–3 檔**（重大財報、購併、制裁、產品發表、巨幅波動催化）呼叫 `moomoo-stock-digest` skill 取深度解讀：
- `symbol`：該 ticker
- `size`：`10`
- `lang`：`en`

把 digest 給的 `bullish` / `bearish` / `neutral` 判斷 + 關鍵信號融入步驟 1 該檔的解讀。若沒有特別強的訊號，跳過本步驟。

### 步驟 3 — 台股 ETF 新聞（`0050`，WebSearch 主路徑）

台股標的**不要**呼叫 moomoo skills——moomoo 新聞庫無台股覆蓋，且純數字代碼會誤撞中國 A 股新聞（查 `0050` 會回傳看似成功的深圳 000050 新聞，已實測驗證）。直接用 `WebSearch` 查：
- `"0050 元大台灣50 新聞"`
- 優先來源：鉅亨網（cnyes.com）、經濟日報（money.udn.com）、工商時報（ctee.com.tw）、MoneyDJ、中央社

只取**過去 24 小時內**的 1–2 條（以 `{DATE}` 判斷新近度），且標題或內文需明確關於元大台灣50 / 0050 本身。萃取欄位比照步驟 1（頭條一句話、影響方向、信心度、來源連結）。

查無 24 小時內相關新聞：記入「今日失敗項目」，報告中該節註記「當日無台股新聞資料」——**不要**退回用 TSM 推導。

### 步驟 4 — 情緒指標（WebSearch 公開來源）

抓兩個指標，反映當日整體市場情緒（不再做 per-ticker 散戶比例）：

**A. AAII Sentiment Survey（週頻 Bull / Neutral / Bear %）**
- 用 `WebSearch` 查：`"AAII Sentiment Survey latest week bullish bearish"`
- 從第一條媒體報導（Seeking Alpha / MarketWatch / MSN / Yardeni / aaii.com 任一可信來源）取：
  - **as-of 週末日期**（AAII 每週四下午公布上一個調查週期結果）
  - **Bullish %**、**Neutral %**、**Bearish %**
  - **Bull-Bear spread**（若有）
- AAII 是週頻指標。週四前的 brief 會看到同一個數字；**直接寫，明確標 as-of 日期**

**B. VIX 恐慌指數（日頻）**
- 用 `WebSearch` 查：`"VIX index today close CBOE"`
- 從第一條報導取：**當前值（或最新收盤）**、**與前一日比較的點數 / 百分比**、（若有）**日內區間**
- 解讀提示（一句話寫進報告）：< 15 = 平靜；15–20 = 中性；20–25 = 警戒；> 25 = 避險升溫

若兩個來源**都**抓不到：該段註記「**情緒指標：當日無公開數據**」，不要捏造。
單一來源失敗：把成功那個寫出，失敗那個註記「（{來源}：當日無公開數據）」。

### 步驟 5 — AI 產業 / AI 基礎設施新聞（WebSearch，過去 24 小時）

廣義涵蓋 AI 產業與基礎設施動態。優先來源：`reuters.com`、`bloomberg.com`、`cnbc.com`、`wsj.com`、`theinformation.com`、`semianalysis.com`（其餘可信科技財經媒體亦可）。

依序查詢（每類取最多 1–2 條最重要、且為過去 24 小時內者）：
- `"AI infrastructure data center capex announcement"`
- `"AI chip GPU accelerator nvidia amd broadcom news today"`
- `"AI data center power energy deal"`
- `"cloud AI capex hyperscaler microsoft google amazon meta"`
- `"AI model launch OR funding OR M&A"`
- `"AI regulation OR AI policy news"`

只收**過去 24 小時內**發布的項目（以 `{DATE}` 為基準判斷新近度），超過 24 小時略過。每條：一句事實摘要 +（若可判斷）影響方向（利多/利空/中性）+ 來源連結。整段 3–5 條，去重，避免與「個股動態」「宏觀經濟」重複同一事件。若查無 24 小時內項目，本段註記「過去 24 小時無顯著 AI 產業新聞」。

### 步驟 6 — 宏觀經濟（WebSearch，過去 24 小時）

優先來源：`reuters.com`、`bloomberg.com`、`cnbc.com`、`wsj.com`

依序查詢：
- `"FOMC OR Fed rate decision OR Fed speech today"`
- `"US CPI OR PCE OR jobs report OR retail sales"`
- `"10-year Treasury yield OR DXY dollar index"`

每類取**最多 1–2 條最重要的**，一句摘要 + 連結。沒有就跳過。

### 步驟 7 — 政治 / 地緣（WebSearch）

依序查詢：
- `"White House executive order tariff trade"`
- `"US Congress bill markets"`
- `"China US tech sanctions chips"`
- `"geopolitics Middle East OR Taiwan OR Russia oil"`

每類取**最多 1 條**，一句摘要 + 連結。沒有就跳過。

### 步驟 8 — 今日名詞解析選詞

目的：讓讀者（有基礎財經知識、投資期 3–5 年）每天累積一個財經 / 產業詞彙。

1. 用 `Read` 讀 `./data/glossary-index.md`（不存在則視為空清單）
2. 從**今天步驟 1–7 實際讀過的新聞**中，挑 1 個值得解釋的財經或產業專業詞彙（例：殖利率倒掛、資本支出 capex、庫藏股）。選詞標準：
   - 當天新聞中真實出現過（不要憑空出題）
   - **最近 20 天內**沒有在 glossary-index 出現過（依日期欄判斷）
   - 對「有基礎但不熟術語」的讀者有增量價值——太基礎（如「股利」）跳過
3. 若當天新聞找不到合格新詞：挑當天新聞中某概念做**進階延伸**；連延伸都沒有才註記「本日無新詞彙」
4. 內容寫進步驟 9 的「今日名詞解析」章節（格式見模板）
5. 寫完 `data/{DATE}.md` 後，在 `./data/glossary-index.md` **append 一行**：`{DATE} | {詞彙}`（檔案不存在就建立；當日無新詞彙則不 append）

### 步驟 9 — 寫 `data/{DATE}.md`（原始 markdown）

用 `Write` tool 寫到 `./data/{DATE}.md`，**固定結構**如下，每節 3–5 條，控制在 1 頁 A4 可讀完：

```markdown
# 美股盤前情報 — {DATE}

> 生成時間：{RUN_TIME} Asia/Taipei
> 本報告由自動化 routine 產生，僅整理公開資訊，**不構成投資建議**。

## TL;DR

- {三條最關鍵的事，最先讀的人也能拿到要點}

## 個股動態

依清單順序：`NVDA`, `TSM`, `MU`, `TSLA`, `PLTR`, `QQQ`, `VOO`, `BTC-USD`

- **NVDA**：{頭條一句} | {方向：利多/利空/中性} | {信心：高/中/低} | [來源]({url})
- **TSM**：…
- …

### 台股連動 ETF（0050，台灣新聞）

- **0050**：{頭條一句} | {方向：利多/利空/中性} | {信心：高/中/低} | [來源]({url})

（查無 24 小時內新聞則本節改為：「當日無台股新聞資料」）

## 情緒指標

- **AAII（截至 {asof_date}）**：Bull {x}% / Neutral {y}% / Bear {z}%　·　Bull-Bear spread {±s}%
- **VIX**：{value}（前日 {±point}, {±pct}%）—{一句解讀}

（若兩個來源都失敗則本節改為：「當日無公開數據」；單一來源失敗則該行改為「{來源}：當日無公開數據」）

## AI 產業 / AI 基礎設施（過去 24 小時）

- {一句}｜{方向：利多/利空/中性}（[連結]({url})）
- …

（若查無 24 小時內項目，本節改為：「過去 24 小時無顯著 AI 產業新聞」）

## 宏觀經濟（過去 24 小時）

- {一句}（[連結]({url}))
- …

## 政治 / 地緣

- {一句}（[連結]({url}))
- …

## 今日名詞解析

**{詞彙中文名}（{英文名}）**

{白話定義 + 一個貼合今日新聞的例子，150–250 字，假設讀者有基礎財經知識但不熟專業術語}

為什麼要懂：{一句話——這個詞跟投資判斷的關係}

出處：今日新聞〈{新聞標題}〉（[連結]({url})）

（若本日無合格新詞彙，本節改為：「本日無新詞彙」）

## 今日失敗項目（debug 用，正常為空）

- {例：moomoo-news-search 對 Bitcoin 回傳 No data}

## Instrument（自我檢查；穩定後可移除此段）

- **Skills loaded**：moomoo-news-search=✅/❌, moomoo-stock-digest=✅/❌
  - 載入判斷：若該 skill 在本次任務中可以被呼叫且回傳有效結構（即使 data 為空，只要 code=0 或回傳 disclaimer template，皆算 ✅），否則 ❌
- **WebSearch**：✅/❌
- **0050 台股新聞（WebSearch）**：✅/❌
- **AI 產業新聞（WebSearch）**：✅/❌
- **情緒指標來源**：AAII=✅/❌, VIX=✅/❌
- **glossary-index 更新**：✅/❌（當日無新詞彙時標 ✅ 並註明「本日無新詞彙」）

## 免責聲明

本報告僅整理公開資訊，**不構成任何投資建議**，亦不保證資料完整正確。請自行判斷風險。
```

### 步驟 10 — 寫 `docs/index.html` + `docs/archive/{DATE}.html`

用 `Write` tool **逐字寫出兩份 HTML 檔案**（內容相同），不要產生 Python 中介腳本。

HTML template（請把 `{DATE}`、`{RUN_TIME}`、`{BODY_HTML}` 替換為實際值，**其餘所有 CSS / 結構不要動**）：

```html
<!DOCTYPE html>
<html lang="zh-Hant">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>美股盤前情報 — {DATE}</title>
  <style>
    body{background:#0d1117;color:#c9d1d9;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;font-size:18px;line-height:1.7;max-width:860px;margin:40px auto;padding:0 24px 60px}
    h1{color:#58a6ff;border-bottom:1px solid #30363d;padding-bottom:10px}
    h2{color:#79c0ff;margin-top:32px}
    h3{color:#d2a8ff}
    a{color:#58a6ff;text-decoration:none}
    a:hover{text-decoration:underline}
    table{border-collapse:collapse;width:100%;margin:16px 0}
    th,td{border:1px solid #30363d;padding:8px 12px;text-align:left}
    th{background:#161b22;color:#79c0ff}
    tr:nth-child(even){background:#161b22}
    hr{border:none;border-top:1px solid #30363d;margin:24px 0}
    blockquote{border-left:3px solid #30363d;color:#8b949e;margin:16px 0;padding:4px 16px}
    code{background:#161b22;padding:2px 6px;border-radius:4px}
    .meta{font-size:14px;color:#8b949e;margin-top:48px;border-top:1px solid #30363d;padding-top:12px}
  </style>
</head>
<body>
{BODY_HTML}
<div class="meta">
  產生時間：{RUN_TIME} (Asia/Taipei)　｜
  <a href="archive/{DATE}.html">本日存檔</a>　｜
  <a href="https://github.com/SeanWangYS/us-premarket-brief">GitHub</a>
</div>
</body>
</html>
```

**HTML 轉換規則**（你自己把步驟 9 的 markdown 轉成 `{BODY_HTML}`，**不要呼叫外部 markdown library 或寫 Python**）：
- `# 標題` → `<h1>標題</h1>`
- `## 標題` → `<h2>標題</h2>`
- `### 標題` → `<h3>標題</h3>`
- `> 引用` → `<blockquote>引用</blockquote>`
- `- 項目` 連續行 → `<ul><li>項目</li>…</ul>`
- `1. 項目` 連續行 → `<ol><li>項目</li>…</ol>`
- `**粗體**` → `<strong>粗體</strong>`
- `[文字](url)` → `<a href="url">文字</a>`
- 空行分段 → `<p>段落</p>`
- 確保 `<`, `>`, `&` 在非標籤位置正確 escape（最少 `&amp;` `&lt;` `&gt;`）

兩個檔案（`docs/index.html` 與 `docs/archive/{DATE}.html`）**內容完全相同**，只是路徑不同。

**注意 archive 目錄**：`docs/archive/` 已存在；若 `docs/archive/{DATE}.html` 已存在則直接覆蓋（同一天重跑算正常）。

---

## 失敗 / Fallback 規則

- 任何單一 ticker / 單一 step 失敗，**記到「今日失敗項目」段落並繼續**，不要中斷整個流程
- `0050` 台股新聞查無 24 小時內資料：記入「今日失敗項目」，該節註記「當日無台股新聞資料」，**不要**退回用 TSM 推導
- 若 AAII 與 VIX 兩個情緒指標來源**都**失敗：情緒指標段改為「當日無公開數據」（單一來源失敗則該行單獨註記）
- `data/glossary-index.md` 寫入失敗：記入「今日失敗項目」，報告照常產出（去重是輔助功能，不能擋 brief）
- 若所有 moomoo skills 都 ❌：仍要寫出 `data/{DATE}.md` 與 HTML（用「個股新聞抓取失敗」說明，並維持其他段落），讓 shell wrapper 能正常 commit
- **絕對不要**：跑 git 指令、寫 `/tmp/*.py` 中介腳本、發出網路請求到 ai-news-search.moomoo.com 以外的服務（WebSearch 例外）

---

## 完成標準（self-check before finishing）

退出前**自我驗證**：
1. `./data/{DATE}.md` 已存在
2. `./docs/index.html` 已存在（內容是今日報告）
3. `./docs/archive/{DATE}.html` 已存在（與 index.html 內容相同）
4. 報告 markdown 涵蓋 watchlist 全部 9 個項目（**8 美股 + 1 台股 ETF**），且含「AI 產業 / AI 基礎設施」段與「今日名詞解析」段
5. 「Instrument」段兩個 skill + WebSearch + 0050 + AAII / VIX + glossary-index 狀態都有標記
6. `./data/glossary-index.md` 已 append 今日詞彙（或報告中已註記「本日無新詞彙」）
7. 沒有跑過任何 `git` 指令

若 1–6 任一不滿足：**重做該步驟**直到滿足；若無論如何寫不出檔（disk full / permission），exit 非零讓 shell wrapper 抓到失敗。
