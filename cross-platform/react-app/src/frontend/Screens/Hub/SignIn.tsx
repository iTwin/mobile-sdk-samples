/*---------------------------------------------------------------------------------------------
* Copyright (c) Bentley Systems, Incorporated. All rights reserved.
* See LICENSE.md in the project root for license terms and full copyright notice.
*--------------------------------------------------------------------------------------------*/
import { IModelApp } from "@itwin/core-frontend";
import { LoadingSpinner } from "@itwin/core-react";
import { useIsMountedRef } from "@itwin/mobile-ui-react";
import React from "react";
import { Button, i18n, presentError } from "../../Exports";

/** Properties for the {@link SignIn} React component. */
export interface SignInProps {
  onBack: () => void;
  onError: () => void;
  onSignedIn: () => void;
}

/**
 * React component to trigger sign in and then wait while the user is signing in.
 *
 * Shows a spinner and a cancel button while the sign in is happening.
 */
export function SignIn(props: SignInProps) {
  const { onBack, onError, onSignedIn } = props;
  const [signedIn, setSignedIn] = React.useState(false);
  const cancelLabel = React.useMemo(() => i18n("HubScreen", "Cancel"), []);
  const connectingLabel = React.useMemo(() => i18n("HubScreen", "Connecting"), []);
  const userCanceledSignInLabel = React.useMemo(() => i18n("HubScreen", "UserCanceledSignIn"), []);
  const isMountedRef = useIsMountedRef();

  React.useEffect(() => {
    if (signedIn) return;
    const signIn = async () => {
      try {
        // Asking for the access token will trigger sign in if that has not already happened.
        const accessToken = await IModelApp.authorizationClient?.getAccessToken();
        if (!isMountedRef.current)
          return;
        if (accessToken) {
          onSignedIn();
        } else {
          presentError("SigninErrorFormat", new Error(userCanceledSignInLabel), "HubScreen");
          onError();
        }
      } catch (error) {
        presentError("SigninErrorFormat", error, "HubScreen");
        onError();
      }
    };
    setSignedIn(true);
    void signIn();
  }, [isMountedRef, onError, onSignedIn, signedIn, userCanceledSignInLabel]);

  return <div className="centered-list">
    {connectingLabel}
    <LoadingSpinner />
    <Button title={cancelLabel} onClick={() => onBack()} />
  </div>;
}
