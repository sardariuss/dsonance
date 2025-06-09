import { formatDuration } from "../utils/conversions/durationUnit";
import { get_current } from "../utils/timeline";
import { unwrapLock } from "../utils/conversions/ballot";
import { SBallot } from "@/declarations/protocol/protocol.did";

interface PutBallotPreviewProps {
  ballotPreview: SBallot | undefined;
}

const PutBallotPreview: React.FC<PutBallotPreviewProps> = ({ ballotPreview }) => {
  
  const defaultValue = "N/A";

  return (
    <div className="grid grid-cols-[repeat(auto-fit,minmax(100px,1fr))] gap-x-6 gap-y-2 justify-center w-full">
      <div className="flex min-w-[100px] items-center justify-center text-base font-semibold">
        Preview:
      </div>
      {[
        { label: "Dissent", value: ballotPreview ? ballotPreview.dissent.toFixed(3) : defaultValue },
        {
          label: "APR (current)",
          value: ballotPreview ? ballotPreview.foresight.current.data.apr.current.toFixed(2) + "%" : defaultValue,
        },
        {
          label: "APR (potential)",
          value: ballotPreview ? ballotPreview.foresight.current.data.apr.potential.toFixed(2) + "%" : defaultValue,
        },
        // @int: DSN minted temporarily disabled
        //{
          //label: "Mining reward",
          //value: ballotPreview ? formatBalanceE8s(BigInt(Math.trunc(0)), DSONANCE_COIN_SYMBOL, 0) : defaultValue,
        //},
        {
          label: "Time left",
          value: ballotPreview ?
            " ≥ " + formatDuration(get_current(unwrapLock(ballotPreview).duration_ns).data)
            : defaultValue,
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
