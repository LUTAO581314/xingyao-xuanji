import { describe, expect, test } from "bun:test"
import { directoryPickerKind, directoryPickerUsesV2 } from "./directory-picker-policy"

const local = {
  type: "sidecar",
  variant: "base",
  http: { url: "http://localhost:4096" },
} as const
const remote = {
  type: "ssh",
  host: "example.test",
  http: { url: "http://localhost:4096" },
} as const

describe("directoryPickerKind", () => {
  test("uses the native picker only for local desktop projects", () => {
    expect(directoryPickerKind("desktop", local)).toBe("native")
    expect(directoryPickerKind("desktop", remote)).toBe("server")
    expect(directoryPickerKind("web", local)).toBe("server")
  })
})

describe("directoryPickerUsesV2", () => {
  test("keeps the web picker available with the legacy visual layout", () => {
    expect(directoryPickerUsesV2("web", false)).toBe(true)
  })

  test("follows the layout setting on desktop and other renderers", () => {
    expect(directoryPickerUsesV2("desktop", false)).toBe(false)
    expect(directoryPickerUsesV2("desktop", true)).toBe(true)
  })
})
