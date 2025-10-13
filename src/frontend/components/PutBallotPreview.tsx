import { formatDuration } from "../utils/conversions/durationUnit";
import { get_current } from "../utils/timeline";
import { unwrapLock } from "../utils/conversions/ballot";
import { SBallot } from "@/declarations/protocol/protocol.did";
import { aprToApy } from "../utils/lending";
import { useMemo, useState } from "react";
import { HiMiniArrowTrendingUp, HiMiniTrophy, HiOutlineArrowTrendingUp, HiOutlineClock, HiTrophy } from "react-icons/hi2";
import { useMiningRatesContext } from "./context/MiningRatesContext";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";
import { getTokenLogo, getTokenDecimals } from "../utils/metadata";

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

  const { participationLedger } = useFungibleLedgerContext();
  const { miningRates } = useMiningRatesContext();

  const displayedPreview = useSupplyImpact ? ballotPreview : ballotPreviewWithoutImpact;

  const twvLogo = useMemo(() => {
    return getTokenLogo(participationLedger.metadata);
  }, [participationLedger.metadata]);

  // Return null if no preview is available
  if (!displayedPreview) {
    return null;
  }

  const handleSupplyImpactToggle = (enabled: boolean) => {
    setUseSupplyImpact(enabled);
    onToggleSupplyImpact?.(enabled);
  };

  const miningRewardsPerDay = miningRates && displayedPreview.amount > 0n
    ? miningRates.calculatePreviewRates({
        additionalSupply: displayedPreview.amount
      }).previewSupplyRatePerToken * Number(displayedPreview.amount)
    : 0;

  const basicFields = [
    {
      label: "Min duration",
      icon: <HiOutlineClock className="w-5 h-5" />,
      value: formatDuration(get_current(unwrapLock(displayedPreview).duration_ns).data),
    },
    {
      label: "Win APY",
      icon: <HiMiniArrowTrendingUp className="w-5 h-5" />,
      value: (aprToApy(displayedPreview.foresight.apr.potential) * 100).toFixed(2) + "%",
    },
    {
      label: "Mining rewards",
      icon: twvLogo ? <img src={twvLogo} alt="TWV" className="w-5 h-5" /> : <HiMiniTrophy className="w-5 h-5" />,
      value: miningRates ? `${participationLedger.formatAmount(miningRewardsPerDay)} TWV/day` : "—",
    },
  ];

  const detailedFields = [
    { label: "Dissent", 
      icon: <HiOutlineArrowTrendingUp className="w-5 h-5" />,
      value: displayedPreview.dissent.toFixed(3) },
    {
      label: "APY (current)",
      icon: <HiOutlineArrowTrendingUp className="w-5 h-5" />,
      value: (aprToApy(displayedPreview.foresight.apr.current) * 100).toFixed(2) + "%",
    },
  ];

  const fieldsToShow = showDetails ? [...basicFields, ...detailedFields] : basicFields;

  return (
    <div className="w-full">
      <div className="flex flex-col space-y-3 w-full">
        {fieldsToShow.map(({ label, icon, value }) => (
          <div key={label} className="flex justify-between items-center w-full rounded-lg">
            <div className="flex items-center gap-2">
              <span className="text-gray-600 dark:text-gray-400">{icon}</span>
              <span className="text-base text-gray-700 dark:text-gray-300 whitespace-nowrap">{label}</span>
            </div>
            <span className="whitespace-nowrap text-xl text-gray-900 dark:text-white">{value}</span>
          </div>
        ))}
      </div>

      {/* TODO: needs rework - show details functionality disabled for now */}
      <div className="flex justify-center items-center" style={{ display: 'none' }}>
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
