import { createUniqueId, type ComponentProps } from "solid-js"
import { bairuiLetters } from "../../components/bairui-brand"

export function WordmarkV2(props: Pick<ComponentProps<"svg">, "class">) {
  const mask = createUniqueId()
  const maskGradient = createUniqueId()
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 210 42" fill="none" classList={{ [props.class ?? ""]: !!props.class }} aria-label="BAIRUI" role="img">
      <g opacity="0.6" mask={`url(#${mask})`}>
        {bairuiLetters.map((d) => <path d={d} opacity="0.112" fill="currentColor" />)}
      </g>
      <defs>
        <mask id={mask} style="mask-type:alpha" maskUnits="userSpaceOnUse" x="0" y="0" width="210" height="42">
          <rect width="210" height="42" fill={`url(#${maskGradient})`} />
        </mask>
        <linearGradient id={maskGradient} x1="105" y1="22" x2="105" y2="42" gradientUnits="userSpaceOnUse">
          <stop stop-color="white" stop-opacity="0.7" />
          <stop offset="1" stop-color="white" stop-opacity="0" />
        </linearGradient>
      </defs>
    </svg>
  )
}
