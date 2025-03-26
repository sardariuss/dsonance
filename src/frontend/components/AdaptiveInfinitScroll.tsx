import { useRef, useState, useEffect } from "react";
import InfiniteScroll, { Props } from "react-infinite-scroll-component";

const AdaptiveInfiniteScroll: React.FC<Props> = ({ className, style, ...props }) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState<number>(0);

  useEffect(() => {
    const updateWidth = () => {
      if (containerRef.current) {
        setWidth(containerRef.current.offsetWidth);
      }
    };

    updateWidth(); // Set initial width
    window.addEventListener("resize", updateWidth);

    return () => window.removeEventListener("resize", updateWidth);
  }, []);

  return (
    <div ref={containerRef} className="w-full">
      <InfiniteScroll
        {...props}
        className={`w-full ${className}`}
        style={{ ...style, width: `${width}px`, height: "auto", overflow: "visible" }}
      />
    </div>
  );
};

export default AdaptiveInfiniteScroll;
