import { type ComponentProps } from "solid-js"
import { bairuiLetters, bairuiMark } from "./bairui-brand"

export const Mark = (props: { class?: string }) => {
  return (
    <svg data-component="logo-mark" classList={{ [props.class ?? ""]: !!props.class }} viewBox="0 0 16 20" fill="none" xmlns="http://www.w3.org/2000/svg" aria-label="BAIRUI" role="img">
      <path d={bairuiMark} transform="translate(1 0.2) scale(2.8)" fill="var(--icon-strong-base)" />
    </svg>
  )
}

export const Splash = (props: Pick<ComponentProps<"svg">, "ref" | "class">) => {
  return (
    <svg ref={props.ref} data-component="logo-splash" classList={{ [props.class ?? ""]: !!props.class }} viewBox="0 0 80 100" fill="none" xmlns="http://www.w3.org/2000/svg" aria-label="BAIRUI" role="img">
      <path d={bairuiMark} transform="translate(5 1) scale(14)" fill="var(--icon-strong-base)" />
    </svg>
  )
}

export const Logo = (props: { class?: string }) => {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 210 42" fill="none" classList={{ [props.class ?? ""]: !!props.class }} aria-label="BAIRUI" role="img">
      {bairuiLetters.map((d, index) => (
        <path d={d} fill={index < 3 ? "var(--icon-base)" : "var(--icon-strong-base)"} />
      ))}
    </svg>
  )
}
