import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    allowedHosts: ['localhost', '127.0.0.1', '0.0.0.0'],
    port: 5173,
    host: '0.0.0.0',
    proxy: {
      '/api/keycloak': {
        // Proxy forwards to Keycloak at 172.17.0.1:8443 (Docker host IP)
        // This matches VITE_KEYCLOAK_BASE_URL in .env
        target: 'https://172.17.0.1:8443',
        changeOrigin: true,
        secure: false, // Allow self-signed certificates
        rewrite: (path) => path.replace(/^\/api\/keycloak/, ''),
        configure: (proxy, _options) => {
          proxy.on('error', (err, _req, _res) => {
            console.log('proxy error', err);
          });
        }
      }
    }
  }
});

