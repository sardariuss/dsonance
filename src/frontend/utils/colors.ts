
// Utility to blend two colors based on a ratio (0 to 1)
export const blendColors = (color1: string, color2: string, ratio: number) => {
  const hexToRgb = (hex: string) =>
    hex
      .replace(/^#/, "")
      .match(/.{2}/g)!
      .map((x) => parseInt(x, 16));
  const rgbToHex = (rgb: number[]) =>
    `#${rgb.map((x) => x.toString(16).padStart(2, "0")).join("")}`;

  const rgb1 = hexToRgb(color1);
  const rgb2 = hexToRgb(color2);
  const blended = rgb1.map((c1, i) => Math.round(c1 * ratio + rgb2[i] * (1 - ratio)));
  return rgbToHex(blended);
};
