

export const aprToApy = (rate: number, compoundingPerYear = 365 * 24 * 60 * 60): number =>{
  return Math.pow(1 + rate / compoundingPerYear, compoundingPerYear) - 1;
}

export const getHealthColor = (hf: number): string => {
  if (hf < 1.1) return "text-red-500 dark:text-red-500";
  if (hf > 3.0) return "text-green-500 dark:text-green-500";
  return "text-orange-500 dark:text-orange-500";
};