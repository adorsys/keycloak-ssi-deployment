# Shutdown keycloak if any
# Determine OS platform and shutdown Keycloak if running
OS=$(uname -s)
case "$OS" in
    Linux*|Darwin*)
        keycloak_pid=$(pgrep -f keycloak)
        if [ -n "$keycloak_pid" ]; then
            echo "Keycloak instance found (PID: $keycloak_pid) on $OS. Shutting it down..."
            kill $keycloak_pid
        fi
        ;;
    *)
        echo "This script supports only Linux or macOS."
        ;;
esac

echo $(pwd)
