import { useAuth } from "@nfid/identitykit/react";
import { fromNullable } from "@dfinity/utils";
import { useCallback, useEffect, useMemo } from "react";
import { backendActor } from "../actors/BackendActor";
import { User } from "../../../declarations/backend/backend.did";

interface UseUserResult {
  user: User | undefined;
  loading: boolean;
  updateNickname: (nickname: string) => Promise<boolean>;
}

export const useUser = (): UseUserResult => {
  const { user: authenticated } = useAuth();

  const { data: user, call: refreshUser } = backendActor.unauthenticated.useQueryCall({
    functionName: 'get_user',
    args: authenticated ? [{ principal: authenticated.principal }] : undefined,
  });

  const normalizedUser = useMemo(
    () => (user ? fromNullable(user) : undefined),
    [user]
  );
  
  const { call: createUser, loading: createUserLoading } = backendActor.unauthenticated.useUpdateCall({
    functionName: 'create_user',
  });

  const { call: setNickname } = backendActor.authenticated.useUpdateCall({
    functionName: 'set_user_nickname',
  });

  useEffect(() => {
    if (authenticated && user !== undefined) {

      let returnedUser = fromNullable(user);
      if (!returnedUser){
        // Automatically create user if not exists
        createUser([ { principal: authenticated.principal, nickname: "New User" }]).then(() => {
          refreshUser([{ principal: authenticated.principal }]);
        }).catch((error) => {
          console.error("Error creating user:", error);
        });
      }
    }
  }, [authenticated, user]);

  // Update nickname function
  const updateNickname = useCallback(async (nickname: string): Promise<boolean> => {
    if (!authenticated || authenticated?.principal.isAnonymous()) {
      return false;
    }

    try {
      const result = await setNickname([{ nickname }]);
      if (result && 'ok' in result) {
        // Trigger refresh of user
        refreshUser([{ principal: authenticated.principal }]);
        return true;
      }
      return false;
    } catch (error) {
      console.error("Error updating nickname:", error);
      return false;
    }
  }, [authenticated]);

  // Determine loading state
  const isLoading = createUserLoading;

  return {
    user: normalizedUser,
    loading: isLoading,
    updateNickname,
  };
};
