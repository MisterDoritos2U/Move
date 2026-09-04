# Move V2 authentication

The supplied Move API documentation defines authentication as a login/token flow.

1. `POST https://{move_ip}/move/v2/users/login`
2. Send JSON with `Spec.UserName` and `Spec.Password`.
3. Read the token from `Status.Token` in the successful response.
4. Store it in the process environment variable `Authorization-Token`.
5. Send that token directly as the `Authorization` HTTP header on subsequent Move V2 requests. Do **not** prepend `Bearer`.

This is based directly on the supplied Login API documentation, which says the login returns an authorization token and that the token is used in all APIs as the HTTP authorization header.

The application therefore no longer constructs a Basic Authorization header for Move V2. Basic authentication remains available for the other legacy endpoint types.

The token is process-scoped and is not written to persistent storage. Saved Move credentials remain in the existing SecretStore credential mechanism and are used only when a new token must be obtained.

If a normal Move V2 request returns HTTP 401, the client clears the process token, logs in again against the appliance that owns the failed request, and retries that request once. The Login endpoint itself is never recursively retried.
