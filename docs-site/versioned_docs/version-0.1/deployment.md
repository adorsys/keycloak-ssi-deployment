# Deployment

This section describes how to deploy the Keycloak SSI solution using the provided Helm chart. Helm is a package manager for Kubernetes, allowing you to define, install, and upgrade even the most complex Kubernetes applications.

## Helm Chart Structure

The [keycloak-chart](https://github.com/adorsys/keycloak-ssi-deployment/tree/main/keycloak-chart) directory contains the Helm chart for deploying Keycloak. Key files and directories include:

*   **`Chart.yaml`**: Defines the metadata for the Helm chart, such as its name, version, and description.
*   **`values.yaml`**: Contains default configuration values for the chart. You can override these values during deployment to customize the Keycloak instance.
*   **`templates/`**: This directory holds the Kubernetes manifest templates that Helm processes to generate deployable Kubernetes resources. These templates typically include deployments, services, ingresses, and other necessary components for Keycloak.
    *   `create-config-map.yaml`: Template for creating Kubernetes ConfigMaps, which can store configuration data.
    *   `external-secrets.yml`: Template for integrating with external secret management systems.
    *   `job-rbac.yaml`: Template for Kubernetes Jobs and Role-Based Access Control (RBAC) configurations.
*   **`local_test_minikube/`**: This directory contains specific configurations for testing the Helm chart locally using Minikube.
    *   `configmap-rbac.yaml`: ConfigMap for RBAC settings in a local Minikube environment.
    *   `secret-store.yaml`: Secret store configuration for local testing.

## Deploying with Helm

To deploy the Keycloak SSI solution to a Kubernetes cluster using Helm, follow these general steps:

1.  **Add the Helm repository (if applicable):**
    If your chart is hosted in a Helm repository, you would add it using:
    ```bash
    helm repo add <repo-name> <repo-url>
    helm repo update
    ```

2.  **Install the chart:**
    Navigate to the root of the `keycloak-ssi-deployment` repository and install the chart. You can override default values using the `--set` flag or by providing a custom `values.yaml` file.
    ```bash
    helm install my-keycloak ./keycloak-chart -f my-values.yaml
    ```
    Replace `my-keycloak` with your desired release name and `my-values.yaml` with your custom values file.

3.  **Verify the deployment:**
    After installation, you can check the status of your Kubernetes pods and services:
    ```bash
    kubectl get pods
    kubectl get svc
    ```

This process allows for consistent and automated deployment of the Keycloak SSI environment across different Kubernetes clusters.