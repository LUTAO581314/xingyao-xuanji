import { Schema } from "effect"
import { HttpApi, HttpApiEndpoint, HttpApiGroup, OpenApi } from "effect/unstable/httpapi"
import { described } from "./metadata"

const root = "/local"

export const LocalDirectoryQuery = Schema.Struct({
  path: Schema.String,
})

export const LocalDirectoryCreatePayload = Schema.Struct({
  parent: Schema.String,
  name: Schema.String,
})

export const LocalDrive = Schema.Struct({
  name: Schema.String,
  path: Schema.String,
})

export const LocalDirectoryEntry = Schema.Struct({
  name: Schema.String,
  path: Schema.String,
  type: Schema.Union([Schema.Literal("file"), Schema.Literal("directory")]),
})

export const LocalDirectoryListing = Schema.Struct({
  path: Schema.String,
  entries: Schema.Array(LocalDirectoryEntry),
})

export class LocalDirectoryError extends Schema.ErrorClass<LocalDirectoryError>("LocalDirectoryError")(
  {
    name: Schema.Literal("LocalDirectoryError"),
    data: Schema.Struct({
      message: Schema.String,
      path: Schema.String,
      code: Schema.optional(Schema.String),
    }),
  },
  { httpApiStatus: 400 },
) {}

export const LocalPaths = {
  drives: `${root}/drives`,
  directories: `${root}/directories`,
} as const

export const LocalApi = HttpApi.make("local").add(
  HttpApiGroup.make("local")
    .add(
      HttpApiEndpoint.get("drives", LocalPaths.drives, {
        success: described(Schema.Array(LocalDrive), "Available local drives"),
        error: LocalDirectoryError,
      }).annotateMerge(
        OpenApi.annotations({
          identifier: "local.drives",
          summary: "List local drives",
          description: "List the local drives available to the BAIRUI process.",
        }),
      ),
      HttpApiEndpoint.get("directories", LocalPaths.directories, {
        query: LocalDirectoryQuery,
        success: described(LocalDirectoryListing, "Local directory listing"),
        error: LocalDirectoryError,
      }).annotateMerge(
        OpenApi.annotations({
          identifier: "local.directories",
          summary: "List a local directory",
          description: "List files and directories at an absolute local path.",
        }),
      ),
      HttpApiEndpoint.post("createDirectory", LocalPaths.directories, {
        payload: LocalDirectoryCreatePayload,
        success: described(LocalDirectoryEntry, "Local directory created"),
        error: LocalDirectoryError,
      }).annotateMerge(
        OpenApi.annotations({
          identifier: "local.directories.create",
          summary: "Create a local directory",
          description: "Create one directory below an existing local directory.",
        }),
      ),
    )
    .annotateMerge(OpenApi.annotations({ title: "local", description: "Local filesystem routes." })),
)
