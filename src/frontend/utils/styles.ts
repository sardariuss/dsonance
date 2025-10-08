/**
 * Common CSS class utilities for consistent styling across components
 */

/**
 * Content panel style with border, shadow, and responsive padding
 * Used for dashboard panels, forms, cards, and other primary content areas
 */
export const CONTENT_PANEL = "bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700";

/**
 * Dashboard outer container with consistent spacing and layout
 */
export const DASHBOARD_CONTAINER = "flex flex-col space-y-4";

/**
 * Stats overview section with token placement and metrics
 */
export const STATS_OVERVIEW_CONTAINER = "flex flex-col sm:flex-row text-center text-gray-800 dark:text-gray-200 px-3 sm:px-6 gap-4 lg:gap-8 items-center self-center";

/**
 * Vertical divider for separating sections (hidden on smaller screens)
 */
export const VERTICAL_DIVIDER = "hidden lg:block border-r border-slate-300 dark:border-slate-700 h-full";

/**
 * Metrics wrapper with responsive layout
 */
export const METRICS_WRAPPER = "flex flex-wrap items-center justify-center gap-2 justify-center px-3 sm:px-6 gap-4 lg:gap-8 lg:justify-around";