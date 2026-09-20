import { createMemo } from "solid-js"
import { useLocal } from "../context/local"
import { DialogSelect } from "../ui/dialog-select"
import { useDialog } from "../ui/dialog"
import { useTheme } from "../context/theme"
import { useSync } from "../context/sync"

export function DialogAgent() {
  const local = useLocal()
  const dialog = useDialog()
  const theme = useTheme()
  const sync = useSync()

  const options = createMemo(() => {
    const agents = local.agent.list()
    const primaryName = sync.data.config.default_agent ?? "build"
    const primary = agents.find((item) => item.name === primaryName)
    if (!primary)
      return agents.map((item) => ({
        value: item.name,
        title: item.name,
        description: item.native ? "native" : item.description,
      }))

    return [
      {
        value: primary.name,
        title: primary.name === "build" ? "星杳" : primary.name,
        description: primary.native ? "native" : primary.description,
      },
      ...agents
        .filter((item) => item.name !== primary.name)
        .map((item) => ({
          value: item.name,
          title: item.name,
          description: item.native ? "native" : item.description,
          category: "其他主智能体",
          categoryView: (
            <text fg={theme.theme.textMuted}>
              ──────── 其他主智能体
            </text>
          ),
        })),
    ]
  })

  return (
    <DialogSelect
      title="Select agent"
      current={local.agent.current()?.name}
      options={options()}
      onSelect={(option) => {
        local.agent.set(option.value)
        dialog.clear()
      }}
    />
  )
}
