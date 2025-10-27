import { toast } from 'sonner';

/**
 * Shows an error toast notification for actor call failures
 * @param message The error message to display
 * @param operation Optional operation name for better context (e.g., "Lock position", "Borrow")
 */
export const showErrorToast = (message: string, operation?: string) => {
  const title = operation ? `${operation} failed` : 'Operation failed';
  toast.error(title, {
    description: message,
    duration: 5000, // Show for 5 seconds
    dismissible: true, // Enable dismiss button
    closeButton: true, // Show explicit close button
  });
};

/**
 * Shows a success toast notification for successful operations
 * @param message The success message to display
 * @param operation Optional operation name for better context (e.g., "Lock position", "Borrow")
 */
export const showSuccessToast = (message: string, operation?: string) => {
  const title = operation ? `${operation} successful` : 'Operation successful';
  toast.success(title, {
    description: message,
    duration: 3000, // Show for 3 seconds
    dismissible: true, // Enable dismiss button
    closeButton: true, // Show explicit close button
  });
};

/**
 * Helper function to extract error message from various error formats
 * @param error The error object (can be string, Error, or actor result with .err property)
 * @returns A formatted error message string
 */
export const extractErrorMessage = (error: any): string => {
  if (typeof error === 'string') {
    return error;
  }
  
  if (error?.message) {
    return error.message;
  }
  
  if (error?.err) {
    return typeof error.err === 'string' ? error.err : error.err.toString();
  }
  
  if (error?.toString) {
    return error.toString();
  }
  
  return 'An unknown error occurred';
};