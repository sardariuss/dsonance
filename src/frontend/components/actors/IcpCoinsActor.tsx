import { useState, useEffect, useCallback } from 'react';
import { useActors } from '../common/ActorsContext';
import { ActorMethod, ActorSubclass } from '@dfinity/agent';
import { _SERVICE as IcpCoins } from "../../../declarations/icp_coins/icp_coins.did";

// Type utilities to extract function signatures from ActorMethod
type IcpCoinsMethods = keyof IcpCoins;
type ExtractArgs<T> = T extends ActorMethod<infer P, any> ? P : never;
type ExtractReturn<T> = T extends ActorMethod<any, infer R> ? R : never;

interface UseQueryCallOptions<T extends IcpCoinsMethods> {
  functionName: T;
  args?: ExtractArgs<IcpCoins[T]>;
  onSuccess?: (data: ExtractReturn<IcpCoins[T]>) => void;
  onError?: (error: any) => void;
}

const useQueryCall = <T extends IcpCoinsMethods>(options: UseQueryCallOptions<T>, actor: ActorSubclass<IcpCoins> | undefined) => {

  const [data, setData] = useState<ExtractReturn<IcpCoins[T]> | undefined>(undefined);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  const call = useCallback(
    async (callArgs?: ExtractArgs<IcpCoins[T]>): Promise<ExtractReturn<IcpCoins[T]> | undefined> => {
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

interface UseUpdateCallOptions<T extends IcpCoinsMethods> {
  functionName: T;
  onSuccess?: (data: ExtractReturn<IcpCoins[T]>) => void;
  onError?: (error: any) => void;
}

const useUpdateCall = <T extends IcpCoinsMethods>(options: UseUpdateCallOptions<T>, actor: ActorSubclass<IcpCoins> | undefined) => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  const call = useCallback(
    async (args: ExtractArgs<IcpCoins[T]> = [] as any): Promise<ExtractReturn<IcpCoins[T]> | undefined> => {

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

export type { IcpCoins };

const useUnauthQueryCall = <T extends IcpCoinsMethods>(options: UseQueryCallOptions<T>) => {
  const { unauthenticated } = useActors();
  return useQueryCall(options, unauthenticated?.icpCoins as any);
}

const useAuthQueryCall = <T extends IcpCoinsMethods>(options: UseQueryCallOptions<T>) => {
  const { authenticated } = useActors();
  return useQueryCall(options, authenticated?.icpCoins as any);
}

const useUnauthUpdateCall = <T extends IcpCoinsMethods>(options: UseUpdateCallOptions<T>) => {
  const { unauthenticated } = useActors();
      return useUpdateCall(options, unauthenticated?.icpCoins as any);
}

const useAuthUpdateCall = <T extends IcpCoinsMethods>(options: UseUpdateCallOptions<T>) => {
  const { authenticated } = useActors();
  return useUpdateCall(options, authenticated?.icpCoins as any);
}

// Compatibility layer that mimics the ic-reactor icpCoinsActor API with full type safety
export const icpCoinsActor = {
  unauthenticated: {
    useQueryCall: useUnauthQueryCall,
    useUpdateCall: useUnauthUpdateCall
  },
  authenticated: {
    useQueryCall: useAuthQueryCall,
    useUpdateCall: useAuthUpdateCall
  }
};
