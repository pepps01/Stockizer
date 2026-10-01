export function BrandMark({ size = 34 }: { size?: number }) {
  return (
    <span
      style={{ width: size, height: size, fontSize: size * 0.5 }}
      className="relative flex shrink-0 items-center justify-center rounded-[28%] bg-brand font-bold text-brand-foreground shadow-md shadow-brand/30"
    >
      A<span className="absolute right-[12%] top-[6%] text-[0.3em] font-semibold">™</span>
    </span>
  );
}
