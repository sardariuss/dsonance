
export const createThumbnailUrl = (thumbnail: Uint8Array | number[]): string => {
  const byteArray = new Uint8Array(thumbnail);
  // A data URI will start with `data:image`, so we check for that.
  if (byteArray.length > 10 && new TextDecoder().decode(byteArray.slice(0, 10)).startsWith('data:image')) {
    // If it's a data URI, decode the whole array back to a string.
    return new TextDecoder().decode(byteArray);
  } else {
    // Otherwise, assume it's raw image data (like a PNG) and create a blob URL.
    const blob = new Blob([byteArray], { type: 'image/png' });
    return URL.createObjectURL(blob);
  }
};