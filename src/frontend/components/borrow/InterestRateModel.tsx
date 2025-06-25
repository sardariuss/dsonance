
interface InterestRateModelProps {
  utilizationRate: number;
}

const InterestRateModel: React.FC<InterestRateModelProps> = ({
  utilizationRate
}) => {

  return (
    <div className="flex flex-col text-white px-6 max-w-3xl w-full space-y-6">
      <div className="grid grid-rows-3 gap-1 h-full">
        <span className="text-sm text-gray-400">Utilization rate</span>
        <span className="text-lg font-bold">{(100 * utilizationRate).toFixed(2)}%</span>
      </div>         
    </div>
  )
};

export default InterestRateModel;
