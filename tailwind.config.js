module.exports = {
    darkMode: 'class', // Enables class-based dark mode
	content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
    theme: {
        extend: {
            colors: {
                'slate-850' : '#172032',
                'brand-true' : 'rgb(7 227 68)',
                'brand-false' : 'rgb(3 181 253)',
                'brand-line': '#073a59',
                'brand-white': '#ebfcf6',
            },
            fontFamily: {
                'acelon': ['Acelon', 'sans-serif'],
                'cafe': ['Cafe', 'sans-serif'],
            },
        },
    },
    plugins: [require('@tailwindcss/typography')],
};
