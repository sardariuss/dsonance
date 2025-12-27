import { LimitOrder } from "@/declarations/protocol/protocol.did";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";

interface OrderDataRowProps {
  order: LimitOrder;
}

const OrderDataRow = ({ order }: OrderDataRowProps) => {
  const { supplyLedger: { formatAmountUsd } } = useFungibleLedgerContext();

  return (
    <div className="grid grid-cols-2 gap-2 sm:gap-4 items-center py-2 h-[60px] sm:h-[68px]">
      {/* Limit Consensus */}
      <div className="w-full text-right flex items-center justify-end">
        <span className="font-semibold text-sm">{(order.limit_consensus * 100).toFixed(1)}%</span>
      </div>

      {/* Amount */}
      <div className="w-full flex flex-col items-end text-right justify-center">
        <span className="font-semibold text-sm">
          {formatAmountUsd(BigInt(Math.floor(order.amount)))}
        </span>
      </div>
    </div>
  );
};

export default OrderDataRow;
