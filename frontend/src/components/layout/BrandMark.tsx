/** The Stockiser mark (approved option V6, "Signal through noise"): the forest S,
 * the signal, cutting through four deeper-mint market bars on a mint tile.
 * Same drawing as src/app/icon.svg and mobile/lib/widgets/brand_mark.dart. */
export const BRAND = { mint: "#4ee478", forest: "#114325", bars: "#25b356" };

export function BrandMark({ size = 28, title }: { size?: number; title?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 200 200"
      role={title ? "img" : undefined}
      aria-label={title}
      aria-hidden={title ? undefined : true}
      className="shrink-0"
    >
      <rect width="200" height="200" rx="46" fill={BRAND.mint} />
      <g transform="translate(100 100) scale(1.12)" fill="none" strokeWidth="14" strokeLinecap="round">
        <g stroke={BRAND.bars}>
          <line x1="0" y1="-64" x2="0" y2="-40" />
          <line x1="29" y1="-46" x2="29" y2="-22" />
          <line x1="-29" y1="22" x2="-29" y2="46" />
          <line x1="0" y1="40" x2="0" y2="64" />
        </g>
        <path d="M-29 -36 V-31 C-29 -12 29 12 29 31 V36" stroke={BRAND.forest} strokeLinejoin="round" />
      </g>
    </svg>
  );
}
