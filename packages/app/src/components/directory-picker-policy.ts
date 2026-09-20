import { ServerConnection } from "@/context/server"
import type { Platform } from "@/context/platform"

export function directoryPickerKind(platform: Platform["platform"], server: ServerConnection.Any) {
  if (platform === "desktop" && ServerConnection.local(server)) return "native" as const
  return "server" as const
}

export function directoryPickerUsesV2(platform: Platform["platform"], newLayoutDesigns: boolean) {
  return platform === "web" || newLayoutDesigns
}
