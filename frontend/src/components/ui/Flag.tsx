import * as Flags from "country-flag-icons/react/1x1";

type FlagComponent = (props: { title?: string; className?: string }) => React.ReactElement;

export function Flag({ code, size = 20, className = "" }: { code: string | null | undefined; size?: number; className?: string }) {
  const Svg = code ? (Flags as Record<string, FlagComponent>)[code.toUpperCase()] : undefined;
  const style = { width: size, height: size };
  if (!Svg) {
    return <span style={style} className={`inline-block shrink-0 rounded-full bg-surface-muted ${className}`} />;
  }
  return (
    <span style={style} className={`inline-flex shrink-0 overflow-hidden rounded-full ring-1 ring-border ${className}`}>
      <Svg title={code ?? undefined} className="h-full w-full" />
    </span>
  );
}

export function GlobeIcon({ size = 20, className = "" }: { size?: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" className={className} aria-hidden>
      <circle cx="12" cy="12" r="9.5" />
      <path d="M2.5 12h19M12 2.5c2.8 3 2.8 16 0 19M12 2.5c-2.8 3-2.8 16 0 19" />
    </svg>
  );
}
