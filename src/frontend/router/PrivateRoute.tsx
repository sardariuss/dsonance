import { useIdentityKit } from "@nfid/identitykit/react";
import { Navigate } from "react-router-dom";
import React from "react";

type PrivateRouteProps = {
  element: React.ReactNode;
};

function PrivateRoute({ element }: PrivateRouteProps) {
  const { user } = useIdentityKit();
  const authenticated = !!user;

  if (!authenticated) {
    return <Navigate to="/login" />;
  }

  return <>{element}</>;
}

export default PrivateRoute;
