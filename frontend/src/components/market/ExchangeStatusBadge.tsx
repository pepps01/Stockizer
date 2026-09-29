export function ExchangeStatusBadge({ isOpen }: { isOpen: boolean }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium ${
        isOpen ? "bg-gain/10 text-gain" : "bg-surface-muted text-muted-foreground"
      }`}
    >
      <span className={`h-1.5 w-1.5 rounded-full ${isOpen ? "bg-gain" : "bg-muted-foreground"}`} />
      {isOpen ? "Open" : "Closed"}
    </span>
  );
}
