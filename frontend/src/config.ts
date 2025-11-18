export type FrontendConfig = {
  baseUrl: string;
  realm: string;
  clientId: string;
  clientSecret: string;
  credentialConfigurationId: string;
};

const sanitizeBaseUrl = (value: string) => value.replace(/\/+$/, '');

const fromEnv = (key: keyof ImportMetaEnv): string => {
  const value = import.meta.env[key];
  if (!value) {
    throw new Error(`Missing required env var: ${String(key)}`);
  }
  return value;
};

export const frontendConfig: FrontendConfig = {
  baseUrl: sanitizeBaseUrl(fromEnv('VITE_KEYCLOAK_BASE_URL')),
  realm: fromEnv('VITE_KEYCLOAK_REALM'),
  clientId: fromEnv('VITE_KEYCLOAK_CLIENT_ID'),
  clientSecret: fromEnv('VITE_KEYCLOAK_CLIENT_SECRET'),
  credentialConfigurationId: fromEnv('VITE_CREDENTIAL_CONFIGURATION_ID')
};

