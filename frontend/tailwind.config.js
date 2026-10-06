/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Manrope", "ui-sans-serif", "system-ui", "sans-serif"],
      },
      colors: {
        // Light DeFi dashboard palette
        bg: "#F5F6F8", // page background
        card: "#FFFFFF", // card surface
        inset: "#F4F5F7", // inputs / subtle inset
        edge: "#E7E9EE", // borders
        ink: "#0B1220", // primary dark navy text
        muted: "#6B7280", // secondary text
        subtle: "#9AA1AC", // faint text / axis labels
        accent: "#6C7CF5", // soft blue/purple primary
        mint: "#5FD4A8", // secondary mint/green
        warnbg: "#FDF8E7", // cream banner
        warnborder: "#F3E3A6",
        warntext: "#8A6D12",
        link: "#2F6FED",
        good: "#12A66A",
        goodbg: "#E7F7EF",
        bad: "#DC2626",
        // legacy aliases kept so existing components render on light
        panel: "#FFFFFF",
        panel2: "#F4F5F7",
      },
      maxWidth: {
        content: "840px",
      },
    },
  },
  plugins: [],
};
