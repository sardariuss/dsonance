import React from "react";

interface TabButtonProps {
  label: string,
  isCurrent: boolean,
  setIsCurrent: () => (void),
};

export const TabButton: React.FC<TabButtonProps> = ({ label, isCurrent, setIsCurrent }) => {

  return (
    <button 
      className={
        "w-full inline-block text-md xl:px-4 lg:px-3 sm:px-2 px-1 py-3 border-b-2 " 
        + (isCurrent ? "dark:text-white border-purple-700 font-semibold" : 
          "border-transparent text-gray-300 hover:text-black hover:border-gray-300 dark:hover:text-gray-300")
      } 
      type="button"
      role="tab"
      onClick={(e) => setIsCurrent() }>
        {label}
    </button>
  );

};