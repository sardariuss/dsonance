import { formatDuration } from "../utils/conversions/durationUnit";
import { get_current } from "../utils/timeline";
import { unwrapLock } from "../utils/conversions/ballot";
import { SBallot } from "@/declarations/protocol/protocol.did";
import { aprToApy } from "../utils/lending";
import { useState } from "react";

interface PutBallotPreviewProps {
  ballotPreview: SBallot | undefined;
  ballotPreviewWithoutImpact?: SBallot | undefined;
  onToggleSupplyImpact?: (enabled: boolean) => void;
}

const PutBallotPreview: React.FC<PutBallotPreviewProps> = ({
  ballotPreview,
  ballotPreviewWithoutImpact,
  onToggleSupplyImpact
}) => {
  const [showDetails, setShowDetails] = useState(false);
  const [useSupplyImpact, setUseSupplyImpact] = useState(true);

  const defaultValue = "N/A";
  const displayedPreview = useSupplyImpact ? ballotPreview : ballotPreviewWithoutImpact;

  const handleSupplyImpactToggle = (enabled: boolean) => {
    setUseSupplyImpact(enabled);
    onToggleSupplyImpact?.(enabled);
  };

  const basicFields = [
    {
      label: "Time left",
      value: displayedPreview ?
        " ≥ " + formatDuration(get_current(unwrapLock(displayedPreview).duration_ns).data)
        : defaultValue,
    },
    {
      label: "APY (potential)",
      value: displayedPreview ? (aprToApy(displayedPreview.foresight.apr.potential) * 100).toFixed(2) + "%" : defaultValue,
    },
  ];

  const detailedFields = [
    { label: "Dissent", value: displayedPreview ? displayedPreview.dissent.toFixed(3) : defaultValue },
    {
      label: "APY (current)",
      value: displayedPreview ? (aprToApy(displayedPreview.foresight.apr.current) * 100).toFixed(2) + "%" : defaultValue,
    },
  ];

  const fieldsToShow = showDetails ? [...basicFields, ...detailedFields] : basicFields;

  return (
    <div className="w-full">
      <div className="grid grid-cols-[repeat(auto-fit,minmax(150px,1fr))] gap-x-6 gap-y-2 justify-center w-full">
        {fieldsToShow.map(({ label, value }) => (
          <div key={label} className="grid grid-rows-2 justify-items-center min-w-[100px]">
            <span className="text-sm text-gray-600 dark:text-gray-400 whitespace-nowrap">{label}</span>
            <span className="whitespace-nowrap">{value}</span>
          </div>
        ))}
      </div>

      <div className="flex justify-center items-center gap-4 mt-4">
        <button
          onClick={() => setShowDetails(!showDetails)}
          className="text-sm text-blue-600 dark:text-blue-400 hover:underline"
        >
          {showDetails ? 'Hide Details' : 'Show Details'}
        </button>

        {showDetails && ballotPreviewWithoutImpact && (
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={useSupplyImpact}
              onChange={(e) => handleSupplyImpactToggle(e.target.checked)}
              className="rounded"
            />
            Include supply APY impact
          </label>
        )}
      </div>
    </div>
  );
};

export default PutBallotPreview;
