import { ColorType, type DeepPartial, type ChartOptions } from "lightweight-charts";

/** Reads the CSS design tokens so charts match the site palette. */
export function chartPalette() {
  const css = getComputedStyle(document.documentElement);
  const token = (name: string, fallback: string) => css.getPropertyValue(name).trim() || fallback;
  return {
    text: token("--muted-foreground", "#6b7080"),
    grid: token("--border", "#e3e6ef"),
    gain: token("--gain", "#089981"),
    loss: token("--loss", "#f23645"),
    brand: token("--brand", "#4f46e5"),
    hold: token("--hold", "#e38a00"),
  };
}

export function baseChartOptions(height: number): DeepPartial<ChartOptions> {
  const p = chartPalette();
  return {
    height,
    layout: { background: { type: ColorType.Solid, color: "transparent" }, textColor: p.text, fontSize: 11 },
    grid: { vertLines: { visible: false }, horzLines: { color: p.grid } },
    rightPriceScale: { borderVisible: false },
    timeScale: { borderVisible: false },
  };
}
