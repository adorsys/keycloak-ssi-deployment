# Customization and Extension

The Keycloak SSI Deployment is designed to be extensible, allowing you to customize its behavior and integrate with other systems.

## Keycloak Plugins

The `providers/` directory contains Keycloak plugins that extend its functionality. For example, `providers/keycloak-token-status-plugin-1.0.0-SNAPSHOT.jar` indicates a custom plugin related to token status.

To develop and integrate your own Keycloak plugins:

1.  **Develop your plugin**: Write your custom Keycloak extension using Java, adhering to Keycloak's Service Provider Interface (SPI).
2.  **Build the JAR**: Compile your plugin into a JAR file.
3.  **Deploy the plugin**: Place the JAR file into the `providers/` directory. When Keycloak starts, it will automatically discover and load the plugin.
4.  **Configure Keycloak**: Depending on your plugin's functionality, you may need to configure it within the Keycloak administration console or through Keycloak's configuration files (e.g., `keycloak-config-dev.json`).

## Terraform Modules

The Terraform modules in [`config/terraform/modules/`](config/terraform/modules/) provide a structured way to extend and customize your Keycloak configuration. You can:

*   **Create new modules**: Develop custom Terraform modules to manage additional Keycloak resources or integrate with other services.
*   **Modify existing modules**: Adjust the existing modules to fit specific requirements, such as adding new client attributes or realm settings.
*   **Override values**: Use custom `values.yaml` files with Helm or Terraform variable overrides to customize deployments without modifying the core chart or module code.

## Dockerfiles

The `Dockerfile` and `Dockerfile.oid4vc-dev` files allow for customization of the Keycloak Docker image. You can modify these Dockerfiles to:

*   **Add custom dependencies**: Include additional libraries or tools required by your Keycloak extensions.
*   **Pre-configure Keycloak**: Add scripts or configuration files to be executed during the Docker image build process, further automating the Keycloak setup.
*   **Change Keycloak version**: Update the base Keycloak image to a different version.

By leveraging these extension points, you can tailor the Keycloak SSI Deployment to meet your specific organizational needs and integrate it seamlessly into your existing infrastructure.