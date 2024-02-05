#Use  Custom Keycloak Docker Image and Deploying it on K8S

- Pull the docker Image 
`$ docker pull ghcr.io/armandmeppa/kcoid4vci:sha-c0271d6`

- We create the file **"Keycloack.yaml"** and **"keycloak-ingress.yaml"** 

- We create the Keycloak deployment and service.
`$ kubectl create -f keycloak.yaml`

- We create an Ingress for Keycloak.
`$ kubectl create -f keycloak-ingress.yaml`
`$ minikube tunnel`
we can acces to the keycloack 
![Alt text](keycloack.png)
