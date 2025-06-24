
interface DualLabel {
  top: string;
  topClassName?: string;
  bottom: string;
  bottomClassName?: string;
};

const DualLabel: React.FC<DualLabel> = ({ top, topClassName, bottom, bottomClassName }) => {

  return (
    <div className="grid grid-rows-[2fr_3fr] place-items-start">
      <span className={`text-gray-500 dark:text-gray-400 text-sm ${topClassName}`}>{top}</span>
      <span className={`text-gray-700 dark:text-white text-lg font-semibold ${bottomClassName}`}>{bottom}</span>
    </div>
  );
}

export default DualLabel;