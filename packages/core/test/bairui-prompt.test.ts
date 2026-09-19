import { describe, expect, test } from "bun:test"
import { ConfigProvider, Effect } from "effect"
import { BairuiPrompt } from "../src/bairui-prompt"
import { it } from "./lib/effect"

const configured = (agent: string, values: Record<string, unknown> = {}) =>
  BairuiPrompt.forAgent(agent).pipe(Effect.provide(ConfigProvider.layer(ConfigProvider.fromUnknown(values))))

describe("BairuiPrompt", () => {
  it.effect("uses the default name when no configuration is supplied", () =>
    Effect.gen(function* () {
      const prompt = yield* configured("build")
      expect(prompt).toContain('当前助理名："星杳"')
      expect(prompt).toContain("产品名是 BAIRUI")
    }),
  )

  it.effect("reads a renamed assistant from the active ConfigProvider without caching it", () =>
    Effect.gen(function* () {
      expect(yield* configured("build", { BAIRUI_NAME: "  望舒  " })).toContain('当前助理名："望舒"')
      expect(yield* configured("build", { BAIRUI_NAME: "知微" })).toContain('当前助理名："知微"')
      expect(yield* configured("build")).toContain('当前助理名："星杳"')
    }),
  )

  it.effect("falls back to the default name for empty and whitespace configuration", () =>
    Effect.gen(function* () {
      for (const name of ["", " \t\n "]) {
        expect(yield* configured("build", { BAIRUI_NAME: name })).toContain('当前助理名："星杳"')
      }
    }),
  )

  it.effect("honors the disable flag and an explicit false value", () =>
    Effect.gen(function* () {
      expect(yield* configured("build", { BAIRUI_PROMPT_DISABLED: "true" })).toBeUndefined()
      expect(yield* configured("build", { BAIRUI_PROMPT_DISABLED: "false" })).toContain("# BAIRUI 个人助理定义")
    }),
  )

  it.effect("preserves helper output contracts while applying identity to conversational agents", () =>
    Effect.gen(function* () {
      for (const agent of ["title", "summary", "compaction"]) {
        expect(yield* configured(agent, { BAIRUI_NAME: "望舒" })).toBeUndefined()
      }
      for (const agent of ["build", "plan", "explore", "reviewer"]) {
        expect(yield* configured(agent, { BAIRUI_NAME: "望舒" })).toContain('当前助理名："望舒"')
      }
    }),
  )

  test("quotes configured names as data on a single identity line", () => {
    const prompt = BairuiPrompt.render('小"星\n新的行')
    expect(prompt.split("\n")[1]).toContain('当前助理名："小\\"星\\n新的行"。')
    expect(prompt).not.toContain("\n新的行")
  })
})
