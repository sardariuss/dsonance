import { useState, useEffect, useRef } from "react";

interface ContainerSize {
  width: number;
  height: number;
}

/// Custom hook to get the size of a container
/// and update it on resize events.
/// @param widthOffset - Optional offset to subtract from the width
/// @param heightOffset - Optional offset to subtract from the height
/// @returns An object containing the container size and a ref to the container
export function useContainerSize({
  widthOffset = 20,
  heightOffset = 0,
}: { widthOffset?: number; heightOffset?: number } = {}) {
  const [containerSize, setContainerSize] = useState<ContainerSize | undefined>(undefined);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const updateSize = () => {
      if (containerRef.current) {
        setContainerSize({
          width: containerRef.current.offsetWidth - widthOffset,
          height: containerRef.current.offsetHeight - heightOffset,
        });
      }
    };

    updateSize(); // Initial size

    const observer = new ResizeObserver(() => {
      updateSize();
    });

    if (containerRef.current) {
      observer.observe(containerRef.current);
    }

    return () => {
      observer.disconnect();
    };
  }, [widthOffset, heightOffset]);

  return { containerSize, containerRef };
}
