import { useEffect, useState } from "react";
import { Result_1, Result_2 } from "@/declarations/protocol/protocol.did";

type OperationResult = Result_1 | Result_2;

interface HealthPreviewArguments {
  amount: bigint;
  previewOperation: (amount: bigint) => Promise<OperationResult | undefined>;
}

export const useBorrowOperationPreview = ({ amount, previewOperation }: HealthPreviewArguments) => {

  const [debouncedAmount, setDebouncedAmount] = useState(amount);
  const [preview, setPreview] = useState<OperationResult | undefined>(undefined);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const handler = setTimeout(() => setDebouncedAmount(amount), 100);
    return () => clearTimeout(handler);
  }, [amount]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);

    previewOperation(debouncedAmount)
      .then((result) => {
        if (!cancelled) {
          if (result && "ok" in result) {
            setPreview(result);
          } else {
            setPreview(undefined);
          }
        }
      })
      .catch((err) => {
        if (!cancelled) setPreview(undefined);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [debouncedAmount]);

  return { loading, preview };
};

export default useBorrowOperationPreview;