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
        "w-full inline-block text-lg border-b-2 font-semibold " 
        + (isCurrent ? "border-purple-700 text-black dark:text-white" : 
          "border-transparent hover:border-gray-300 text-gray-400 dark:text-gray-600")
      } 
      type="button"
      role="tab"
      onClick={(e) => setIsCurrent() }>
        {label}
    </button>
  );

};