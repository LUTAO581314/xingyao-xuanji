import { describe, expect } from "bun:test"
import { ConfigProvider, Effect, Layer } from "effect"
import { BairuiPrompt } from "@opencode-ai/core/bairui-prompt"
import { ModelV2 } from "@opencode-ai/core/model"
import { ProviderV2 } from "@opencode-ai/core/provider"
import { RuntimeFlags } from "@/effect/runtime-flags"
import { Plugin } from "@/plugin"
import type { Provider } from "@/provider/provider"
import { ProviderTransform } from "@/provider/transform"
import { LLMNative } from "@/session/llm/native-request"
import { LLMRequestPrep } from "@/session/llm/request"
import { MessageID, SessionID } from "@/session/schema"
import { SystemPrompt } from "@/session/system"
import { testEffect } from "../lib/effect"

const model: Provider.Model = {
  id: ModelV2.ID.make("gpt-6"),
  providerID: ProviderV2.ID.openai,
  api: { id: "gpt-6", url: "https://api.openai.com/v1", npm: "@ai-sdk/openai" },
  name: "GPT-6",
  capabilities: {
    temperature: false,
    reasoning: true,
    attachment: false,
    toolcall: true,
    input: { text: true, audio: false, image: false, video: false, pdf: false },
    output: { text: true, audio: false, image: false, video: false, pdf: false },
    interleaved: false,
  },
  cost: { input: 0, output: 0, cache: { read: 0, write: 0 } },
  limit: { context: 128_000, output: 32_000 },
  status: "active",
  options: {},
  headers: {},
  release_date: "2026-01-01",
}
const agent = {
  name: "build",
  mode: "primary" as const,
  options: {},
  permission: [],
}
const sessionID = SessionID.make("ses_bairui_request")
const marker = "# BAIRUI 个人助理定义"
const it = testEffect(
  Layer.mergeAll(
    RuntimeFlags.layer(),
    ConfigProvider.layer(ConfigProvider.fromUnknown({})),
    Layer.mock(Plugin.Service, { trigger: (_name, _input, output) => Effect.succeed(output) }),
  ),
)

const prepare = Effect.fn("test.prepareBairuiRequest")(function* (
  overrides: Partial<Parameters<typeof LLMRequestPrep.prepare>[0]> = {},
) {
  const flags = yield* RuntimeFlags.Service
  const plugin = yield* Plugin.Service
  return yield* LLMRequestPrep.prepare({
    user: {
      id: MessageID.make("msg_bairui_request"),
      sessionID,
      role: "user",
      time: { created: 0 },
      agent: agent.name,
      model: { providerID: model.providerID, modelID: model.id },
      system: "Answer in Mandarin.",
    },
    sessionID,
    model,
    agent,
    provider: { id: model.providerID, name: "OpenAI", source: "config", env: [], options: {}, models: {} },
    auth: undefined,
    system: ["Repository instructions."],
    messages: [{ role: "user", content: "Hello" }],
    tools: {},
    flags,
    plugin,
    isWorkflow: false,
    ...overrides,
  })
})

describe("session.llm request identity", () => {
  it.effect("retains the model template and user context through normal and native request preparation", () =>
    Effect.gen(function* () {
      const prepared = yield* prepare()
      expect(prepared.system[0]).toStartWith(SystemPrompt.provider(model).join("\n") + "\n")
      expect(prepared.system[0]).toContain(BairuiPrompt.render())
      expect(prepared.system[0]).toContain("Repository instructions.")
      expect(prepared.system[0]).toContain("Answer in Mandarin.")
      expect(prepared.messages.filter((message) => message.role === "system")).toEqual([
        { role: "system", content: prepared.system[0] },
      ])
      expect(JSON.stringify(prepared.messages).split(marker)).toHaveLength(2)

      const native = LLMNative.request({ model, apiKey: "test-key", messages: prepared.messages })
      expect(native.system.map((part) => part.text)).toEqual(prepared.system)
      expect(JSON.stringify(native.system).split(marker)).toHaveLength(2)
    }),
  )

  it.effect("keeps a custom agent prompt as its specialist instructions", () =>
    Effect.gen(function* () {
      const prepared = yield* prepare({
        agent: { ...agent, name: "reviewer", prompt: "Report only verified regressions." },
      })
      expect(prepared.system[0]).toStartWith("Report only verified regressions.\n")
      expect(prepared.system[0]).toContain(BairuiPrompt.render())
      expect(prepared.system[0]).not.toContain(SystemPrompt.provider(model)[0])
      expect(JSON.stringify(prepared.messages).split(marker)).toHaveLength(2)
    }),
  )

  it.effect("sends OAuth identity once via instructions and preserves it through native lowering", () =>
    Effect.gen(function* () {
      const prepared = yield* prepare({ auth: { type: "oauth", access: "access", refresh: "refresh", expires: 1 } })
      expect(prepared.messages).toEqual([{ role: "user", content: "Hello" }])
      expect(prepared.params.options.instructions).toBe(prepared.system.join("\n"))
      expect(prepared.params.options.instructions.split(marker)).toHaveLength(2)
      expect(prepared.params.options.instructions).toContain(BairuiPrompt.render())

      const native = LLMNative.request({
        model,
        apiKey: "test-key",
        messages: prepared.messages,
        providerOptions: ProviderTransform.providerOptions(model, prepared.params.options),
      })
      expect(native.system).toEqual([])
      expect(native.providerOptions).toMatchObject({ openai: { instructions: prepared.system.join("\n") } })
      expect(JSON.stringify(native.providerOptions).split(marker)).toHaveLength(2)
    }),
  )

  it.effect("provides workflow system text without duplicating it in messages", () =>
    Effect.gen(function* () {
      const prepared = yield* prepare({ isWorkflow: true })
      expect(prepared.messages).toEqual([{ role: "user", content: "Hello" }])
      expect(prepared.system.join("\n")).toContain(BairuiPrompt.render())
      expect(prepared.system.join("\n").split(marker)).toHaveLength(2)
    }),
  )

  it.effect("does not add a conversational identity to auxiliary agent requests", () =>
    Effect.gen(function* () {
      for (const name of ["title", "summary", "compaction"]) {
        const prepared = yield* prepare({ agent: { ...agent, name, prompt: "Use the required output format." } })
        expect(prepared.system[0]).toStartWith("Use the required output format.\n")
        expect(JSON.stringify(prepared.messages)).not.toContain(marker)
      }
    }),
  )

  it.effect("can disable the identity while preserving provider and user instructions", () =>
    Effect.gen(function* () {
      const prepared = yield* prepare().pipe(
        Effect.provide(ConfigProvider.layer(ConfigProvider.fromUnknown({ BAIRUI_PROMPT_DISABLED: "true" }))),
      )
      expect(prepared.system[0]).toStartWith(SystemPrompt.provider(model).join("\n") + "\n")
      expect(prepared.system[0]).toContain("Answer in Mandarin.")
      expect(JSON.stringify(prepared.messages)).not.toContain(marker)
    }),
  )
})
