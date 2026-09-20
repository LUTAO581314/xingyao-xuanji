import { Effect } from "effect"
import { HttpApiBuilder } from "effect/unstable/httpapi"
import { readdir, stat, mkdir } from "node:fs/promises"
import path from "node:path"
import { RootHttpApi } from "../api"
import {
  LocalDirectoryCreatePayload,
  LocalDirectoryError,
  LocalDirectoryQuery,
} from "../groups/local"

function errorCode(cause: unknown) {
  return cause && typeof cause === "object" && "code" in cause && typeof cause.code === "string"
    ? cause.code
    : undefined
}

function errorMessage(cause: unknown, fallback: string) {
  return cause instanceof Error && cause.message ? cause.message : fallback
}

function localError(pathname: string, cause: unknown, fallback: string) {
  const code = errorCode(cause)
  const message =
    code === "EACCES" || code === "EPERM"
      ? "Permission denied"
      : code === "ENOENT"
        ? "The path does not exist"
        : code === "EEXIST"
          ? "A directory with this name already exists"
          : errorMessage(cause, fallback)
  return new LocalDirectoryError({
    name: "LocalDirectoryError",
    data: { message, path: pathname, code },
  })
}

function absolutePath(value: string) {
  const input = value.trim()
  if (!input) throw new Error("A path is required")
  const windowsDrive = /^[A-Za-z]:$/.test(input) ? `${input}\\` : input
  const normalized = process.platform === "win32" ? windowsDrive.replaceAll("/", "\\") : windowsDrive
  if (!path.isAbsolute(normalized)) throw new Error("An absolute path is required")
  return path.normalize(normalized)
}

function validDirectoryName(value: string) {
  const name = value.trim()
  if (!name || name === "." || name === "..") throw new Error("Enter a valid folder name")
  if (/[\\/\u0000-\u001f]/.test(name))
    throw new Error("Folder names cannot contain path separators or control characters")
  if (process.platform === "win32") {
    if (/[<>:"|?*]/.test(name) || /[. ]$/.test(name))
      throw new Error("Folder name contains an invalid Windows character")
    const device = name.split(".", 1)[0].toUpperCase()
    if (/^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/.test(device)) throw new Error("That name is reserved by Windows")
  }
  return name
}

async function drives() {
  if (process.platform !== "win32") return [{ name: "/", path: "/" }]
  const found = await Promise.all(
    Array.from({ length: 26 }, (_, index) => {
      const letter = String.fromCharCode(65 + index)
      const drive = `${letter}:\\`
      return stat(drive)
        .then(() => ({ name: `${letter}:`, path: drive }))
        .catch(() => undefined)
    }),
  )
  return found.filter((drive): drive is { name: string; path: string } => drive !== undefined)
}

async function listDirectory(value: string) {
  const directory = absolutePath(value)
  const entries = await readdir(directory, { withFileTypes: true })
  entries.sort((left, right) => {
    const type = Number(right.isDirectory()) - Number(left.isDirectory())
    return type || left.name.localeCompare(right.name, undefined, { sensitivity: "base" })
  })
  return {
    path: directory,
    entries: entries.map((entry) => ({
      name: entry.name,
      path: path.join(directory, entry.name),
      type: (entry.isDirectory() ? "directory" : "file") as "directory" | "file",
    })),
  }
}

async function createDirectory(parentValue: string, nameValue: string) {
  const parent = absolutePath(parentValue)
  let name: string
  try {
    name = validDirectoryName(nameValue)
  } catch (cause) {
    throw localError(parent, cause, "Invalid folder name")
  }
  const target = path.join(parent, name)
  if (path.dirname(target) !== parent) throw localError(parent, new Error("Invalid folder name"), "Invalid folder name")
  await mkdir(target)
  return { name, path: target, type: "directory" as const }
}

export const localHandlers = HttpApiBuilder.group(RootHttpApi, "local", (handlers) =>
  Effect.gen(function* () {
    const drivesHandler = Effect.fn("LocalHttpApi.drives")(function* () {
      return yield* Effect.tryPromise({
        try: drives,
        catch: (cause) => localError("", cause, "Unable to list local drives"),
      })
    })

    const directories = Effect.fn("LocalHttpApi.directories")(function* (ctx: {
      query: typeof LocalDirectoryQuery.Type
    }) {
      return yield* Effect.tryPromise({
        try: () => listDirectory(ctx.query.path),
        catch: (cause) => localError(ctx.query.path, cause, "Unable to read this folder"),
      })
    })

    const createDirectoryHandler = Effect.fn("LocalHttpApi.createDirectory")(function* (ctx: {
      payload: typeof LocalDirectoryCreatePayload.Type
    }) {
      return yield* Effect.tryPromise({
        try: () => createDirectory(ctx.payload.parent, ctx.payload.name),
        catch: (cause) =>
          cause instanceof LocalDirectoryError
            ? cause
            : localError(ctx.payload.parent, cause, "Unable to create this folder"),
      })
    })

    return handlers
      .handle("drives", drivesHandler)
      .handle("directories", directories)
      .handle("createDirectory", createDirectoryHandler)
  }),
)
