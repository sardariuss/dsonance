module.exports = {
    darkMode: 'class', // Enables class-based dark mode
	content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
    theme: {
        extend: {
            colors: {
                'slate-850' : '#172032',
                'brand-true' : 'oklch(62.7% 0.194 149.214)',
                'brand-true-dark' : 'oklch(72.3% 0.219 149.579)',
                'brand-false' : 'oklch(63.7% 0.237 25.331)',
                'brand-line': '#073a59',
                'brand-white': '#ebfcf6',
            },
            fontFamily: {
                'acelon': ['Acelon', 'sans-serif'],
                'cafe': ['Cafe', 'sans-serif'],
                'decoment': ['Decoment', 'sans-serif'],
            },
        },
    },
    plugins: [require('@tailwindcss/typography'), require('tailwindcss-animate')],
};
