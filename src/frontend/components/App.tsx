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
  theme: "dark",
  setTheme: (theme) => console.warn("no theme provider"),
});

function App() {
  const [theme, setTheme] = useState<string>("dark");

  const rawSetTheme = (rawTheme: string) => {
    const root = window.document.documentElement;
    root.classList.remove(rawTheme === "dark" ? "light" : "dark");
    root.classList.add(rawTheme);
    window.localStorage.setItem("color-theme", rawTheme);
    setTheme(rawTheme);
  };

  if (typeof window !== "undefined") {
    useEffect(() => {
      // Use saved theme if any
      const initialTheme = window.localStorage.getItem("color-theme");
      if (initialTheme) {
        rawSetTheme(initialTheme);
        return;
      }

      // Fall back to system theme
      rawSetTheme(window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
    }, []);
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

function AppContent() {

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