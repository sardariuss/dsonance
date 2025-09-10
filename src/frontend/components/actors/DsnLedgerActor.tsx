import { useState, useEffect } from 'react';
import { useActors } from '../common/ActorsContext';
import { ActorMethod, ActorSubclass } from '@dfinity/agent';
import { _SERVICE as DsnLedger } from "../../../declarations/dsn_ledger/dsn_ledger.did";

// Type utilities to extract function signatures from ActorMethod
type DsnLedgerMethods = keyof DsnLedger;
type ExtractArgs<T> = T extends ActorMethod<infer P, any> ? P : never;
type ExtractReturn<T> = T extends ActorMethod<any, infer R> ? R : never;

interface UseQueryCallOptions<T extends DsnLedgerMethods> {
  functionName: T;
  args?: ExtractArgs<DsnLedger[T]>;
  onSuccess?: (data: ExtractReturn<DsnLedger[T]>) => void;
  onError?: (error: any) => void;
}

const useQueryCall = <T extends DsnLedgerMethods>(options: UseQueryCallOptions<T>, actor: ActorSubclass<DsnLedger> | undefined) => {

  const [data, setData] = useState<ExtractReturn<DsnLedger[T]> | undefined>(undefined);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  const call = async (callArgs?: ExtractArgs<DsnLedger[T]>): Promise<ExtractReturn<DsnLedger[T]> | undefined> => {

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
  };

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
    }
  }, [actor, options.functionName, serializeArgs(options.args)]);

  return { data, loading, error, call };
};

interface UseUpdateCallOptions<T extends DsnLedgerMethods> {
  functionName: T;
  onSuccess?: (data: ExtractReturn<DsnLedger[T]>) => void;
  onError?: (error: any) => void;
}

const useUpdateCall = <T extends DsnLedgerMethods>(options: UseUpdateCallOptions<T>, actor: ActorSubclass<DsnLedger> | undefined) => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  const call = async (args: ExtractArgs<DsnLedger[T]> = [] as any): Promise<ExtractReturn<DsnLedger[T]> | undefined> => {

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
  };

  return { call, loading, error };
};

export type { DsnLedger };

const useUnauthQueryCall = <T extends DsnLedgerMethods>(options: UseQueryCallOptions<T>) => {
  const { unauthenticated } = useActors();
  return useQueryCall(options, unauthenticated?.dsnLedger as any);
}

const useAuthQueryCall = <T extends DsnLedgerMethods>(options: UseQueryCallOptions<T>) => {
  const { authenticated } = useActors();
  return useQueryCall(options, authenticated?.dsnLedger as any);
}

const useUnauthUpdateCall = <T extends DsnLedgerMethods>(options: UseUpdateCallOptions<T>) => {
  const { unauthenticated } = useActors();
      return useUpdateCall(options, unauthenticated?.dsnLedger as any);
}

const useAuthUpdateCall = <T extends DsnLedgerMethods>(options: UseUpdateCallOptions<T>) => {
  const { authenticated } = useActors();
  return useUpdateCall(options, authenticated?.dsnLedger as any);
}

// Compatibility layer that mimics the ic-reactor dsnLedgerActor API with full type safety
export const dsnLedgerActor = {
  unauthenticated: {
    useQueryCall: useUnauthQueryCall,
    useUpdateCall: useUnauthUpdateCall
  },
  authenticated: {
    useQueryCall: useAuthQueryCall,
    useUpdateCall: useAuthUpdateCall
  }
};
