import { useEffect, useState } from "react";
import { Result_1 } from "@/declarations/protocol/protocol.did";

interface HealthPreviewArguments {
  amount: bigint;
  previewOperation: (amount: bigint) => Promise<Result_1 | undefined>;
}

export const useBorrowOperationPreview = ({ amount, previewOperation }: HealthPreviewArguments) => {
  
  const [debouncedAmount, setDebouncedAmount] = useState(amount);
  const [preview, setPreview] = useState<Result_1 | undefined>(undefined);
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