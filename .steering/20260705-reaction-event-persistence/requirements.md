# 要件定義書 — 生 ReactionEvent / モーションの永続化（moat の燃料）

関連: [issue #112] / `docs/vision.md`（North Star・moat）/ ADR-0003（ルールベース→フライホイール）

## 背景・課題（実コードで裏取り済み）

HowTune の moat は「低レイヤーの反応データ（頭部モーション・生理・エンゲージメント）」の蓄積とフライホイール（`docs/vision.md`）。しかし現状、その**核心データが永続化されていない**。

実装の実態:

- `Features/AirPodsMotion/Models/AirPodsMotionSample.swift`: `userAcceleration` / `rotationRate` / `attitude` / `playbackTime` / 導出 `interactionIntensity` を **on-device で毎サンプル生成**。
- `Features/ReactionDetection/ViewModels/ReactionDetectionViewModel.swift`: そのモーションから反応を検出し `Models/ReactionEvent.swift`（`startTime`/`endTime`/`intensity`/`tags`/`score`/`heartRateTrend`）を組み立てる。
- `ViewModels/ClipCreationViewModel.swift` の `createHowCard` が Firestore へ送るのは **How カード（comment・song_start/end・tags）だけ**。
- ⇒ **生モーション列と ReactionEvent（intensity 時系列・score 内訳）は破棄**され、Firestore の `song_insights` は「How カード区間の重なり」という粗い近似で密度を出しているに過ぎない。

## 目的・ゴール

- 生の反応シグナル（モーション由来の intensity 時系列 / ReactionEvent）を**プライバシーを守りつつ蓄積**し、
  - 「本物の反応密度」（How カード有無に依らない、実際に体が動いた瞬間）で `song_insights` を精緻化、
  - 将来の「雰囲気レコメンド」「ホルモン/低レイヤー分解」（North Star）の学習素材にする。
- **ML で反応を推定できる形で蓄積する**：頭部モーション（＋補助 HR・音響・コメント）と**自己申告タグ（弱教師ラベル）**を対にして貯め、`arousal/valence` 次元回帰＋multi-label タグを学習可能にする（下記「生理学的接地と ML 前提」）。

## 生理学的接地と ML 前提（精査で更新）

How タグ（groove / hype / hit / immersion / chill / afterglow / neutral）を文献に照らして精査した結果（出典は末尾）：

- **7タグは直交していない**：覚醒(hype/hit/chill/neutral)・運動同期(groove)・注意(immersion)・時間フェーズ(afterglow) の**別々の生理系が混在**＝互いに排他でなく、単一クラス分類には不適。
- **実センサーで読める確度に差がある**（頭部モーション＋補助 HR）：
  - **高**：groove（拍同期の頭うなずき＝加速度計で直接）／arousal の量（hype↔chill）／hit（単発スパイク）
  - **低**：valence（快/悲は動きから弱い＝arousal ≫ valence）／immersion（静止＝chill/neutral と縮退）
  - **不可**：frisson（鳥肌・戦慄。金指標は EDA/立毛で AirPods に無い）
- **旗艦反応 frisson が抜けている**：最も測れてドーパミン直結の反応なのにタグに無く、名前は "chill"(低覚醒) に取られて真逆。→ 将来の追加センサー(EDA)候補として明記。
- **ML の原則**：モデルは**信号に入っている情報しか取り出せない**。「魔法で valence を当てる」のではなく、**arousal/groove は高精度・valence/没入は多モーダルで確率的・frisson は要追加センサー**、と**確信度付き**でスコープする。
- **ML の設計前提**：単一クラス → **multi-label ＋ arousal/valence 次元回帰 ＋ 時系列（afterglow 等のフェーズ）＋ 多モーダル融合（motion＋HR＋音響＋コメント）＋ 個人化（frisson/groove 感受性の個人差）**。既存 `OthelloActivityClassifier`（Create ML・3状態）が出発点。
- **帰結（この steering の意義）**：ML で「生理学的に通す」には **motion＋ラベルの蓄積が必要条件**。＝本 steering（reaction_sessions 保存）が ML flywheel の土台。

## スコープ

### In

- `ReactionEvent`（検出済み区間サマリ）の Firestore 永続化スキーマと書き込み経路の設計。
- モーション由来 `interactionIntensity` の**ダウンサンプリング時系列**（生 CMDeviceMotion 全点ではなく、曲時間に沿った軽量サマリ）の保存設計。
- プライバシー（匿名化・同意・データ量・保持期間）の設計。
- 既存 `song_insights` 集計をこの新データに接続する段階案。

### Out（この steering では扱わない）

- 実装そのもの（本 steering は設計まで。実装は別 tasklist で着手）。
- 生 CMDeviceMotion の全点ロー保存（データ量・電池・プライバシーが過大 → 却下方針）。
- 心拍/生理の**新規センサー追加**（本 steering は既存 `heartRateTrend`・頭部モーションの範囲。ただし frisson 用の EDA/立毛は「将来の追加センサー候補」として記録のみ。ADR-0005 参照）。

## 機能要件

- FR-1: 反応記録セッション（1 曲の再生中）ごとに、ReactionEvent 群と intensity ダウンサンプル列を 1 ドキュメントで保存できる。
- FR-2: 保存単位に `song_id` / `user_id` / `playbackTime` 基準の時刻を持ち、`song_insights` 集計が「How カード」ではなく「実反応」を密度に使える。
- FR-3: 既存 How カード作成フローと**疎結合**（How カードを作らなくても反応セッションは保存されうる／その逆も可）。

## 非機能要件（特に重要）

- NFR-Privacy-1: 生データは **本人のみ read**、B2B へは必ず Functions 集計・匿名化（k=5・`user_id` 除去）を経由（ADR-0007 の原則を踏襲）。
- NFR-Privacy-2: **明示同意**（オンボーディングの motion 許可とは別に「反応データの蓄積」への同意）と、保持期間・削除手段。
- NFR-Volume-1: 1 曲あたりの保存サイズを抑える（生全点ではなくバケット/ダウンサンプル）。目安: 数 KB/曲。
- NFR-Battery-1: バックグラウンド書き込みは曲終了時などにバッチ化し、再生体験・電池に影響しない。

## 受け入れ基準

- スキーマ・書き込み経路・プライバシー・段階案が design.md に、実装単位が tasklist.md に落ちている。
- 設計上の未決事項（下記）がユーザー判断待ちとして明示されている。

## オープンな設計判断（ユーザー判断待ち）

1. **保存粒度**: ReactionEvent サマリのみ / +intensity ダウンサンプル / +ML 用モーション特徴 / +姿勢(attitude) まで、のどこまで蓄積するか（moat・ML 価値 vs データ量・プライバシー）。→ design.md に段階案。
2. **同意モデル**: デフォルト on（オプトアウト）/ デフォルト off（オプトイン）。プライバシー訴求と蓄積速度のトレードオフ。
3. **B2B での二次利用範囲**: 集計密度の精緻化まで / 学習用データセット化まで。
4. **ML ラベル方針**: 自己申告タグを弱教師ラベルとして保存するか（＝将来の学習に必須）／single-tag でなく multi-label＋arousal-valence 回帰を採るか。

## 参考文献（精査の根拠）

- frisson ↔ ドーパミン/自律神経（皮膚電気・立毛）: [Thrills, chills, frissons, and skin orgasms (Frontiers 2014)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4107937/) / [Musical chills (McGill, Salimpoor·Zatorre)](https://www.mcgill.ca/newsroom/channels/news/musical-chills-why-they-give-us-thrills-170538)
- groove ↔ 感覚運動網・報酬: [musical groove review](https://www.academia.edu/114098699/A_review_of_psychological_and_neuroscientific_research_on_musical_groove) / [Groove & prefrontal (Nature Sci Rep 2022)](https://www.nature.com/articles/s41598-022-11324-3)
- arousal×valence の生理相関（HR・皮膚電気・顔面EMG）: [Music-prompted valence/arousal (Purdue)](https://docs.lib.purdue.edu/dissertations/AAI9819062/) / [Universal emotion psychophysiology (Frontiers 2014)](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2014.01341/full)
- 頭部/身体運動 ↔ 拍同期・情動推定: [Keeping the Beat (PLOS ONE)](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0160178) / [Affect classification of motion capture in valence-arousal (ACM)](https://dl.acm.org/doi/10.1145/2948910.2948936)
- flow/没入の生理（HRV低下・弛緩と重複）: [Physiological aspects of flow (HRV/cortisol)](https://www.researchgate.net/publication/251472781_Physiological_aspects_of_flow_experiences_Skills-demand-compatibility_effects_on_heart_rate_variability_and_salivary_cortisol)
