/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Manrope", "ui-sans-serif", "system-ui", "sans-serif"],
      },
      colors: {
        // Light theme tokens
        ink: "#f7f8fa", // page background
        panel: "#ffffff", // card background
        panel2: "#f1f3f7", // subtle inset / inputs
        edge: "#e2e5ec", // borders
        accent: "#2563eb", // primary blue
        good: "#059669",
        bad: "#dc2626",
      },
    },
  },
  plugins: [],
};
