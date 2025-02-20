import { protocolActor } from "../actors/ProtocolActor";
import { toCandid } from "../utils/conversions/yesnochoice";
import { useEffect, useState } from "react";
import { formatDuration } from "../utils/conversions/durationUnit";
import { DISSENT_EMOJI, DSONANCE_COIN_SYMBOL, LOCK_EMOJI } from "../constants";
import { BallotInfo } from "./types";
import { get_current } from "../utils/timeline";
import { v4 as uuidv4 } from 'uuid';
import { unwrapLock } from "../utils/conversions/ballot";
import { formatBalanceE8s } from "../utils/conversions/token";

interface PutBallotPreviewProps {
  vote_id: string;
  ballot: BallotInfo;
}

const PutBallotPreview: React.FC<PutBallotPreviewProps> = ({ vote_id, ballot }) => {

  const [debouncedBallot, setDebouncedBallot] = useState(ballot);

  const { data: preview, call: refreshPreview } = protocolActor.useQueryCall({
    functionName: "preview_ballot",
  });

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedBallot(ballot);
    }, 100); // Wait for 100ms before updating
  
    return () => clearTimeout(handler); // Cleanup if ballot changes before 100ms
  }, [ballot]);
  
  useEffect(() => {
    console.log("Refresh preview");
    refreshPreview([
      {
        ballot_id: uuidv4(),
        vote_id,
        from_subaccount: [],
        amount: debouncedBallot.amount,
        choice_type: { YES_NO: toCandid(debouncedBallot.choice) },
      },
    ]);
  }, [debouncedBallot]);

  // Check if preview is valid, otherwise default to "N/A"
  const isPreviewValid = preview && "ok" in preview;
  const defaultValue = "N/A";

  const previewData = isPreviewValid ? preview.ok.YES_NO : null;

  return (
    <div className="flex flex-row items-center space-x-6 justify-center">
      {[
        {
          label: "Mining reward",
          value: previewData
            ? formatBalanceE8s(
                BigInt(Math.trunc(previewData.contribution.current.data.pending)),
                DSONANCE_COIN_SYMBOL
              )
            : defaultValue,
        },
        {
          label: "APR (current)",
          value: previewData
            ? previewData.foresight.current.data.apr.current.toFixed(2) + "%"
            : defaultValue,
        },
        {
          label: "APR (potential)",
          value: previewData
            ? previewData.foresight.current.data.apr.potential.toFixed(2) + "%"
            : defaultValue,
        },
        {
          label: "Time left",
          value: isPreviewValid
            ? " ≥ " + formatDuration(get_current(unwrapLock(preview.ok).duration_ns).data)
            : defaultValue,
        },
      ].map(({ label, value }) => (
        <div key={label} className="grid grid-rows-2 justify-items-center min-w-max">
          <span className="text-sm text-gray-600 dark:text-gray-400 whitespace-nowrap">
            {label}
          </span>
          <span className="whitespace-nowrap">{value}</span>
        </div>
      ))}
    </div>
  );
};


export default PutBallotPreview;
