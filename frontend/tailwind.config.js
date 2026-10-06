/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#0b0f17",
        panel: "#121826",
        panel2: "#0f1522",
        edge: "#1e293b",
        accent: "#6ea8fe",
        good: "#34d399",
        bad: "#f87171",
      },
    },
  },
  plugins: [],
};
