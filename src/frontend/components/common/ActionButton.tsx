import React from "react";

interface ActionButtonProps {
  title: string;
  onClick?: () => void;
  disabled?: boolean;
  loading?: boolean;
  className?: string;
}

const ActionButton: React.FC<ActionButtonProps> = ({
  title,
  onClick,
  disabled = false,
  loading = false,
  className = "",
}) => {
  return (
    <button
      className={`px-4 py-2 font-medium rounded-md transition-colors shadow-sm ${
        disabled
          ? "bg-gray-300 dark:bg-gray-600 text-gray-500 dark:text-gray-400 cursor-not-allowed opacity-50"
          : "bg-blue-500 hover:bg-blue-600 text-white"
      } ${className}`}
      onClick={onClick}
      disabled={disabled || loading}
    >
      {loading ? "Loading..." : title}
    </button>
  );
};

export default ActionButton;
