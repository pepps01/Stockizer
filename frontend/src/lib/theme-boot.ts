// Shared by the server layout (which inlines the script) and lib/theme.ts. No
// "use client" here: the layout needs the string itself, not a client reference.
export const THEME_KEY = "stockiser-theme";

/** Runs in <head> before first paint: applies the saved theme, or the device's. */
export const THEME_BOOT_SCRIPT = `(function(){try{var p=localStorage.getItem("${THEME_KEY}");var d=p==="dark"||((!p||p==="system")&&window.matchMedia("(prefers-color-scheme: dark)").matches);document.documentElement.dataset.theme=d?"dark":"light";}catch(e){}})();`;
