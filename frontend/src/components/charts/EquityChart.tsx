"use client";

import { useEffect, useRef } from "react";
import { LineSeries, LineStyle, createChart } from "lightweight-charts";
import type { CurvePoint } from "@/lib/types";
import { baseChartOptions, chartPalette } from "./chart-theme";

/** Growth of 1 unit: tuned strategy vs. buy-and-hold. */
export function EquityChart({ points, height = 260 }: { points: CurvePoint[]; height?: number }) {
  const container = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!container.current || !points.length) return;
    const palette = chartPalette();
    const chart = createChart(container.current, baseChartOptions(height));
    const strategy = chart.addSeries(LineSeries, { color: palette.brand, lineWidth: 2, title: "Strategy" });
    const benchmark = chart.addSeries(LineSeries, { color: palette.text, lineWidth: 1, lineStyle: LineStyle.Dashed, title: "Buy & hold" });
    strategy.setData(points.map((p) => ({ time: p.time, value: p.strategy })));
    benchmark.setData(points.map((p) => ({ time: p.time, value: p.buy_and_hold })));
    chart.timeScale().fitContent();
    const observer = new ResizeObserver(([entry]) => chart.applyOptions({ width: entry.contentRect.width }));
    observer.observe(container.current);
    return () => {
      observer.disconnect();
      chart.remove();
    };
  }, [points, height]);

  return <div ref={container} className="w-full" style={{ height }} />;
}
