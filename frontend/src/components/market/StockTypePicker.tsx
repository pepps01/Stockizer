import type { StockType, StockTypeOption } from "@/lib/types";

/** The Selector's starting parameter: which kind of stock to screen for.
 * A quiet radio list, one hairline row per type with its definition. */
export function StockTypePicker({
  options,
  value,
  onChange,
}: {
  options: StockTypeOption[];
  value: StockType;
  onChange: (value: StockType) => void;
}) {
  return (
    <div role="radiogroup" aria-label="Stock type" className="divide-y divide-border border-y border-border">
      {options.map((o) => {
        const selected = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={selected}
            onClick={() => onChange(o.value)}
            className="flex w-full items-start gap-3 py-3 text-left"
          >
            <span
              aria-hidden
              className={`mt-0.5 grid size-[18px] shrink-0 place-items-center rounded-full border-2 transition-colors ${
                selected ? "border-foreground" : "border-border"
              }`}
            >
              {selected && <span className="size-2 rounded-full bg-foreground" />}
            </span>
            <span>
              <span className="block text-sm font-bold">{o.label}</span>
              <span className="mt-0.5 block text-xs leading-relaxed text-muted-foreground">{o.description}</span>
            </span>
          </button>
        );
      })}
    </div>
  );
}

const STYLE_LABEL: Record<string, string> = { growth: "Growth", value: "Value", blend: "Blend" };

/** Small caps style tag for a ranked result. */
export function StyleTag({ style }: { style?: string | null }) {
  if (!style) return <span className="text-muted-foreground">—</span>;
  return <span className="text-[11px] font-bold uppercase tracking-[0.1em] text-muted-foreground">{STYLE_LABEL[style] ?? style}</span>;
}
