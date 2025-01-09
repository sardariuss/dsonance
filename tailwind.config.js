module.exports = {
	content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
    theme: {
        extend: {
            colors: {
                'slate-850' : '#172032',
                'brand-false' : 'rgb(254 87 39)',
                'brand-true' : 'rgb(13 200 79)',
            },
            fontFamily: {
                'acelon': ['Acelon', 'sans-serif'],
            },
        },
    },
    plugins: [require('@tailwindcss/typography')],
};
