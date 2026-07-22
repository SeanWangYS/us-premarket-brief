# 長期投資型讀者的每日盤前 brief 最佳呈現格式：研究報告

> 建立日期：2026-07-22。作者：Sean（＋AI 協作，deep-research harness）。
> 本文件是一次以「對抗式多來源查證」方法完成的設計研究，目的在回答：**對長期投資型讀者而言，每日盤前 brief 的最佳呈現格式是什麼？** 最後收斂為三個具體格式提案與落地建議。
> 語氣力求中性、客觀、可查證。每個關鍵主張都對到來源連結，並標明信心度與驗證票數；被推翻與未驗證的部分誠實標示。
> 相關工程升級規劃見 `docs/agentic-rag-eval-upgrade.md`（本研究的「storyline 追蹤」結論與該計畫的檢索/記憶機制直接呼應）。

---

## 1. 研究緣起與問題定義

### 1.1 背景

這個 repo 每晚（MTWRF 20:30 Asia/Taipei）以 headless `claude -p` 自動產出一份美股盤前情報 brief，發佈到 GitHub Pages。現行格式是 **per-ticker 逐條**：每檔 watchlist 標的一行「頭條一句 | 方向（利多/利空/中性）| 信心（高/中/低）| 來源連結」，另有情緒指標（AAII/VIX）、AI 產業新聞、宏觀、地緣各節，每節 3–5 條 bullet。

使用者明確回饋：此格式「**不具備實用性**」——每天讀完像流水帳，**無法累積觀點**。

### 1.2 讀者輪廓（研究錨點）

- 散戶投資人，投資期間 **3–5 年**，每月僅交易 **1–2 次**，**不做當沖**。
- 每天讀 brief 的目的**不是取得交易訊號**，而是：
  1. 持續追蹤固定 watchlist（8 檔美股：NVDA / TSM / MU / TSLA / PLTR / QQQ / VOO / BTC-USD ＋ 台股 0050）的新聞；
  2. 追蹤 AI／半導體產業主題趨勢；
  3. **日積月累建立自己對持股與產業的觀點**，作為未來加碼/減碼判斷的基礎。
- 有基礎財經知識但不熟進階術語；要求來源連結**可查證、可回溯引用**。

### 1.3 「實用性」的操作型定義

對這位讀者，實用性 ≠ 行動訊號密度，而是三個屬性：

- **可累積**：今天讀到的東西能疊加到昨天、上週建立的理解上，而不是每天歸零重讀。
- **可回溯**：任何一句判斷都能追回到當初的來源與脈絡。
- **來源可靠**：連結指向真實存在、可查證的素材，而非看似合理但實際不存在的引用。

### 1.4 約束條件（工程現實）

- 報告由 headless LLM **每晚一次性生成**，無人工編輯。
- Markdown 輸出，目標長度 **1 頁 A4 可讀完**。
- 每條資訊**必須附來源連結**。
- 可利用的既有素材：當日 moomoo 新聞、WebSearch 結果、repo 內歷史 briefs（`data/*.md` 可回讀，這使「接續昨日脈絡」在技術上可行）。

---

## 2. 研究方法

本研究不是單次搜尋，而是一套 **deep-research harness** 的多階段流程（Scope → Search → Fetch → Verify → Synthesize），核心特徵是**對抗式查證**：每條核心主張交由三個獨立 verifier 投票，只有通過的才進入結論。

| 階段 | 做法 | 產出 |
|---|---|---|
| Scope | 把研究問題拆成 6 個互補搜尋角度 | 6 angles |
| Search | 每個角度各跑一輪 web search，去重後保留 novel 結果 | 候選來源清單 |
| Fetch | 抓取來源全文，由 extractor 逐一抽出可查證主張並附逐字引用 | 25 sources → 110 claims |
| Verify | 對重要度最高的 25 條 claim 做三票對抗式查證 | 24 confirmed / 1 refuted / 0 unverified |
| Synthesize | 合併同源主張，收斂成核心發現與格式提案 | 6 findings + 3 提案 |

**6 個搜尋角度**：
1. practitioner/newsletter design（成功財經電子報的結構與敘事手法）
2. institutional morning note（sell-side 晨報、機構晨會紀要實務）
3. cognitive science/learning（每日閱讀情境下的記憶與心智模型建立）
4. long-term investor noise filtering（低頻決策者的雜訊過濾與過度交易防範）
5. continuity/thread-based information design（storyline/thread 追蹤、delta 呈現）
6. LLM-generated brief implementation（headless 一次性生成的長度控制與引用可靠性）

