
export enum ChartType {
    EVP = "EVP",
    TVL = "TVL",
    Consensus = "Consensus",
};

interface ChartToggleProps {
    selected: ChartType;
    setSelected: (selected: ChartType) => void;
}

const ChartToggle: React.FC<ChartToggleProps> = ({ selected, setSelected }) => {

    return (
        <div className="flex flex-row space-x-0 sm:space-x-1 rounded ">
        {[ChartType.EVP, ChartType.TVL, ChartType.Consensus].map((chartType) => (
            <button
                className={`text-base h-8 px-2 justify-center items-center button-discrete
                    ${selected === chartType ? "dark:bg-slate-700 bg-slate-300" : ""}`}
                key={chartType}
                onClick={() => setSelected(chartType)}
            >
                {chartType} {/* Convert enum to string */}
            </button>
        ))}
        </div>
    );
};

export default ChartToggle;