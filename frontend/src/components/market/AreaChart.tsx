"use client";

import { useEffect, useRef } from "react";
import { AreaSeries, ColorType, createChart, IChartApi } from "lightweight-charts";

interface Point {
  time: string;
  value: number;
}

export function AreaChart({
  data,
  compact = false,
  height = 260,
}: {
  data: Point[];
  compact?: boolean;
  height?: number;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    const isDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    const gain = "#089981";

    const chart = createChart(containerRef.current, {
      height,
      layout: {
        background: { type: ColorType.Solid, color: "transparent" },
        textColor: isDark ? "#868993" : "#787b86",
        fontSize: 11,
      },
      grid: {
        vertLines: { visible: false },
        horzLines: { visible: !compact, color: isDark ? "#2a2e39" : "#e0e3eb" },
      },
      rightPriceScale: { visible: !compact, borderVisible: false },
      timeScale: { visible: !compact, borderVisible: false },
      crosshair: compact ? { horzLine: { visible: false }, vertLine: { visible: false } } : undefined,
      handleScroll: !compact,
      handleScale: !compact,
    });

    const series = chart.addSeries(AreaSeries, {
      lineColor: gain,
      topColor: "rgba(8, 153, 129, 0.28)",
      bottomColor: "rgba(8, 153, 129, 0.0)",
      lineWidth: 2,
      priceLineVisible: false,
      lastValueVisible: !compact,
    });

    series.setData(data.map((d) => ({ time: d.time, value: d.value })));
    chart.timeScale().fitContent();
    chartRef.current = chart;

    const resizeObserver = new ResizeObserver((entries) => {
      const { width } = entries[0].contentRect;
      chart.applyOptions({ width });
    });
    resizeObserver.observe(containerRef.current);

    return () => {
      resizeObserver.disconnect();
      chart.remove();
    };
  }, [data, compact, height]);

  return <div ref={containerRef} className="w-full" />;
}
