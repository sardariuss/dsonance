import { useAuth } from "@ic-reactor/react";
import { useCallback, useEffect } from "react";
import { backendActor } from "../../actors/BackendActor";
import { User } from "../../../declarations/backend/backend.did";

interface UseUserResult {
  user: User | undefined;
  loading: boolean;
  updateNickname: (nickname: string) => Promise<boolean>;
}

export const useUser = (): UseUserResult => {
  const { identity, authenticated } = useAuth({});

  // Get user data from backend - ic-reactor handles state sharing automatically
  const { data: user, call: getOrCreateUser, loading: getOrCreateUserLoading } = backendActor.useUpdateCall({
    functionName: 'get_or_create_user',
  });

  // Set user nickname
  const { call: setNickname, loading: setNicknameLoading } = backendActor.useUpdateCall({
    functionName: 'set_user_nickname',
  });

  useEffect(() => {
    if (authenticated && identity && !identity.getPrincipal().isAnonymous() && !user) {
      // Automatically create user if not exists
      getOrCreateUser();
    }
  }, [authenticated, identity]);

  // Update nickname function
  const updateNickname = useCallback(async (nickname: string): Promise<boolean> => {
    if (!authenticated || !identity || identity.getPrincipal().isAnonymous()) {
      return false;
    }

    try {
      const result = await setNickname([{ nickname }]);
      if (result && 'ok' in result) {
        // Trigger refetch by calling getUser with current args
        getOrCreateUser();
        return true;
      }
      return false;
    } catch (error) {
      console.error("Error updating nickname:", error);
      return false;
    }
  }, [authenticated, identity, setNickname]);

  // Determine loading state
  const isLoading = getOrCreateUserLoading || setNicknameLoading;

  return {
    user,
    loading: isLoading,
    updateNickname,
  };
};
