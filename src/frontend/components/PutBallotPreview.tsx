import { formatDuration } from "../utils/conversions/durationUnit";
import { get_current } from "../utils/timeline";
import { unwrapLock } from "../utils/conversions/ballot";
import { SBallot } from "@/declarations/protocol/protocol.did";
import { aprToApy } from "../utils/lending";

interface PutBallotPreviewProps {
  ballotPreview: SBallot | undefined;
}

const PutBallotPreview: React.FC<PutBallotPreviewProps> = ({ ballotPreview }) => {
  
  const defaultValue = "N/A";

  return (
    <div className="grid grid-cols-[repeat(auto-fit,minmax(150px,1fr))] gap-x-6 gap-y-2 justify-center w-full">
      {[
        { label: "Dissent", value: ballotPreview ? ballotPreview.dissent.toFixed(3) : defaultValue },
        {
          label: "Time left",
          value: ballotPreview ?
            " ≥ " + formatDuration(get_current(unwrapLock(ballotPreview).duration_ns).data)
            : defaultValue,
        },
        {
          label: "APY (current)",
          value: ballotPreview ? (aprToApy(ballotPreview.foresight.current.data.apr.current) * 100).toFixed(2) + "%" : defaultValue,
        },
        {
          label: "APY (potential)",
          value: ballotPreview ? (aprToApy(ballotPreview.foresight.current.data.apr.potential) * 100).toFixed(2) + "%" : defaultValue,
        },
      ].map(({ label, value }) => (
        <div key={label} className="grid grid-rows-2 justify-items-center min-w-[100px]">
          <span className="text-sm text-gray-600 dark:text-gray-400 whitespace-nowrap">{label}</span>
          <span className="whitespace-nowrap">{value}</span>
        </div>
      ))}
    </div>
  );
};

export default PutBallotPreview;
