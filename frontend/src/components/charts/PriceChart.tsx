"use client";

import { useEffect, useRef } from "react";
import { AreaSeries, CandlestickSeries, HistogramSeries, createChart } from "lightweight-charts";
import type { Bar } from "@/lib/types";
import { baseChartOptions, chartPalette } from "./chart-theme";

export type ChartStyle = "candles" | "area";

export function PriceChart({ bars, style = "candles", height = 420, showVolume = true }: { bars: Bar[]; style?: ChartStyle; height?: number; showVolume?: boolean }) {
  const container = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!container.current || !bars.length) return;
    const palette = chartPalette();
    const chart = createChart(container.current, baseChartOptions(height));

    if (style === "candles") {
      const series = chart.addSeries(CandlestickSeries, {
        upColor: palette.gain,
        downColor: palette.loss,
        borderVisible: false,
        wickUpColor: palette.gain,
        wickDownColor: palette.loss,
      });
      series.setData(bars.map((b) => ({ time: b.time, open: b.open, high: b.high, low: b.low, close: b.close })));
    } else {
      const rising = bars[bars.length - 1].close >= bars[0].close;
      const color = rising ? palette.gain : palette.loss;
      const series = chart.addSeries(AreaSeries, {
        lineColor: color,
        topColor: `${color}44`,
        bottomColor: `${color}00`,
        lineWidth: 2,
      });
      series.setData(bars.map((b) => ({ time: b.time, value: b.close })));
    }

    if (showVolume && bars.some((b) => b.volume > 0)) {
      const volume = chart.addSeries(HistogramSeries, { priceScaleId: "volume", priceFormat: { type: "volume" }, lastValueVisible: false, priceLineVisible: false });
      volume.priceScale().applyOptions({ scaleMargins: { top: 0.82, bottom: 0 } });
      volume.setData(bars.map((b) => ({ time: b.time, value: b.volume, color: `${b.close >= b.open ? palette.gain : palette.loss}55` })));
    }

    chart.timeScale().fitContent();
    const observer = new ResizeObserver(([entry]) => chart.applyOptions({ width: entry.contentRect.width }));
    observer.observe(container.current);
    return () => {
      observer.disconnect();
      chart.remove();
    };
  }, [bars, style, height, showVolume]);

  return <div ref={container} className="w-full" style={{ height }} />;
}
