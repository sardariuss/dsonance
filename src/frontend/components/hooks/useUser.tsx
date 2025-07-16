import { useAuth } from "@ic-reactor/react";
import { useCallback, useMemo } from "react";
import { backendActor } from "../../actors/BackendActor";
import { User } from "../../../declarations/backend/backend.did";
import { fromNullableExt } from "../../utils/conversions/nullable";

interface UseUserResult {
  user: User | null;
  loading: boolean;
  updateNickname: (nickname: string) => Promise<boolean>;
  refreshUser: () => void;
}

export const useUser = (): UseUserResult => {
  const { identity, authenticated } = useAuth({});

  // Use ic-reactor's automatic state sharing by providing args that trigger refetch
  const userArgs = useMemo(() => {
    if (!authenticated || !identity || identity.getPrincipal().isAnonymous()) {
      return undefined;
    }
    return [{ principal: identity.getPrincipal() }] as [{ principal: ReturnType<typeof identity.getPrincipal> }];
  }, [authenticated, identity]);

  // Get user data from backend - ic-reactor handles state sharing automatically
  const { data: userData, call: getUserCall, loading: getUserLoading } = backendActor.useQueryCall({
    functionName: 'get_user',
    args: userArgs
  });

  // Set user nickname
  const { call: setUserCall, loading: setUserLoading } = backendActor.useUpdateCall({
    functionName: 'set_user'
  });

  // Process user data
  const user = useMemo(() => {
    if (!userData) return null;
    return fromNullableExt(userData) || null;
  }, [userData]);

  // Update nickname function
  const updateNickname = useCallback(async (nickname: string): Promise<boolean> => {
    if (!authenticated || !identity || identity.getPrincipal().isAnonymous()) {
      return false;
    }

    try {
      const result = await setUserCall([{ nickname }]);
      if (result && 'ok' in result) {
        // Trigger refetch by calling getUserCall with current args
        if (userArgs) {
          await getUserCall(userArgs);
        }
        return true;
      }
      return false;
    } catch (error) {
      console.error("Error updating nickname:", error);
      return false;
    }
  }, [authenticated, identity, setUserCall, getUserCall, userArgs]);

  // Refresh user data
  const refreshUser = useCallback(() => {
    if (userArgs) {
      getUserCall(userArgs);
    }
  }, [getUserCall, userArgs]);

  // Determine loading state
  const isLoading = getUserLoading || setUserLoading;

  return {
    user,
    loading: isLoading,
    updateNickname,
    refreshUser
  };
};
