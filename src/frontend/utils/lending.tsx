
export const aprToApy = (rate: number, compoundingPerYear = 365 * 24 * 60 * 60): number =>{
  return Math.pow(1 + rate / compoundingPerYear, compoundingPerYear) - 1;
}

export const getHealthColor = (hf: number): string => {
  const font = "text-lg font-semibold";
  var textColor = "text-orange-500";
  if (hf < 1.5) textColor = "text-red-500";
  if (hf > 3.0) textColor = "text-green-500";
  return `${font} ${textColor} dark:${textColor}`;
};