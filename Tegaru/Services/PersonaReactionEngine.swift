//
//  PersonaReactionEngine.swift
//  Tegaru
//
//  Task 5.4: ペルソナリアクションエンジン
//  Requirements: 8.3, 8.4, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 10.2, 10.5, 11.2, 13.3, 15.4, 15.5
//

import Foundation
import SwiftData
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

/// ペルソナのいいね/返信/気づきの「決定」を供給する生成系（Sendable・`@Generable` 非依存）。
/// 入力は Sendable な文字列のみとし、SwiftData モデルをアクター境界へ運ばない。
protocol PersonaReactionGenerating: Sendable {
    func reaction(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> ReactionDecision
    func insight(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> InsightDecision?
}

/// AI 非対応環境向けの無反応ジェネレータ（コア継続性のため安全側, Req 12.3）。
struct NullReactionGenerator: PersonaReactionGenerating {
    func reaction(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> ReactionDecision { .none }
    func insight(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> InsightDecision? { nil }
}

#if canImport(FoundationModels)
/// Foundation Models のオンデバイス推論を用いる本番ジェネレータ。
/// ペルソナの性格指示文で独立セッションを張り（Req 8.4）、関連メモを文脈に与えて grounded 化する（Req 10.2）。
@available(iOS 26, macOS 26, *)
struct FoundationModelsReactionGenerator: PersonaReactionGenerating {
    func reaction(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> ReactionDecision {
        let session = LanguageModelSession(instructions: personaInstructions)
        var prompt = "次のメモにあなたなりに反応してください。\nメモ: \(memoBody)"
        if !relatedBodies.isEmpty {
            prompt += "\n参考(過去のメモ):\n" + numbered(relatedBodies)
        }
        let response = try await session.respond(to: prompt, generating: PersonaReaction.self)
        return ReactionDecision(response.content)
    }

    func insight(memoBody: String, personaInstructions: String, relatedBodies: [String]) async throws -> InsightDecision? {
        guard !relatedBodies.isEmpty else { return nil }
        let session = LanguageModelSession(instructions: personaInstructions)
        let prompt = """
        新しいメモ: \(memoBody)
        以下の過去メモとのつながりに気づけば、最も関連する番号と短い気づきを述べてください。なければ空で構いません。
        \(numbered(relatedBodies))
        """
        let response = try await session.respond(to: prompt, generating: PersonaInsight.self)
        return InsightDecision(response.content)
    }

    private func numbered(_ bodies: [String]) -> String {
        bodies.enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: "\n")
    }
}
#endif

/// 起動時に注入する生成系を選択する。
enum ReactionGeneratorFactory {
    static func make() -> any PersonaReactionGenerating {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            AppLog.ai.info("ReactionGenerator: FoundationModels")
            return FoundationModelsReactionGenerator()
        }
        #endif
        AppLog.ai.notice("ReactionGenerator: Null（Foundation Models 不在）")
        return NullReactionGenerator()
    }
}

/// 背景アクターで投稿後のペルソナ反応を逐次生成・適用する。
///
/// 処理順: (1) 関連メモをメモ単位に1回だけ算出し全ペルソナで共有 →(2) 各ペルソナを遅延を挟み逐次適用 →
/// (3) 関連メモがある場合のみ代表1体が気づきを1回生成。専用 `ModelContext` で書き込み UI を非ブロック（Req 9.4, 14.3）。
@ModelActor
actor PersonaReactionEngine {
    // 既定で実経路（Foundation Models / RAG）を注入する。これにより、外部からの非同期 configure を
    // 待たずに本番の生成系が使われ、起動直後の投稿でも無反応にならない（configure はテスト用に上書き可）。
    private var generator: any PersonaReactionGenerating = ReactionGeneratorFactory.make()
    private var relatedFinder: any RelatedMemoFinder = RelatedMemoFinderFactory.make()
    private var reactionDelay: Duration = .milliseconds(400)
    private var relatedLimit = 3

    /// 依存と挙動を注入する（起動時に1度）。
    func configure(
        generator: any PersonaReactionGenerating,
        relatedFinder: any RelatedMemoFinder,
        reactionDelay: Duration = .milliseconds(400),
        relatedLimit: Int = 3
    ) {
        self.generator = generator
        self.relatedFinder = relatedFinder
        self.reactionDelay = reactionDelay
        self.relatedLimit = relatedLimit
    }

    /// 対象メモ（永続 ID）に対し、関連メモ算出 → 全ペルソナのいいね/返信 → 気づきの順に生成・適用する。
    func start(memoID: PersistentIdentifier) async {
        guard let memo = modelContext.model(for: memoID) as? Memo else {
            AppLog.ai.error("engine.start: 対象メモが見つからない")
            return
        }
        let personas = (try? modelContext.fetch(FetchDescriptor<Persona>())) ?? []
        guard !personas.isEmpty else {
            AppLog.ai.error("engine.start: ペルソナが0件（シード未了の可能性）")
            return
        }

        // (1) 関連メモはメモ単位に1回だけ算出し、全ペルソナで共有する（重複検索を回避）。
        let related = relatedFinder.relatedMemos(for: memo, limit: relatedLimit)
        let relatedBodies = related.map(\.body)
        AppLog.ai.info("engine.start: personas=\(personas.count) related=\(related.count) generator=\(String(describing: type(of: self.generator)), privacy: .public)")

        // (2) ペルソナを1体ずつ逐次処理（遅延で時間差反映, Req 9.5/9.6）。
        for persona in personas {
            do {
                let decision = try await generator.reaction(
                    memoBody: memo.body,
                    personaInstructions: persona.personality,
                    relatedBodies: relatedBodies
                )
                apply(decision, from: persona, to: memo)
                try? modelContext.save()
                AppLog.ai.info("reaction applied: persona=\(persona.name, privacy: .public) like=\(decision.shouldLike ? "Y" : "N", privacy: .public) reply=\(decision.shouldReply ? "Y" : "N", privacy: .public)")
            } catch {
                // 個別の生成失敗はスキップ（コア継続性, Req 12.3）。理由はログに残す。
                AppLog.ai.error("reaction failed: persona=\(persona.name, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                continue
            }
            if reactionDelay > .zero {
                try? await Task.sleep(for: reactionDelay)
            }
        }

        // (3) 関連メモがある場合のみ、代表1体が気づきを1回だけ生成する（Req 10.5）。
        guard !related.isEmpty, let representative = personas.first else { return }
        do {
            let insight = try await generator.insight(
                memoBody: memo.body,
                personaInstructions: representative.personality,
                relatedBodies: relatedBodies
            )
            if let insight,
               !insight.insightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               related.indices.contains(insight.relatedMemoIndex) {
                modelContext.insert(ReactionEvent(
                    kind: .insight,
                    persona: representative,
                    targetMemo: memo,
                    relatedMemo: related[insight.relatedMemoIndex],
                    insightText: insight.insightText
                ))
                try? modelContext.save()
                AppLog.ai.info("insight applied: persona=\(representative.name, privacy: .public)")
            }
        } catch {
            AppLog.ai.error("insight failed: error=\(error.localizedDescription, privacy: .public)")
        }
    }

    /// いいね/返信を適用しイベントを記録する。空の返信本文では返信を作らない（応答揺れ対策）。
    private func apply(_ decision: ReactionDecision, from persona: Persona, to memo: Memo) {
        if decision.shouldLike {
            memo.likedBy.append(persona)
            modelContext.insert(ReactionEvent(kind: .like, persona: persona, targetMemo: memo))
        }

        let replyText = decision.replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if decision.shouldReply, !replyText.isEmpty {
            let reply = Memo(body: decision.replyText, author: persona, parent: memo)
            modelContext.insert(reply)
            modelContext.insert(ReactionEvent(kind: .reply, persona: persona, targetMemo: memo, replyMemo: reply))
        }
    }
}
