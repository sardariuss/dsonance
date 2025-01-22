import Header from "./Header";
import Footer from "./Footer";
import { createContext, useState, useEffect } from "react";
import { BrowserRouter } from "react-router-dom";

import Router from "../router/Router";

const originalConsoleError = console.error;

console.error = (...args) => {
  // Ignore nivo warnings: https://github.com/plouc/nivo/issues/2612
  if (typeof args[2] === 'string' && args[2].includes('The prop `legendOffsetX` is marked as required')) {
    return;
  }
  if (typeof args[2] === 'string' && args[2].includes('The prop `legendOffsetY` is marked as required')) {
    return;
  }
  originalConsoleError(...args);
};

interface ThemeContextProps {
  theme: string;
  setTheme: (theme: string) => void;
}

export const ThemeContext = createContext<ThemeContextProps>({
  theme: "light",
  setTheme: (theme) => console.warn("no theme provider"),
});

function App() {
  const [theme, setTheme] = useState("dark");

  const rawSetTheme = (rawTheme: string) => {
    const root = window.document.documentElement;
    const isDark = rawTheme === "dark";

    root.classList.remove(isDark ? "light" : "dark");
    root.classList.add(rawTheme);
    setTheme(rawTheme);
  };

  if (typeof window !== "undefined") {
    useEffect(() => {
      const initialTheme = window.localStorage.getItem("color-theme");
      window.matchMedia("(prefers-color-scheme: dark)").matches && !initialTheme
        ? rawSetTheme("dark")
        : rawSetTheme(initialTheme || "light");
    }, []);

    useEffect(() => {
      window.localStorage.setItem("color-theme", theme);
    }, [theme]);
  }

  return (
    <ThemeContext.Provider value={{ theme, setTheme: rawSetTheme }}>
      <div className="flex h-screen w-full flex-col sm:flex-row">
        <BrowserRouter>
          <AppContent />
        </BrowserRouter>
      </div>
    </ThemeContext.Provider>
  );
}

const MobileWarning = () => (
  <div className="flex flex-col min-h-screen w-full bg-slate-100 dark:bg-slate-900 dark:border-gray-700 border-gray-300 dark:text-white text-black items-center justify-center space-y-10">
    <div className="flex items-baseline">
      <span className="text-5xl font-acelon whitespace-nowrap drop-shadow-lg shadow-white font-bold text-slate-800">
        RESONANCE
      </span>
      <span className="text-8xl font-cafe whitespace-nowrap drop-shadow shadow-blue-800 neon-effect">
        .defi
      </span>
    </div>
    <div className="text-5xl">🚧</div>
    <div className="flex flex-col items-center text-xl text-center">
      <span>Sorry!</span>
      <span>This website is not available on mobile devices yet.</span>
    </div>
  </div>
);

function AppContent() {

  const isMobile = /Mobi|Android/i.test(navigator.userAgent);

  if (isMobile) {
    return <MobileWarning />;
  }

  return (
    <>
      <div className="flex flex-col min-h-screen w-full bg-slate-100 dark:bg-slate-900 dark:border-gray-700 border-gray-300 text-gray-800 dark:text-white justify-between">
        <div className="flex flex-col w-full flex-grow items-center bg-slate-100 dark:bg-slate-900">
          <Header/>
          <Router/>
        </div>
        <Footer/>
      </div>
    </>
  );
}

export default App;