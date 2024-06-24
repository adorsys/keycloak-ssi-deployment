# Build the image
We want to provide a keycloak image with oid4vci feature enabled.


For the moment, a script sequence leads the developer through steps needed to deploy keycloak and have it issue a verifiable credential

For this version: checkout the branch: https://github.com/adorsys/keycloak-oid4vc/tree/issue-30525. 

This is subject of the pull request: https://github.com/keycloak/keycloak/pull/30692. You will go back to KC upstream as soon as this branch is merged.

# Steps
- Checkout this project.
- In the project directory execute following scripts:

## In the first shell
```bash
# checkout build and start keycloak
./0.start-kc-oid4vci.sh 
```

Wait for Keycloak to start

## Configure oid4vci protocol

In the second shell

```bash
./1.oid4vci_test_deployment.sh

./2.configure_user_4_account_client.sh
```

## Produce a credential without key binding

```bash
./3.retrieve_test_credential.sh
```

## Produce a credential with key binding

```bash
./3.retrieve_IdentityCredential.sh
```