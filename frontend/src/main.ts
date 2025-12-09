import QRCode from 'qrcode';
import { frontendConfig } from './config';

// DOM elements
const loginSection = document.getElementById('login-section') as HTMLDivElement;
const authenticatedSection = document.getElementById('authenticated-section') as HTMLDivElement;
const loginForm = document.getElementById('login-form') as HTMLFormElement;
const usernameInput = document.getElementById('username') as HTMLInputElement;
const passwordInput = document.getElementById('password') as HTMLInputElement;
const statusText = document.getElementById('status') as HTMLDivElement;
const getOfferButton = document.getElementById('get-offer') as HTMLButtonElement;
const qrImage = document.getElementById('qr-code') as HTMLCanvasElement;
const userInfo = document.getElementById('user-info') as HTMLDivElement;

let accessToken: string | null = null;
let loggedInUsername: string | null = null;

// Login form handler
loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  
  const username = usernameInput.value.trim();
  const password = passwordInput.value;

  if (!username || !password) {
    statusText.textContent = 'Please enter username and password';
    statusText.style.color = '#ff6961';
    return;
  }

  try {
    statusText.textContent = 'Authenticating...';
    statusText.style.color = '#666';

    // Get access token using password grant (same as script)
    // Use proxy to avoid CORS and certificate issues
    // Proxy forwards to frontendConfig.baseUrl (172.17.0.1:8443)
    const tokenEndpoint = `/api/keycloak/realms/${frontendConfig.realm}/protocol/openid-connect/token`;
    const tokenResponse = await fetch(tokenEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: frontendConfig.clientId,
        client_secret: frontendConfig.clientSecret,
        username: username,
        password: password,
        grant_type: 'password',
        scope: 'openid'
      })
    });

    if (!tokenResponse.ok) {
      const error = await tokenResponse.json().catch(() => ({ error: 'Authentication failed' }));
      throw new Error(error.error_description || error.error || `HTTP ${tokenResponse.status}`);
    }

    const tokenData = await tokenResponse.json();
    accessToken = tokenData.access_token;
    loggedInUsername = username;

    if (!accessToken) {
      throw new Error('No access token received');
    }

    // Show authenticated section
    loginSection.style.display = 'none';
    authenticatedSection.style.display = 'block';
    userInfo.textContent = `Logged in as: ${username}`;
    statusText.textContent = 'Authenticated! Click button to get credential offer.';
    statusText.style.color = '#666';

  } catch (error) {
    console.error('Login error:', error);
    statusText.textContent = `Login failed: ${error instanceof Error ? error.message : 'Unknown error'}`;
    statusText.style.color = '#ff6961';
  }
});

// Get credential offer button click
getOfferButton.addEventListener('click', async () => {
  if (!accessToken || !loggedInUsername) {
    statusText.textContent = 'Not authenticated. Please login first.';
    statusText.style.color = '#ff6961';
    return;
  }

  try {
    getOfferButton.disabled = true;
    statusText.textContent = 'Fetching credential offer...';
    statusText.style.color = '#666';

    // Get credential offer URI (same as script - line 56)
    // Use type=uri to get JSON that we can modify
    // Use proxy to avoid CORS and certificate issues
    const uriParams = new URLSearchParams({
      credential_configuration_id: frontendConfig.credentialConfigurationId,
      type: 'uri',
      pre_authorized: 'true',
      user_id: loggedInUsername,
    });
    const uriEndpoint = `/api/keycloak/realms/${frontendConfig.realm}/protocol/oid4vc/credential-offer-uri?${uriParams.toString()}`;
    const uriResponse = await fetch(uriEndpoint, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Authorization': `Bearer ${accessToken}`
      }
    });

    if (!uriResponse.ok) {
      const error = await uriResponse.json().catch(() => ({ error: 'Request failed' }));
      throw new Error(error.error_description || error.error || `HTTP ${uriResponse.status}`);
    }

    const uriData = await uriResponse.json();
    
    // Extract nonce (same as script - line 64)
    const nonce = uriData.nonce;
    
    if (!nonce) {
      throw new Error('No nonce in response');
    }

    // Build credential offer URI using frontend's base URL (from .env)
    const issuerUrl = `${frontendConfig.baseUrl}/realms/${frontendConfig.realm}`;
    const credentialOfferUri = `${issuerUrl}/protocol/oid4vc/credential-offer/${nonce}`;

    // Fetch the actual credential offer JSON (same as script - line 75)
    // Use proxy to avoid CORS and certificate issues
    const offerResponse = await fetch(`/api/keycloak/realms/${frontendConfig.realm}/protocol/oid4vc/credential-offer/${nonce}`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Authorization': `Bearer ${accessToken}`
      }
    });

    if (!offerResponse.ok) {
      const error = await offerResponse.json().catch(() => ({ error: 'Request failed' }));
      throw new Error(error.error_description || error.error || `HTTP ${offerResponse.status}`);
    }

    const credentialOffer = await offerResponse.json();

    // Modify credential_issuer to use frontend's base URL (same as script - line 83)
    // This ensures the wallet fetches well-known from the correct URL
    credentialOffer.credential_issuer = issuerUrl;
    
    // Generate QR code with the modified credential offer JSON
    // Format: openid-credential-offer://?credential_offer=<encoded_json>
    const encodedOffer = encodeURIComponent(JSON.stringify(credentialOffer));
    const qrCodeData = `openid-credential-offer://?credential_offer=${encodedOffer}`;
    
    // Generate QR code canvas
    await QRCode.toCanvas(qrImage, qrCodeData, {
      width: 300,
      margin: 2
    });

    qrImage.style.display = 'block';
    statusText.textContent = 'Credential offer QR code retrieved! Scan with your wallet.';
    statusText.style.color = '#666';
    getOfferButton.disabled = false;
  } catch (error) {
    console.error('Error:', error);
    statusText.textContent = `Error: ${error instanceof Error ? error.message : 'Unknown error'}`;
    statusText.style.color = '#ff6961';
    getOfferButton.disabled = false;
  }
});
