import { useState, useEffect } from 'react';
import { useActors } from '../common/ActorsContext';
import { ActorMethod, ActorSubclass } from '@dfinity/agent';
import { _SERVICE as Protocol } from "../../../declarations/protocol/protocol.did";

// Type utilities to extract function signatures from ActorMethod
type ProtocolMethods = keyof Protocol;
type ExtractArgs<T> = T extends ActorMethod<infer P, any> ? P : never;
type ExtractReturn<T> = T extends ActorMethod<any, infer R> ? R : never;

interface UseQueryCallOptions<T extends ProtocolMethods> {
  functionName: T;
  args?: ExtractArgs<Protocol[T]>;
  onSuccess?: (data: ExtractReturn<Protocol[T]>) => void;
  onError?: (error: any) => void;
}

const useQueryCall = <T extends ProtocolMethods>(options: UseQueryCallOptions<T>, actor: ActorSubclass<Protocol> | undefined) => {

  const [data, setData] = useState<ExtractReturn<Protocol[T]> | undefined>(undefined);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  const call = async (callArgs?: ExtractArgs<Protocol[T]>): Promise<ExtractReturn<Protocol[T]> | undefined> => {

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
    console.log("ProtocolActor useEffect triggered with args:", options.args);
    if (options.args !== undefined) {
      call();
    } else {
      // Reset data if no args
      setData(undefined);
    }
  }, [actor, options.functionName, serializeArgs(options.args)]);

  return { data, loading, error, call };
};

interface UseUpdateCallOptions<T extends ProtocolMethods> {
  functionName: T;
  onSuccess?: (data: ExtractReturn<Protocol[T]>) => void;
  onError?: (error: any) => void;
}

const useUpdateCall = <T extends ProtocolMethods>(options: UseUpdateCallOptions<T>, actor: ActorSubclass<Protocol> | undefined) => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  const call = async (args: ExtractArgs<Protocol[T]> = [] as any): Promise<ExtractReturn<Protocol[T]> | undefined> => {

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

export type { Protocol };

const useUnauthQueryCall = <T extends ProtocolMethods>(options: UseQueryCallOptions<T>) => {
  const { unauthenticated } = useActors();
  return useQueryCall(options, unauthenticated?.protocol as any);
}

const useAuthQueryCall = <T extends ProtocolMethods>(options: UseQueryCallOptions<T>) => {
  const { authenticated } = useActors();
  return useQueryCall(options, authenticated?.protocol as any);
}

const useUnauthUpdateCall = <T extends ProtocolMethods>(options: UseUpdateCallOptions<T>) => {
  const { unauthenticated } = useActors();
      return useUpdateCall(options, unauthenticated?.protocol as any);
}

const useAuthUpdateCall = <T extends ProtocolMethods>(options: UseUpdateCallOptions<T>) => {
  const { authenticated } = useActors();
  return useUpdateCall(options, authenticated?.protocol as any);
}

// Compatibility layer that mimics the ic-reactor protocolActor API with full type safety
export const protocolActor = {
  unauthenticated: {
    useQueryCall: useUnauthQueryCall,
    useUpdateCall: useUnauthUpdateCall
  },
  authenticated: {
    useQueryCall: useAuthQueryCall,
    useUpdateCall: useAuthUpdateCall
  }
};
