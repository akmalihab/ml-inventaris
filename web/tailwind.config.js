/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{vue,ts}'],
  theme: {
    extend: {
      colors: {
        primary:   '#10B981', // Emerald 500
        secondary: '#34D399', // Emerald 400
        accent:    '#F43F5E', // Rose 500
        dark: {
          950: '#060911',
          900: '#090D16',
          850: '#0F1626',
          800: '#141D30',
          750: '#1A253C',
          700: '#23304D',
        },
      },
      fontFamily: {
        heading: ['Plus Jakarta Sans', 'sans-serif'],
        mono:    ['JetBrains Mono', 'monospace'],
        body:    ['Plus Jakarta Sans', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
