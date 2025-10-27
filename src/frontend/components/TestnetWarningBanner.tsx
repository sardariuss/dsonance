import { useState, useEffect } from "react";
import { HiOutlineExclamationTriangle, HiXMark } from "react-icons/hi2";

const STORAGE_KEY = "testnet-warning-dismissed";

const TestnetWarningBanner: React.FC = () => {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    // Check if the banner has been dismissed
    const dismissed = localStorage.getItem(STORAGE_KEY);
    if (!dismissed) {
      setIsVisible(true);
    }
  }, []);

  const handleDismiss = () => {
    localStorage.setItem(STORAGE_KEY, "true");
    setIsVisible(false);
  };

  if (!isVisible) {
    return null;
  }

  return (
    <div className="w-full bg-amber-50 dark:bg-amber-900/20 border-y border-amber-200 dark:border-amber-800">
      <div className="max-w-7xl mx-auto px-3 sm:px-4 py-2.5">
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-2 flex-1 min-w-0">
            <HiOutlineExclamationTriangle className="w-5 h-5 text-amber-600 dark:text-amber-400 flex-shrink-0" />
            <div className="flex-1 min-w-0">
              <p className="text-sm text-amber-900 dark:text-amber-100 text-center">
                <span className="font-semibold">Testnet tokens only:</span> Do not send real assets. All funds will be lost!
              </p>
            </div>
          </div>
          <button
            onClick={handleDismiss}
            className="flex-shrink-0 p-1 rounded-md hover:bg-amber-100 dark:hover:bg-amber-900/40 transition-colors"
            aria-label="Dismiss warning"
          >
            <HiXMark className="w-5 h-5 text-amber-600 dark:text-amber-400" />
          </button>
        </div>
      </div>
    </div>
  );
};

export default TestnetWarningBanner;
