import { useContext } from "react";
import { ThemeContext } from "./App";
import { MdOutlineDarkMode, MdOutlineLightMode } from "react-icons/md";

const ThemeToggle = () => {

    const { theme, setTheme } = useContext(ThemeContext);
  
    const toggleTheme = () => {
      setTheme(theme === "dark" ? "light" : "dark");
    };
  
    return (
      <button
        id="theme-toggle"
        type="button"
        className="h-10 w-10 rounded-full bg-white p-2 text-xl text-black dark:bg-white/10 dark:text-white"
        onClick={toggleTheme}
      >
        {theme === "dark" ? (
          <MdOutlineDarkMode size={22} />
        ) : (
          <MdOutlineLightMode size={22} />
        )}
      </button>
    );
};

  
export default ThemeToggle;