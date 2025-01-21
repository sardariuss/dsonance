module.exports = {
    darkMode: 'class', // TODO: remove once the white theme is implemented
	content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
    theme: {
        extend: {
            colors: {
                'slate-850' : '#172032',
                'brand-true' : 'rgb(7 227 68)',
                'brand-false' : 'rgb(3 181 253)',
            },
            fontFamily: {
                'acelon': ['Acelon', 'sans-serif'],
                'cafe': ['Cafe', 'sans-serif'],
            },
        },
    },
    plugins: [require('@tailwindcss/typography')],
};
