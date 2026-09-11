const domain = import.meta.env.VITE_COGNITO_DOMAIN as string | undefined;
const client = import.meta.env.VITE_COGNITO_CLIENT_ID as string | undefined;
const redirect = (import.meta.env.VITE_REDIRECT_URI as string | undefined) || window.location.origin + "/";
const encode = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

export function token(): string | null {
  const expiry = Number(sessionStorage.getItem("streamml_expiry") || 0);
  return expiry > Date.now() + 5000 ? sessionStorage.getItem("streamml_token") : null;
}
export async function login(): Promise<void> {
  if (!domain || !client) throw new Error("Configure Cognito to connect to AWS. Use the labelled sample preview meanwhile.");
  const verifier = encode(crypto.getRandomValues(new Uint8Array(32)));
  const state = encode(crypto.getRandomValues(new Uint8Array(24)));
  sessionStorage.setItem("streamml_verifier", verifier);
  sessionStorage.setItem("streamml_state", state);
  const challenge = encode(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier))));
  const params = new URLSearchParams({client_id: client, response_type: "code", redirect_uri: redirect,
    scope: "openid email streamml/read", state, code_challenge: challenge, code_challenge_method: "S256"});
  window.location.assign(domain + "/oauth2/authorize?" + params);
}
export async function completeLogin(): Promise<void> {
  const params = new URLSearchParams(window.location.search);
  const code = params.get("code");
  if (!code) return;
  const state = sessionStorage.getItem("streamml_state");
  const verifier = sessionStorage.getItem("streamml_verifier");
  if (!state || !verifier || params.get("state") !== state || !domain || !client)
    throw new Error("Sign-in state did not match. Start sign-in again.");
  window.history.replaceState({}, "", "/");
  sessionStorage.removeItem("streamml_state");
  sessionStorage.removeItem("streamml_verifier");
  const response = await fetch(domain + "/oauth2/token", {method: "POST", headers: {"content-type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams({grant_type: "authorization_code", client_id: client, redirect_uri: redirect, code, code_verifier: verifier})});
  if (!response.ok) throw new Error("Sign-in exchange failed. Start sign-in again.");
  const body: {access_token: string; expires_in: number} = await response.json();
  sessionStorage.setItem("streamml_token", body.access_token);
  sessionStorage.setItem("streamml_expiry", String(Date.now() + body.expires_in * 1000));
}
export function logout(): void {
  for (const key of ["streamml_token", "streamml_expiry", "streamml_state", "streamml_verifier"]) sessionStorage.removeItem(key);
  if (domain && client) window.location.assign(domain + "/logout?" + new URLSearchParams({client_id: client, logout_uri: redirect}));
  else window.location.reload();
}

