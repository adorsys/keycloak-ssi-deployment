# Build the image
We want to provide a keycloak image with oid4vci feature enabled.


For the moment, a script sequence leads the deveoper through steps needed to deploy keycloak and hav  e it issue a verifiable credential

# Steps
- Checkout this project.
- In the project directory execute following scripts:

## In the first shell
```bash
# checkout build and start keycloak
./0.start-kc-oid4vci.sh 
```

Wait for Keycloak to start

## In the second shell
```bash
./1.oid4vci_test_deployment.sh

./2.configure_user_4_account_client.sh

./3.retrieve_credential.sh
```
