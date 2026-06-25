# Research & Design Decisions

## Summary
- **Feature**: `x-style-memo-app`（アプリ名: Tegaru）
- **Discovery Scope**: New Feature（グリーンフィールド / Apple フレームワーク依存が強い）
- **Key Findings**:
  - Foundation Models（iOS 26）は `SystemLanguageModel.default.availability` で可用性を判定でき、`LanguageModelSession(instructions:)` + `respond(to:generating:)` + `@Generable`/`@Guide` で構造化出力を得られる。縮退判定（Req 12）と AI リアクション（Req 9）の土台になる。
  - iOS 27（WWDC2026）で Foundation Models に **Spotlight 検索ツール**（`Tool` プロトコル準拠）が追加され、Core Spotlight インデックスを使った完全オンデバイス RAG が可能。`searchableItems(forIdentifiers:)` で元 `CSSearchableItem` を復元できる。RAG（Req 10）の本命経路。
  - SwiftData の `.cascade` 削除は **inverse 関係を明示しないと期待どおり動かない**事例が報告されている。親子（`Memo.parent`/`replies`）の連鎖削除（Req 3.4）は inverse を明示する必要がある。
  - WWDC2026 で provider 非依存の `LanguageModel` プロトコルが追加され、将来のクラウド AI 差し替え（要件外 §10）が現実的になった。今回はオンデバイス固定だが抽象化の余地として留意。

## Research Log

