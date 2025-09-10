import { useAuth } from "@nfid/identitykit/react";
import { useCallback, useEffect, useState } from "react";
import { backendActor } from "../actors/BackendActor";
import { User } from "../../../declarations/backend/backend.did";

interface UseUserResult {
  user: User | undefined;
  loading: boolean;
  updateNickname: (nickname: string) => Promise<boolean>;
}

export const useUser = (): UseUserResult => {
  const { user : authenticatedUser } = useAuth();

  // State for user data
  const [user, setUser] = useState<User | undefined>(undefined);
  
  // Get user data from backend
  const { call: getOrCreateUser, loading: getOrCreateUserLoading } = backendActor.authenticated.useUpdateCall({
    functionName: 'get_or_create_user',
    onSuccess: (userData) => setUser(userData),
  });

  // Set user nickname
  const { call: setNickname, loading: setNicknameLoading } = backendActor.authenticated.useUpdateCall({
    functionName: 'set_user_nickname',
  });

  useEffect(() => {
    if (authenticatedUser && !authenticatedUser?.principal.isAnonymous() && !user) {
      // Automatically create user if not exists
      getOrCreateUser();
    }
  }, [authenticatedUser]);

  // Update nickname function
  const updateNickname = useCallback(async (nickname: string): Promise<boolean> => {
    if (!authenticatedUser || !authenticatedUser?.principal.isAnonymous()) {
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
  }, [authenticatedUser, setNickname]);

  // Determine loading state
  const isLoading = getOrCreateUserLoading || setNicknameLoading;

  return {
    user,
    loading: isLoading,
    updateNickname,
  };
};