**統計（`result.stats`）**：6 angles、25 sources fetched、110 claims extracted、25 verified、**24 confirmed / 1 killed / 0 unverified**、synthesis 後收斂為 6 findings；共 108 次 agent calls。

**投票記法**：`3-0 ✓` 表三名 verifier 一致確認；`2-1 ✓` 表多數確認但有一票異議；`0-3 ✗` 表一致否決。下文每條發現均附其票數。

> 方法的邊界：這是**格式設計的支持性證據匯聚**，不是一項針對「這位特定讀者」的對照實驗。沒有任何研究直接證明下述格式會改善他的長期投資結果（見 §6）。

---

## 3. 核心發現

研究總結論（`result.summary`）：**最佳格式不是 per-ticker 逐條羅列（現行痛點根源），而是「少量主題 ＋ 敘事延續 ＋ 掛回既有脈絡」的結構。** 三條獨立證據鏈（機構實務、認知科學、優秀財經寫作）匯聚到同一結論，行為金融再從反面約束格式，最後一條硬約束來自 LLM 引用可靠性。以下逐條展開。

### 3.1 機構級研究以「關鍵因子監控 ＋ delta」為骨架，而非每日羅列新聞

**結論（信心：高，票數 3-0）**：機構級股票研究的基礎不是每日羅列所有新聞，而是為每檔標的預先定義一組「關鍵因子（critical factors）」並**持續監控其變化**。「辨識並監控關鍵因子」被列為分析師五大核心工作**之首**，且以專章教導。這使「把今天的新聞對照既有因子框架、呈現 delta」成為機構標準做法，直接支持以 **watchlist 因子看板取代 per-ticker 流水帳**。

**逐字證據**：Valentine（ex-Morgan Stanley，McGraw-Hill《Best Practices for Equity Research Analysts》）明列五大工作「identifying and monitoring critical factors; ...; communicating stock ideas」，並設專章「Identify and Monitor a Stock's Critical Factors」；其 EPIC 框架教分析師把 inbound 資訊快速分離為 critical factor 或 noise。CFI 等獨立來源逐字複述同一清單。

**佐證（來自 institutional morning note 角度）**：機構晨報模板（Top Call、Overnight/Pre-Market Developments、market context）要求每則更新都必答「Does it change our thesis? Maintain/Upgrade/Downgrade? Adjust price target?」——正是「相對既有 thesis 什麼變了」的 delta 慣例，且限定 2 分鐘讀完。

