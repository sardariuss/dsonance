import { useState, useEffect, useCallback } from 'react';
import { useActors } from '../common/ActorsContext';
import { ActorMethod, ActorSubclass } from '@dfinity/agent';
import { _SERVICE as TwvLedger } from "../../../declarations/twv_ledger/twv_ledger.did";

// Type utilities to extract function signatures from ActorMethod
type TwvLedgerMethods = keyof TwvLedger;
type ExtractArgs<T> = T extends ActorMethod<infer P, any> ? P : never;
type ExtractReturn<T> = T extends ActorMethod<any, infer R> ? R : never;

interface UseQueryCallOptions<T extends TwvLedgerMethods> {
  functionName: T;
  args?: ExtractArgs<TwvLedger[T]>;
  onSuccess?: (data: ExtractReturn<TwvLedger[T]>) => void;
  onError?: (error: any) => void;
}

const useQueryCall = <T extends TwvLedgerMethods>(options: UseQueryCallOptions<T>, actor: ActorSubclass<TwvLedger> | undefined) => {

  const [data, setData] = useState<ExtractReturn<TwvLedger[T]> | undefined>(undefined);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  const call = useCallback(
    async (callArgs?: ExtractArgs<TwvLedger[T]>): Promise<ExtractReturn<TwvLedger[T]> | undefined> => {
      if (!actor) return undefined;

      setLoading(true);
      setError(null);
      
      try {
        const args = callArgs || options.args || [];
        const result = await (actor as any)[options.functionName](...args);
        setData(result);
        options.onSuccess?.(result);
        return result;
      } catch (err) {
        setError(err);
        options.onError?.(err);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [actor, options.functionName, options.args, options.onSuccess, options.onError]
  );

  // Helper function to safely serialize args including BigInt
  const serializeArgs = (args: any) => {
    try {
      return JSON.stringify(args, (_, value) =>
        typeof value === 'bigint' ? value.toString() + 'n' : value
      );
    } catch {
      // Fallback for circular references or other issues
      return String(args);
    }
  };

  // Auto-call if args are provided
  useEffect(() => {
    if (options.args !== undefined) {
      call();
    } else {
      // Reset data if no args
      setData(undefined);
    }
  }, [actor, options.functionName, serializeArgs(options.args)]);

  return { data, loading, error, call };
};

interface UseUpdateCallOptions<T extends TwvLedgerMethods> {
  functionName: T;
  onSuccess?: (data: ExtractReturn<TwvLedger[T]>) => void;
  onError?: (error: any) => void;
}

const useUpdateCall = <T extends TwvLedgerMethods>(options: UseUpdateCallOptions<T>, actor: ActorSubclass<TwvLedger> | undefined) => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  const call = useCallback(
    async (args: ExtractArgs<TwvLedger[T]> = [] as any): Promise<ExtractReturn<TwvLedger[T]> | undefined> => {

      if (!actor) return undefined;

      setLoading(true);
      setError(null);
      
      try {
        const result = await (actor as any)[options.functionName](...args);
        options.onSuccess?.(result);
        return result;
      } catch (err) {
        setError(err);
        options.onError?.(err);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [actor, options.functionName, options.onSuccess, options.onError]
  );

  return { call, loading, error };
};

export type { TwvLedger };

const useUnauthQueryCall = <T extends TwvLedgerMethods>(options: UseQueryCallOptions<T>) => {
  const { unauthenticated } = useActors();
  return useQueryCall(options, unauthenticated?.twvLedger as any);
}

const useAuthQueryCall = <T extends TwvLedgerMethods>(options: UseQueryCallOptions<T>) => {
  const { authenticated } = useActors();
  return useQueryCall(options, authenticated?.twvLedger as any);
}

const useUnauthUpdateCall = <T extends TwvLedgerMethods>(options: UseUpdateCallOptions<T>) => {
  const { unauthenticated } = useActors();
      return useUpdateCall(options, unauthenticated?.twvLedger as any);
}

const useAuthUpdateCall = <T extends TwvLedgerMethods>(options: UseUpdateCallOptions<T>) => {
  const { authenticated } = useActors();
  return useUpdateCall(options, authenticated?.twvLedger as any);
}

// Compatibility layer that mimics the ic-reactor twvLedgerActor API with full type safety
export const twvLedgerActor = {
  unauthenticated: {
    useQueryCall: useUnauthQueryCall,
    useUpdateCall: useUnauthUpdateCall
  },
  authenticated: {
    useQueryCall: useAuthQueryCall,
    useUpdateCall: useAuthUpdateCall
  }
};
