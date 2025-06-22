
interface DualLabel {
  top: string;
  bottom: string;
};

const DualLabel: React.FC<DualLabel> = ({ top, bottom }) => {

  return (
    <div className="grid grid-rows-[2fr_3fr] place-items-start">
      <span className="text-gray-500 dark:text-gray-400 text-sm">{top}</span>
      <span className="text-gray-700 dark:text-white text-lg font-semibold">{bottom}</span>
    </div>
  );
}

export default DualLabel;