### Foundation Models の可用性判定と構造化出力
- **Context**: AI 機能の縮退（Req 12）と AI いいね/リプライ（Req 9）をどの API で実現するか。
- **Sources Consulted**:
  - [SystemLanguageModel | Apple Developer](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
  - [Exploring the Foundation Models framework](https://www.createwithswift.com/exploring-the-foundation-models-framework/)
  - [Getting Started with Foundation Models in iOS 26](https://www.appcoda.com/foundation-models/)
- **Findings**:
  - `SystemLanguageModel.default` で基本モデルにアクセス。`availability` は `.available` / `.unavailable(reason)` を返し、Apple Intelligence 無効・非対応端末・モデル未ダウンロードを区別できる。
  - `LanguageModelSession` は単一コンテキスト（プロンプト/応答の履歴を保持）。ペルソナごとに独立セッションを張る方針（Req 8.4）と整合。
  - `@Generable` + `@Guide` でガイド付き構造化出力。`PersonaReaction`（shouldLike / shouldReply / replyText）をそのまま採用可能（Req 9.1）。
- **Implications**: 起動時に `availability` を 1 度評価して AI 機能フラグ（`AIFeatureGate`）に落とし込み、UI（アクティビティタブ）とサービス起動を分岐する。

### iOS 27 Spotlight 検索ツールによる RAG
- **Context**: 関連メモ提示（Req 10）の本命経路と代替経路の切り分け。
- **Sources Consulted**:
  - [What's new in the Foundation Models framework - WWDC26](https://developer.apple.com/videos/play/wwdc2026/241/)
  - [On-Device AI Across iOS 27: Spotlight and Media](https://blakecrosley.com/blog/on-device-ai-spotlight-media-ios-27)
  - [Foundation Models in iOS 27: Tool-Calling Control](https://blakecrosley.com/blog/foundation-models-tool-calling-ios-27)
- **Findings**:
  - Spotlight 検索ツールは `Tool` プロトコルに準拠し、モデルが生成途中にアプリの Core Spotlight インデックスを直接検索して文脈に取り込む。ネットワーク不要。
  - 各メモを `CSSearchableItem`（identifier = `Memo.id`）としてインデックスしておく必要がある。インデックス更新は投稿・編集・削除に同期させる。
  - ツール呼び出しは framework が直列/並列を最適に調停する。
- **Implications**: RAG はストラテジ切り替え（`RelatedMemoFinder` プロトコル）にし、iOS 27+ は Spotlight ツール経路、それ未満は決定的フォールバック（タグ重複 / `NLContextualEmbedding`）を使う。

### SwiftData の関係・カスケード・並行性
- **Context**: 親子スレッド・多対多（likedBy/tags）・自己参照のモデリングと連鎖削除（Req 3.4, 6, 4）、バックグラウンド生成（Req 9.4）。
- **Sources Consulted**:
  - [Relationship deleteRule | Apple Developer](https://developer.apple.com/documentation/swiftdata/relationship(_:deleterule:minimummodelcount:maximummodelcount:originalname:inverse:hashmodifier:))
  - [How to create cascade deletes using relationships (Hacking with Swift)](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-cascade-deletes-using-relationships)
  - [Relationships in SwiftData - fatbobman](https://fatbobman.com/en/posts/relationships-in-swiftdata-changes-and-considerations/)
- **Findings**:
  - `.cascade` は inverse 関係を明示するか、片側を非 Optional にすると安定する。曖昧な構成だと連鎖削除が発火しない既知不具合がある。
  - 自己参照（`Memo.parent` ↔ `Memo.replies`）は inverse を明示し、`replies` 側に `.cascade` を付与する。
  - 多対多（`Memo.likedBy` ↔ `Persona.likedMemos`、`Memo.tags` ↔ `Tag.memos`）は `.nullify`（既定）で関連解除のみ。
  - `ModelContext` は Sendable でない。バックグラウンド書き込みは `@ModelActor` による専用コンテキストで行う。
- **Implications**: モデル定義で inverse を明示。AI 生成は `@ModelActor` バックグラウンドアクターで実行し、UI の `@Query` は `mainContext` を使う。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| MV（Model + SwiftUI View + `@Query`） | サービスを薄く保ち View で `@Query` 直結 | SwiftData の宣言的データ駆動を最大活用、記述量小 | AI/RAG の複雑ロジックが View に漏れやすい | コア CRUD に最適 |
| 軽量レイヤード（Models → Services → State → Views） | 副作用（AI/RAG/Spotlight/Seed）をサービスに隔離し View は表示に専念 | 境界が明確・並行実装可・テスト容易 | サービスの配線がやや増える | **採用**。CRUD は `@Query` 直結、副作用のみサービス化 |
| MVVM 全面適用 | 全画面に ViewModel | 関心分離が厳密 | `@Query` の利点を捨て冗長 | 過剰 |

## Design Decisions

### Decision: AI 生成をバックグラウンド `@ModelActor` で逐次実行
- **Context**: Req 9.4（UI 非ブロック）, 9.6（低並行度）, 14.3（UI スレッド非ブロック）, SwiftData の `ModelContext` 非 Sendable 制約。
- **Alternatives Considered**:
  1. メインコンテキストで `Task` 実行 — 実装は単純だが大量メモ時に UI と競合し、Sendable 制約に抵触。
  2. `@ModelActor` 専用バックグラウンドコンテキスト — 分離された `ModelContext` で安全に書き込み。
- **Selected Approach**: `PersonaReactionEngine` を `@ModelActor` 化し、投稿後に `PersistentIdentifier` を渡して起動。ペルソナを 1 体ずつ `Task.sleep` を挟みつつ逐次処理。書き込みは保存後 `mainContext` の `@Query` が自動反映。
- **Rationale**: Sendable 安全・UI 非ブロック・「反応がパラパラ届く」体験（Req 9.5）を同時に満たす。
- **Trade-offs**: アクター境界を跨ぐため `Memo`/`Persona` 本体ではなく `PersistentIdentifier` を受け渡す必要がある。
- **Follow-up**: アクター内 fetch のエラー（対象削除済み）時はスキップ。

### Decision: アクティビティ記録のための `ReactionEvent` エンティティ追加
- **Context**: Req 11.2 は「いいね・リプライ・気づきを新しい順に一覧」。だが「いいね」は `likedBy` 多対多メンバーシップのみで**タイムスタンプを持たない**ため、時系列整列ができない。気づき（Req 10.5）も保存先が未定義。
- **Alternatives Considered**:
  1. 既存 3 エンティティのみで導出 — リプライは `Memo.createdAt` で並ぶが、いいねは時刻不明で整列不能。
  2. `ReactionEvent`（kind: like/reply/insight, persona, targetMemo, createdAt, 付帯参照）を追加 — 3 種を 1 クエリで時系列取得。
- **Selected Approach**: オプション 2。AI リアクション適用時に対応する `ReactionEvent` を併せて記録。アクティビティ画面は `ReactionEvent` を `createdAt` 降順で取得（Req 11.2）。
- **Rationale**: いいねの時刻問題を解消し、3 種のリアクションを統一的に扱える。リプライ本体は引き続き `Memo` に存在し、`ReactionEvent.reply` が参照。
- **Trade-offs**: 仕様 §7 の 3 エンティティから 1 つ増える。本スペックが所有するデータとして明示。
- **Follow-up（レビュー反映 / 設計確定）**: 参照整合は SwiftData の削除規則で自動保証する。`ReactionEvent.targetMemo` を inverse 明示 + `.cascade`（対象メモ削除でイベント消滅）、`replyMemo`/`relatedMemo` は `.nullify`。これにより親メモ cascade 削除時の dangling `PersistentIdentifier` を防ぐ。

### Decision: RAG はストラテジ切り替え（`RelatedMemoFinder` プロトコル）
- **Context**: Req 10.3/10.4。本命は iOS 27+ の Spotlight ツール、代替は iOS 17+ の決定的手法。
- **Selected Approach**: `RelatedMemoFinder` プロトコルを定義し、`SpotlightToolFinder`（iOS 27+）/ `TagOverlapFinder`（タグ重複）/ `EmbeddingFinder`（`NLContextualEmbedding`）を実装。起動時の OS バージョン・可用性で実装を注入。
- **Rationale**: 経路差を 1 箇所に隔離し、上位（ペルソナの気づき生成）は経路非依存。
- **Trade-offs**: 3 実装の維持コスト。フォールバックは決定的で安価なため許容。
- **Follow-up（レビュー反映 / 設計確定）**: 関連メモ算出は**メモ単位に 1 回**だけ実行し全ペルソナで共有（ペルソナ毎の重複検索を排除, 9.6/14.3）。気づきは関連メモがある場合のみ、専用 `@Generable`（`PersonaInsight`: `relatedMemoIndex` + `insightText`）で**1 投稿につき高々 1 回**生成し grounded 化（10.2, 10.5）。`PersonaReaction`（いいね/返信）とは別ステップに分離。

### Decision: コア機能は `@Query` 直結、副作用のみサービス化
- **Context**: Req 14.1/14.2（数千件で滑らか、ソート/フィルタは DB 側）。
- **Selected Approach**: タイムライン・検索・スレッドは SwiftUI `@Query`（`#Predicate` + `SortDescriptor`）で直接取得。ハッシュタグ抽出・タグ upsert・AI 反応・RAG・Spotlight・シードのみサービス層へ。
- **Rationale**: SwiftData のクエリ最適化を活かしつつ、複雑な副作用を境界に隔離。
- **Trade-offs**: View にクエリ定義が分散するが、各画面の責務に閉じるため許容。

## Risks & Mitigations
- **SwiftData カスケードの不発** — 親子 inverse を明示し、`replies` に `.cascade`。削除後に孤児リプライが無いことをテストで担保。
- **Foundation Models の応答揺れ/失敗** — 構造化出力の検証（空 `replyText` 時は返信生成しない）、`try` 失敗時は当該ペルソナをスキップしアプリは継続（Req 12.3 のコア継続性を守る）。
- **iOS 27 Spotlight ツールの提供時期/挙動の不確実性** — フォールバック経路（タグ重複/埋め込み）を常備し、本命が使えない端末でも Req 10 を満たす。
- **`@ModelActor` 跨ぎのオブジェクト受け渡し** — 本体ではなく `PersistentIdentifier` を渡し、アクター内で再 fetch。
- **編集時の Spotlight/タグ不整合** — 編集サービスがタグ再抽出と Spotlight 再インデックスをアトミックに行う（Req 16.5）。

## References
- [SystemLanguageModel | Apple Developer](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel) — 可用性 API
- [What's new in the Foundation Models framework - WWDC26](https://developer.apple.com/videos/play/wwdc2026/241/) — Spotlight 検索ツール / Tool プロトコル
- [On-Device AI Across iOS 27: Spotlight and Media](https://blakecrosley.com/blog/on-device-ai-spotlight-media-ios-27) — `searchableItems(forIdentifiers:)`、RAG ループ
- [Relationship deleteRule | Apple Developer](https://developer.apple.com/documentation/swiftdata/relationship(_:deleterule:minimummodelcount:maximummodelcount:originalname:inverse:hashmodifier:)) — 削除ルール/inverse
- [How to create cascade deletes using relationships (Hacking with Swift)](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-cascade-deletes-using-relationships) — cascade の実務注意
- [WWDC 2026 - Apple Just Opened the Foundation Models Framework to Any LLM Provider](https://dev.to/arshtechpro/wwdc-2026-apple-just-opened-the-foundation-models-framework-to-any-llm-provider-5ejn) — provider 抽象（将来のクラウド差し替え）