**來源**：
- [Valentine, *Best Practices for Equity Research Analysts* (McGraw-Hill)](https://www.amazon.com/Best-Practices-Equity-Research-Analysts/dp/0071736387)（primary）

### 3.2 優秀財經寫作與結構化新聞的共通設計＝少量主題 ＋ 跨期敘事延續 ＋ 掛回脈絡

**結論（信心：高，票數 3-0）**：優秀財經寫作與結構化新聞的共通有效設計是「少量主題 ＋ 跨期敘事延續 ＋ 把今天的事件掛回既有脈絡」，而非 per-item 羅列。**Money Stuff** 每期只深挖約五則、跨多期回訪同一主題以逐日累積讀者知識「像學一門新語言」；其價值主張是「重新框架（reframe）」而非資訊密度。**Circa / structured journalism** 把每則事件當成一條持續 storyline 的節點，systematically 追蹤並隨時間累積成單一可累積的知識物件——正對應讀者「觀點累積、可回溯」的目標。

**逐字證據**：
- *Harvard Magazine*：Money Stuff 每期「five-ish financial news headlines」以假想對話／註腳／評論展開，跨期回訪 crypto(2020)／Musk-Twitter(2022)／SVB(2023)／private credit，「building on readers knowledge, as though learning a new language」；Levine 自述價值在「reframes and conceptualizes」。
- *Nieman Lab*：Circa「each news event was not a story in itself, but only a part of a broader ongoing story」，以 branch system 追蹤 storylines。
- *CJR/Caswell*：「the journalism accumulates...a single artifact could accumulate over months or years, in an organized way」。

**來源**：
- [Harvard Magazine — Matt Levine / Money Stuff](https://www.harvardmagazine.com/2025/07/harvard-bloomberg-column-matt-levine)（secondary）
- [Nieman Lab — What we can learn from Circa](https://www.niemanlab.org/2015/06/one-thing-we-can-learn-from-circa-a-broader-way-to-think-about-structured-news/)（secondary）
- [CJR — Structured journalism](https://www.cjr.org/innovations/structured_journalism.php)（secondary）

### 3.3 認知科學支持敘事與「掛回既有脈絡」優於孤立條列

**結論（信心：高，票數 3-0；其中敘事 vs 條列一票 2-1）**：一項整合 75+ 樣本、33,000+ 受試的 meta-analysis 顯示故事比說明文更易理解且記得更牢（Hedge g=.55；memory g=.72）；記憶表現取決於新資訊**能多好地整合進既有知識**，且有先備知識時新資訊同化被促進、**加速固化（consolidation）**；精緻化編碼（提供額外脈絡句）能顯著提升目標資訊回憶率（Bradshaw & Anderson 1982，建立多條檢索路徑）。這為「接續昨日脈絡、把當日事件掛回讀者持股／產業心智模型」提供學習科學依據。

**逐字證據**：
- Mar/Li 2021 (*Psychonomic Bulletin & Review*)：「Stories were more easily understood and better recalled than essays」，結果 robust。
- Brod 2013 (*Frontiers*)：記憶取決於「how well they can be integrated into pre-existing knowledge」，先備知識使「assimilation...facilitated, which would lead to speeded consolidation」。
- Bradshaw & Anderson 1982：獲得額外脈絡事實者「had a far easier time recalling the target sentence」。

**重要限定**：唯一異議票（2-1）指出 meta-analysis 的比較對象是**連續散文（essay）而非 bullet 清單**，故「敘事直接優於條列」略有 overreach，屬**方向性推論**而非直接證明（見 §6.1）。

**來源**：
- [Mar et al. 2021 — Narrative vs expository meta-analysis](https://link.springer.com/article/10.3758/s13423-020-01853-1)（primary）
- [Brod et al. 2013 — Prior knowledge & consolidation](https://www.frontiersin.org/journals/behavioral-neuroscience/articles/10.3389/fnbeh.2013.00139/full)（primary）
- [Elaborative encoding (Wikipedia，含 Bradshaw & Anderson 1982)](https://en.wikipedia.org/wiki/Elaborative_encoding)（secondary）

### 3.4 對低頻長期投資人，格式必須刻意「去訊號化、去躁動化」

**結論（信心：高，票數 3-0）**：以每日新聞熱度／異常成交量／極端漲跌呈現會**系統性誘導散戶追買**（Barber & Odean 2008：buy-sell imbalance 9.35% in-news vs 2.70% out-of-news，散戶對高異常量或極差前日報酬股的買進近乎賣出兩倍）；而高頻交易者年化淨報酬僅 **11.4% vs 低頻 18.5%**（約 7pp 懲罰，主因是**交易成本與交易頻率而非選股能力**，毛報酬幾乎無差異）。加上 **myopic loss aversion**（愈頻繁檢視組合、波動愈痛、股票愈不吸引人；投資人實際以約一年評估期行事）。因此對這位低頻讀者，格式應強調**脈絡／趨勢累積**，避免製造當日行動誘因。

**逐字證據**：
- Barber & Odean 2008 (*RFS*)：散戶是 attention-grabbing 股票的淨買方，因買進需在數千檔中搜尋、賣出僅限已持有；buy-sell imbalance 9.35% vs 2.70%。
- Barber & Odean 2000 (*J. Finance*，66,465 戶)：頻繁交易者淨報酬 11.4% vs 低頻 18.5% vs 市場 17.9%，「the cost of trading and the frequency of trading, not portfolio selections」。
- Benartzi & Thaler 1995 (*QJE*/NBER w4369)：myopic loss aversion；投資人「as if operating with a time horizon of about one year」。

**來源**：
- [Barber & Odean 2008 — All that Glitters](https://faculty.haas.berkeley.edu/odean/papers/Attention/All%20that%20Glitters.pdf)（primary）
- [Barber & Odean 2000 — Trading is Hazardous (SSRN)](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=219228)（primary）
- [Benartzi & Thaler 1995 — Myopic Loss Aversion (NBER w4369)](https://www.nber.org/papers/w4369)（primary）

### 3.5 Smart Brevity 的 signpost 骨架可用，但過度壓縮傷害脈絡

**結論（信心：高，票數 3-0）**：Smart Brevity 的固定粗體「訊號路標（signposts）」——Why it matters／Go deeper／The bottom line——搭配帶超連結的 bullet，用可預期版位引導讀者快速抓重點；「why it matters / so what」是 Axios 官方定義的核心組件。**但**此格式被批評會犧牲脈絡與 nuance，讓讀者「聽起來聰明」而非真正理解（如談千禧世代財務只講消費模式、略去低薪／高負債／醫療成本）。對「觀點累積」導向的 brief，這是明確警訊：過度壓縮會阻礙心智模型建立，故 **signpost 可用作骨架，但每則仍需保留 why-it-matters 的實質脈絡**。

**逐字證據**：Axios 官方與 CJR 皆確認 signposts「Why it matters / Go deeper / The bottom line」＋ bulleted list ＋ embedded hyperlinks 為結構骨架；Axios 官方將「why it matters」列為四大核心組件之一。CJR/Lenz：該格式造成「a steamrolling of nuance in favor of sounding smart at a cocktail party」。

**重要限定**：CJR 批評為單一評論者意見，非「壓縮有害理解」的實證。且與此相關的一條主張已被**否決**（見 §4）。

**來源**：
- [Axios — Smart Brevity](https://www.axios.com/smart-brevity)（primary）
- [CJR — Axios Smart Brevity 批評](https://www.cjr.org/criticism/axios-smart-brevity-longform.php)（secondary）

### 3.6 硬約束：headless LLM 生成的來源連結不可信任為既成事實

**結論（信心：高，票數 3-0）**：實驗顯示模型能產出**格式完全正確**的參考書目（作者／期刊／DOI 看似無誤），實際存在率卻崩潰（GPT-4o 0.235→0.019，open-weight 近乎零），**格式合規會遮蔽「可查證性的近乎完全喪失」**；建議把任何 LLM 生成的引用清單當作**未驗證草稿**，須對外部資料庫做 post-hoc 驗證後才可用。對本 brief，這代表格式設計必須以「**真實抓取到的素材**」（moomoo 當日新聞回傳的原始 URL、WebSearch 實際結果、repo 歷史 brief）為連結來源錨點，**禁止讓 LLM 自由生成連結**。

**逐字證據**：arXiv:2603.07287：「under the Temporal condition every model produces well-formed bibliographic entries...yet existence rates fall sharply—GPT-4o drops from 0.235 to 0.019...Format compliance therefore masks a near-complete loss of verifiability」；「any LLM-generated reference list should be treated as a draft requiring independent verification against scholarly databases」。

**重要限定**：此為**未經同儕審查之 preprint**，樣本小（144 claims/4 模型），絕對數字未必普適，但方向性結論由 GhostCite 等 2025-26 研究獨立佐證。

**來源**：
- [arXiv:2603.07287 — LLM 引用可靠性](https://arxiv.org/pdf/2603.07287)（primary）

---

## 4. 被推翻的主張（誠實記錄）

研究中有一條與「1 頁 A4 可行性」直接相關的主張被**一致否決（0-3 ✗）**：

> **被否決主張**：「Smart Brevity 格式宣稱可以將溝通內容縮短 40–50%，同時保留全部核心資訊——這直接支持研究約束中『1 頁 A4 讀完』的可行性：正確的格式設計可大幅壓縮長度而不犧牲實質內容。」
> 來源：[Axios — Smart Brevity](https://www.axios.com/smart-brevity)　票數：**0-3**

**否決理由與意涵**：三名 verifier 一致認為「縮短 40–50% 仍保留**全部**核心資訊」是行銷宣稱、非可驗證事實，且與 §3.5 的 CJR 批評（壓縮會犧牲 nuance）直接矛盾。**壓縮與脈絡保留之間存在真實張力。** 因此：

- **不可**用這條宣稱去背書「1 頁 A4 一定塞得下所有必要脈絡」。
- 「1 頁 A4」應被視為**待實測的目標**，而非已被證實可達成的保證（見 §6.4 開放問題）。

---

## 5. 三個格式提案

由 §3 findings 收斂，附章節結構、單一標的呈現範例與取捨。

### 提案 A — 主題敘事流 ＋ watchlist 因子看板（**推薦**）

**章節結構（markdown，目標 1 頁 A4）**：
1. **今日一句話**：1 sentence 大局判斷。
2. **主題敘事 2–3 段**：以 AI／半導體趨勢為主軸，每段一個 storyline，接續昨日脈絡（「相較昨日/上週，X 變了」）。
3. **Watchlist 因子看板**（表格：每檔一列，欄位＝關鍵因子現況 | 本週 delta | 掛回哪條主題 | 來源連結），**只在有實質變化時才展開敘述**。
4. **對長期持有人的「so what」收束**（明確**不含**行動訊號）。

**單一標的範例（NVDA）**：
> NVDA — 關鍵因子[資料中心需求/供給]：本週 Blackwell 出貨時程與昨日一致，但 [新增] 某 hyperscaler capex 上修 → 接續本週「AI capex 續強」主線；對 3–5 年持有人：趨勢未變，無需動作。來源：\<moomoo 原始連結\>

**取捨**：最貼合機構因子監控（§3.1）＋ 敘事記憶科學（§3.3）＋ 觀點累積（§3.2）。但對 headless 一次性生成的**敘事連貫性要求最高**（需回讀 `data/*.md`），生成失敗風險與長度控制是主要挑戰。

### 提案 B — storyline 追蹤線程 ＋ 每日 delta

仿 Circa / structured journalism（§3.2）：維護 3–5 條長期 storyline（如「AI capex 週期」「記憶體漲價循環」「地緣/出口管制」），每條線每天只 **append 一個「今日節點 + 與前次的 delta」**，watchlist 個股掛到所屬 storyline 之下。

**取捨**：可累積性、可回溯性**最強**，最能建立心智模型。但需要**跨日狀態（storyline 清單）的穩定維護機制**，若無結構化存檔易漂移。

### 提案 C — Smart Brevity 訊號路標式精簡

沿用現行分節，但每則從「頭條一句 | 方向 | 信心」改為「頭條 → Why it matters（1–2 句脈絡）→ 來源」，保留粗體 signpost 骨架（§3.5）。

**取捨**：離現況最近、最易 headless 穩定生成、長度最好控制。但敘事連貫與觀點累積**最弱**，且 CJR 警示過度壓縮傷害 nuance——**最保守、最不推薦作為終局**。

### 提案對照表

| 維度 | A 主題敘事＋因子看板 | B storyline 線程 | C Smart Brevity 精簡 |
|---|---|---|---|
| 觀點累積力 | 高 | **最高** | 低 |
| 可回溯性 | 高 | **最高** | 中 |
| 敘事記憶效果 | **高** | 高 | 低 |
| headless 一次生成穩定度 | 低（需回讀歷史） | 低（需跨日狀態） | **高** |
| 長度控制難度 | 中 | 中 | **低** |
| 離現況距離 | 中 | 遠 | **近** |
| 綜合推薦 | **目標終局** | 骨幹機制 | 過渡/保底 |

---

## 6. 不確定性與限制

彙整自 `result.caveats`（6 條）與 `result.openQuestions`（4 條）。

### 6.1 證據層面的不確定性

1. **認知科學的比較對象是散文，非 bullet**：meta-analysis 測的是「敘事 vs 連續散文」，並未直接測「敘事 vs bullet 清單」；chunking 研究有時反而支持清單利於回憶。故「敘事優於條列」是**方向性推論**。該 meta-analysis 本身有 publication bias 與高異質性（I²=98%）。
2. **「壓縮 40–50% 保留全部資訊」已被否決**（§4），勿用來背書 1 頁 A4 可行性。
3. **myopic loss aversion** 對權益溢價的解釋力有複現爭議，但「評估頻率而非持有期驅動避險」的描述性核心未被推翻。
4. **財經寫作案例（Levine/Circa）是 secondary source 且為人工編輯產物**；本 brief 是 headless 一次性生成，其敘事連貫與 storyline 追蹤能否**無人工維持**是**最大工程未知數**。
5. **LLM 引用可靠性論文為未審查 preprint**，絕對數字未必普適，但方向性結論穩固。
6. 所有結論皆為格式設計的**支持性推論**，**無任何研究直接證明**這些格式會改善「這位特定讀者」的長期投資結果。

### 6.2 開放問題（待落地時解決）

1. **跨日 storyline 如何在 headless 一次性生成下可靠維持連貫與 delta？** 需在 `routine-prompt.md` 設計「回讀 `data/*.md` 前 N 日 ＋ 抽取既有 storyline 狀態」的機制，才能技術上實現 A/B 的敘事延續而不漂移。
2. **「少量主題深挖」vs「8 檔固定 watchlist 每檔都要交代」如何取捨？** 某檔當日無實質新聞時，是完全略過（利於去躁動化與長度）還是仍列一行「無變化」（利於追蹤完整性與讀者安心感）？
3. **關鍵因子（critical factors）清單由誰、如何為這 8 檔預先定義並維護？** 寫死在 prompt，還是讓 LLM 每季重評？此清單品質**直接決定提案 A 的成敗**，但本研究未涵蓋因子選取方法。
4. **1 頁 A4 的長度上限與脈絡深度的實際可容納量是多少字？** 在無 40–50% 壓縮保證的前提下，需實測不同提案在真實 moomoo+WebSearch 素材量下能否穩定收斂到目標長度。

---

## 7. 總結與建議

### 7.1 總結

三條獨立證據鏈（機構因子監控、認知科學敘事整合、優秀財經寫作的 storyline 累積）匯聚到同一設計方向：**少量主題 ＋ 敘事延續 ＋ 掛回既有脈絡**，並由行為金融（去躁動化）與 LLM 引用可靠性（連結必須錨定真實素材）從兩側加上硬約束。per-ticker 流水帳之所以「無法累積觀點」，正是因為它同時違反了這幾條原則。

### 7.2 建議：以提案 A 為目標、用提案 B 的 storyline 機制當骨幹，分兩階段落地

- **推薦終局＝提案 A**（主題敘事流 ＋ watchlist 因子看板），因為它同時滿足機構因子監控、敘事記憶科學與觀點累積三者。
- **骨幹機制＝提案 B 的 storyline 追蹤**：把 A 的「主題敘事段」實作成 3–5 條可跨日 append 的 storyline，個股掛到所屬線程之下。

**第一階段（純 prompt，低風險，可立即做）**：
- 在 `routine-prompt.md` 導入**靜態 signpost 骨架**（提案 A/C 的章節結構＋每則保留 why-it-matters 實質脈絡）。
- 加**輕量回讀歷史**：讀 `data/` 前 N 日 brief，讓當日敘事以「相較昨日/上週 X 變了」的 delta 語氣書寫。
- 強制每條連結錨定真實抓取到的素材（moomoo 原始 URL／WebSearch 結果），**禁止 LLM 自由生成連結**（§3.6）。
- 明確去除「方向/信心」標籤式的行動誘因，改以脈絡與趨勢陳述（§3.4）。

**第二階段（等 agentic RAG 落地後）**：
- 做 **storyline 狀態管理與 delta 計算**：把 storyline 清單存成結構化物件（而非每天重新推斷），每日只 append 節點與變化。
- 這本質上是一個**檢索問題**——「今天的事件屬於哪條既有 storyline、相對上次變了什麼」需要對歷史語料做可靠檢索與比對。

### 7.3 與既有計畫的呼應

storyline 追蹤的「跨日狀態穩定維護」正是 `docs/agentic-rag-eval-upgrade.md` 規劃中的 **agentic RAG + 記憶/檢索** 要解決的能力落差（歷史簡報進向量庫、做 grounding 與延續性檢索、citation 對齊驗證）。因此本研究的第二階段建議**不需另起爐灶**，而是作為該升級計畫的一個具體應用場景落地。第一階段則可在現行 CLI headless 架構下先行，不必等 RAG 完成。

---

## 8. 參考文獻

25 個來源，依研究角度分組；品質分級為 extractor 標註（primary＝一手/原始文獻，secondary＝二手可靠報導/百科，blog／forum＝部落格或論壇，須較保守看待）。`claims` 為該來源被抽出的主張數。

### practitioner/newsletter design
| # | 來源 | 品質 | claims |
|---|---|---|---|
| 1 | [Axios — Smart Brevity](https://www.axios.com/smart-brevity) | primary | 5 |
| 2 | [AxiosHQ — Smart Brevity communication checklist](https://www.axioshq.com/research/smart-brevity-communication-checklist) | blog | 4 |
| 3 | [Daniel Stone — Money Stuff is linear-ish](https://danielstone.substack.com/p/money-stuff-is-linear-ish) | blog | 3 |
| 4 | [Harvard Magazine — Matt Levine / Money Stuff](https://www.harvardmagazine.com/2025/07/harvard-bloomberg-column-matt-levine) | secondary | 5 |
| 5 | [CJR — Axios Smart Brevity 批評](https://www.cjr.org/criticism/axios-smart-brevity-longform.php) | secondary | 5 |
| 6 | [News Machines — How Morning Brew uses data to grow](https://newsmachines.substack.com/p/how-morning-brew-uses-data-to-grow) | blog | 3 |

### institutional morning note
| # | 來源 | 品質 | claims |
|---|---|---|---|
| 7 | [Claude Code Playbooks — Equity Research Morning Note](https://www.claudecodehq.com/playbooks/er-morning-note) | blog | 5 |
| 8 | [Richard Toad — How sell-side equity research works](https://richardtoad.substack.com/p/how-sell-side-equity-research-works) | blog | 5 |
| 9 | [Wall Street Prep — Sample equity research report](https://www.wallstreetprep.com/knowledge/sample-equity-research-report/) | secondary | 4 |
| 10 | [Wall Street Oasis — Buy-side research note](https://www.wallstreetoasis.com/forum/equity-research/buy-side-research-note) | forum | 4 |
| 11 | [Valentine — Best Practices for Equity Research Analysts (McGraw-Hill)](https://www.amazon.com/Best-Practices-Equity-Research-Analysts/dp/0071736387) | primary | 5 |
| 12 | [Mergers & Inquisitions — Equity research report](https://mergersandinquisitions.com/equity-research-report/) | blog | 5 |

### cognitive science/learning
| # | 來源 | 品質 | claims |
|---|---|---|---|
| 13 | [Mar et al. 2021 — Narrative vs expository meta-analysis (Psychonomic Bulletin & Review)](https://link.springer.com/article/10.3758/s13423-020-01853-1) | primary | 4 |
| 14 | [Brod et al. 2013 — Prior knowledge & consolidation (Frontiers)](https://www.frontiersin.org/journals/behavioral-neuroscience/articles/10.3389/fnbeh.2013.00139/full) | primary | 5 |
| 15 | [Elaborative encoding (Wikipedia)](https://en.wikipedia.org/wiki/Elaborative_encoding) | secondary | 4 |

### long-term investor noise filtering
| # | 來源 | 品質 | claims |
|---|---|---|---|
| 16 | [Barber & Odean 2008 — All that Glitters](https://faculty.haas.berkeley.edu/odean/papers/Attention/All%20that%20Glitters.pdf) | primary | 5 |
| 17 | [Benartzi & Thaler 1995 — Myopic Loss Aversion (NBER w4369)](https://www.nber.org/papers/w4369) | primary | 4 |
| 18 | [Barber & Odean 2000 — Trading is Hazardous (SSRN)](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=219228) | primary | 5 |

### continuity/thread-based information design
| # | 來源 | 品質 | claims |
|---|---|---|---|
| 19 | [Nieman Lab — What we can learn from Circa](https://www.niemanlab.org/2015/06/one-thing-we-can-learn-from-circa-a-broader-way-to-think-about-structured-news/) | secondary | 4 |
| 20 | [CJR — Structured journalism](https://www.cjr.org/innovations/structured_journalism.php) | secondary | 4 |
| 21 | [Living Stories (Wikipedia)](https://en.wikipedia.org/wiki/Living_Stories) | secondary | 4 |
| 22 | [Formats Unpacked — Axios](https://formatsunpacked.storythings.com/p/formats-unpacked-axios) | blog | 5 |

### LLM-generated brief implementation
| # | 來源 | 品質 | claims |
|---|---|---|---|
| 23 | [arXiv:2508.13805 — Prompt-based one-shot exact length-controlled generation](https://arxiv.org/pdf/2508.13805) | primary | 3 |
| 24 | [arXiv:2603.07287 — LLM 引用可靠性](https://arxiv.org/pdf/2603.07287) | primary | 5 |
| 25 | [GitHub — hoangsonww/AI-News-Briefing](https://github.com/hoangsonww/AI-News-Briefing) | secondary | 5 |

---

> **研究方法透明度**：本報告由 deep-research harness 產出，6 角度 / 25 來源 / 110 主張 / 25 條經三票對抗式查證（24 confirmed、1 refuted、0 unverified）/ 108 次 agent calls。所有逐字引用取自各來源 extractor 的原文擷取；被否決與有異議的部分已於 §3、§4、§6 明確標示。
