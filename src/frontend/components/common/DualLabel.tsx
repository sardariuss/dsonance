
interface DualLabel {
  top: string;
  topClassName?: string;
  bottom: string;
  bottomClassName?: string;
};

const DualLabel: React.FC<DualLabel> = ({ top, topClassName, bottom, bottomClassName }) => {

  return (
    <div className="grid grid-rows-[2fr_3fr] place-items-start">
      <span className={`${topClassName ?? "text-gray-500 dark:text-gray-400 text-sm"}`}>{top}</span>
      <span className={`${bottomClassName ?? "text-gray-700 dark:text-white text-lg font-semibold"}`}>{bottom}</span>
    </div>
  );
}

export default DualLabel;