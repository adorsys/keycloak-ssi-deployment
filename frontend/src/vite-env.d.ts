/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_KEYCLOAK_BASE_URL?: string;
  readonly VITE_KEYCLOAK_REALM?: string;
  readonly VITE_KEYCLOAK_CLIENT_ID?: string;
  readonly VITE_KEYCLOAK_CLIENT_SECRET?: string;
  readonly VITE_CREDENTIAL_CONFIGURATION_ID?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

