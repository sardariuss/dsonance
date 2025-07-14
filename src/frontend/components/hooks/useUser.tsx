import { useAuth } from "@ic-reactor/react";
import { useEffect, useState, useCallback } from "react";
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
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(false);

  // Get user data from backend
  const { call: getUserCall, loading: getUserLoading } = backendActor.useQueryCall({
    functionName: 'get_user'
  });

  // Set user nickname
  const { call: setUserCall, loading: setUserLoading } = backendActor.useUpdateCall({
    functionName: 'set_user'
  });

  // Function to fetch user data
  const fetchUser = useCallback(async () => {
    if (!authenticated || !identity || identity.getPrincipal().isAnonymous()) {
      setUser(null);
      return;
    }

    try {
      const result = await getUserCall([{ principal: identity.getPrincipal() }]);
      const userData = fromNullableExt(result);
      
      if (userData) {
        setUser(userData);
      } else {
        // User doesn't exist, create with default nickname
        const createResult = await setUserCall([{ nickname: "New user" }]);
        if (createResult && 'ok' in createResult) {
          // Refetch user after creation
          const newResult = await getUserCall([{ principal: identity.getPrincipal() }]);
          const newUserData = fromNullableExt(newResult);
          setUser(newUserData || null);
        }
      }
    } catch (error) {
      console.error("Error fetching user:", error);
      setUser(null);
    }
  }, [authenticated, identity, getUserCall, setUserCall]);

  // Update nickname function
  const updateNickname = useCallback(async (nickname: string): Promise<boolean> => {
    if (!authenticated || !identity || identity.getPrincipal().isAnonymous()) {
      return false;
    }

    try {
      const result = await setUserCall([{ nickname }]);
      if (result && 'ok' in result) {
        // Update local user state
        if (user) {
          setUser({ ...user, nickname });
        }
        return true;
      }
      return false;
    } catch (error) {
      console.error("Error updating nickname:", error);
      return false;
    }
  }, [authenticated, identity, setUserCall, user]);

  // Refresh user data
  const refreshUser = useCallback(() => {
    fetchUser();
  }, [identity]);

  // Effect to fetch user when authentication state changes
  useEffect(() => {
    fetchUser();
  }, [identity]);

  // Determine loading state
  const isLoading = loading || getUserLoading || setUserLoading;

  return {
    user,
    loading: isLoading,
    updateNickname,
    refreshUser
  };
};
