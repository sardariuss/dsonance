import { useProtocolContext } from "./context/ProtocolContext";
import { Duration } from "@/declarations/protocol/protocol.did";
import { durationToNs } from "../utils/conversions/duration";
import { formatDuration } from "../utils/conversions/durationUnit";
import { DASHBOARD_CONTAINER, CONTENT_PANEL } from "../utils/styles";

const formatDurationValue = (duration: Duration): string => {
  const ns = durationToNs(duration);
  return formatDuration(ns);
};

const ProtocolPage = () => {
  const { parameters } = useProtocolContext();

  if (!parameters) {
    return (
      <div className="w-full sm:w-4/5 md:w-11/12 lg:w-5/6 xl:w-4/5 mx-auto px-3 pb-3">
        <div className="text-center text-gray-500 mt-8">Loading protocol parameters...</div>
      </div>
    );
  }

  const sections = [
    {
      title: "Resolution APY",
      description: "Parameters controlling positions' resolution APY",
      items: [
        {
          label: "Dissent Steepness",
          value: parameters.dissent_steepness.toFixed(2),
          description: "Controls how dissent affects resolution APY in foresight calculations."
        },
        {
          label: "Consent Steepness",
          value: parameters.consent_steepness.toFixed(2),
          description: "Controls how consent affects resolution APY in foresight calculations"
        },
        {
          label: "Age Coefficient",
          value: parameters.age_coefficient.toFixed(2),
          description: "Controls how age affects resolution APY in foresight calculations"
        },
        {
          label: "Max Age",
          value: formatDurationValue(parameters.max_age),
          description: "Maximum age considered in foresight calculations"
        }
      ]
    },
    {
      title: "Consensus",
      description: "Parameters controlling pool's consensus",
      items: [
        {
          label: "Positions' Half-Life",
          value: formatDurationValue(parameters.ballot_half_life),
          description: "Controls how much time shall affect positions' weight in the consensus"
        },
      ]
    },
    {
      title: "Lock Duration Scaling",
      description: "Parameters controlling how lock durations are calculated based on voting activity",
      items: [
        {
          label: "Multiplier (a)",
          value: parameters.duration_scaler.a.toLocaleString(),
          description: "Base multiplier for duration scaling formula"
        },
        {
          label: "Logarithmic Base (b)",
          value: parameters.duration_scaler.b.toFixed(2),
          description: "Controls the power law exponent (log₁₀(b)) in duration scaling"
        },
        {
          label: "Formula",
          value: "duration = a × hotness^(log₁₀(b))",
          description: "Lock duration computed based on voting hotness (locked USDT amount)"
        },
      ]
    },
    {
      title: "Price Oracle (TWAP)",
      description: "Time-weighted average price configuration for collateral valuation",
      items: [
        {
          label: "Window Duration",
          value: formatDurationValue(parameters.twap_config.window_duration),
          description: "Time window for TWAP calculation"
        },
        {
          label: "Max Observations",
          value: parameters.twap_config.max_observations.toString(),
          description: "Maximum number of price observations to store"
        },
      ]
    },
    {
      title: "System Configuration",
      description: "Core system timing and clock parameters",
      items: [
        {
          label: "Clock Type",
          value: "SIMULATED" in parameters.clock ? "Simulated" : "Real-time",
          description: "Type of clock used by the protocol"
        },
        ...("SIMULATED" in parameters.clock ? [
          {
            label: "Time Dilation Factor",
            value: parameters.clock.SIMULATED.dilation_factor.toFixed(1) + "x",
            description: "Time acceleration factor for testing (100x = 1 day ≈ 14.4 minutes)"
          }
        ] : []),
      ]
    },
    {
      title: "Miscellaneous",
      description: "Miscellaneous protocol parameters",
      items: [
        {
          label: "Minimum Position Amount",
          value: (Number(parameters.minimum_ballot_amount) / 1_000_000).toLocaleString() + " USDT",
          description: "Minimum amount required to lock a position"
        },
      ]
    },
  ];

  return (
    <div className="w-full sm:w-4/5 md:w-11/12 lg:w-5/6 xl:w-4/5 mx-auto px-3 pb-3 my-6">

      <div className={DASHBOARD_CONTAINER}>
        {sections.map((section, idx) => (
          <div key={idx} className={CONTENT_PANEL}>
            <div className="mb-4">
              <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-1">
                {section.title}
              </h2>
              <p className="text-sm text-gray-600 dark:text-gray-400">
                {section.description}
              </p>
            </div>

            <div className="space-y-4">
              {section.items.map((item, itemIdx) => (
                <div
                  key={itemIdx}
                  className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-2 pb-4 border-b border-gray-200 dark:border-gray-700 last:border-b-0 last:pb-0"
                >
                  <div className="flex-1">
                    <div className="font-medium text-gray-900 dark:text-white">
                      {item.label}
                    </div>
                    <div className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                      {item.description}
                    </div>
                  </div>
                  <div className="font-mono text-base text-gray-900 dark:text-white font-semibold sm:text-right whitespace-nowrap">
                    {item.value}
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default ProtocolPage;
