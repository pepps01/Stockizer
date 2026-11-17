/** On/off switch: brand green when on, readable in light and dark. */
export function Switch({ checked, onChange, label, disabled }: { checked: boolean; onChange: () => void; label: string; disabled?: boolean }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={onChange}
      className={`flex h-7 w-12 shrink-0 items-center rounded-full p-[3px] transition-colors disabled:opacity-50 ${checked ? "justify-end bg-mint-deep" : "justify-start bg-border"}`}
    >
      <span className="h-[22px] w-[22px] rounded-full bg-white shadow-sm" />
    </button>
  );
}
