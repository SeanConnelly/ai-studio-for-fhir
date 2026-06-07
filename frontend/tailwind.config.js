/** @type {import('tailwindcss').Config} */
export default {
  darkMode: ["class"],
  content: [
    "./studio/index.html",
    "./studio/src/**/*.{ts,tsx}",
    "./clinical/index.html",
    "./clinical/src/**/*.{ts,tsx}",
    "./shared/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // NHS blue palette (NHS identity: #005EB8 primary, #003087 dark, #0072CE bright)
        nhs: {
          50: "#eaf2fb",
          100: "#cfe2f5",
          200: "#a6c8ec",
          300: "#6ea7e0",
          400: "#3385d4",
          500: "#0072CE",
          600: "#005EB8",
          700: "#004c96",
          800: "#003087",
          900: "#00205b",
        },
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};
