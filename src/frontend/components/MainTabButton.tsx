
type Properties = {
    label: string,
    isCurrent: boolean,
    setIsCurrent: () => (void),
  };
  
  export const MainTabButton = ({label, isCurrent, setIsCurrent}: Properties) => {
  
    return (
      <button 
        className={
          "inline-block py-4 w-full border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 rounded " 
          + (isCurrent ? "dark:text-white font-bold " : 
            "hover:text-gray-600 hover:border-gray-300 dark:hover:text-gray-300")
        } 
        type="button"
        role="tab"
        onClick={(e) => setIsCurrent()}>
          {label}
      </button>
    );
  
  };