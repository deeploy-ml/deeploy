<h1 align="center"> Install Deeploy </h1> <br>

<p align="center">
This repository is part of the [complete installation guide](https://deeploy-ml.zendesk.com/hc/en-150/categories/360002889759-Install) and contains detailed instructions how to install the Deeploy Software Stack on Kubernetes using [Helm](https://helm.sh/).
</p>

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Install the Deeploy Software Stack](#install-the-deeploy-software-stack)
  - [Step 1. Create the Deeploy namespaces](#step-1-create-the-deeploy-namespaces)
  - [Step 2. Install Istio](#step-2-install-istio)
  - [Step 3. Install Knative](#step-3-install-knative)
  - [Step 4. Install Cert-manager](#step-4-install-cert-manager)
  - [Step 5. Metrics Server](#step-5-metrics-server)
  - [Step 6. Deeploy Helm chart](#step-6-deeploy-helm-chart)
- [Troubelshooting](#troubelshooting)
  - [`Permission Denied` errors on GKE](#permission-denied-errors-on-gke)

## Install the Deeploy Software Stack

We assume that you now have the prerequisites and infrastructure ready as defined in [the installation guide](https://deeploy-ml.zendesk.com/hc/en-150/categories/360002889759-Install). From here we continue deploying the Deeploy software stack with dependencies.
Make sure you are in the `deeploy-core` root folder.

### Step 1. Create the Deeploy namespaces

Create all the Deeploy namespaces in kubernetes.

```bash
kubectl apply -f namespaces/
```

### Step 2. Install Istio

> Current Istio installation instructions are based on `istio version 1.4.10` that should work on common cloud platforms. Always double check [platform specific installation requirements](https://istio.io/docs/setup/platform-setup/) and [the istio helm installation instructions](https://istio.io/docs/setup/install/helm/) to check the latest installation instructions.

**Installation steps:**

1. Download the Istio release:

    ```bash
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.4.10 sh -
    ```

2. Install Istio CRD's:

    ```bash
    for i in ./istio-1.4.10/install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done
    ```

3. Install Istio:

    ```bash
    $ # A lighter template, with just pilot/gateway.
    # Based on install/kubernetes/helm/istio/values-istio-minimal.yaml
    helm template --namespace=istio-system \
    -f ./istio/values.yaml \
    istio-1.4.10/install/kubernetes/helm/istio \
    | sed -e "s/custom-gateway/cluster-local-gateway/g" -e "s/customgateway/clusterlocalgateway/g" \
    > ./istio.yaml

    kubectl apply -f istio.yaml
    ```

4. Wait for a couple seconds and verify everything is in the running state by running:

    ```bash
    kubectl get pods --namespace istio-system
    ```

For additional information about installing Istio, see the [official website](https://archive.istio.io/v1.4/docs/setup/install/istioctl/)

### Step 3. Install Knative

1. Install Knative CRDs using

    ```bash
    kubectl apply --filename ./knative/serving-crds.yml
    ```

2. Install core components

    ```bash
    kubectl apply --filename ./knative/serving-core.yml
    ```

3. Install the Knative Istio controller:

    ```bash
    kubectl apply --filename ./knative/serving-istio.yml
    ```

### Step 4. Install Cert-manager

1. [Install cert-manager](https://cert-manager.io/docs/installation/kubernetes/#installing-with-helm).

2. (__Optional__) [Set up auto-renewal through ACME](https://cert-manager.io/docs/configuration/acme/). Only do this if you want to terminate TLS on this cluster. Make sure to generate two certificates as described above.

### Step 5. Metrics Server

The Kubernetes Metrics Server is necessary for pod autoscaling.
Most cloud providers pre-install the Metrics Server in your cluster, but some do not.

Validate that the `metrics-server` pod is running in the `kube-system` namespace. If not, install it.

- [AWS EKS Metrics Server Guide](https://docs.aws.amazon.com/eks/latest/userguide/metrics-server.html)
- [Digital Ocean Metrics Server Guide](https://www.digitalocean.com/community/tutorials/how-to-autoscale-your-workloads-on-digitalocean-kubernetes#step-3-%E2%80%94-installing-metrics-server)


### Step 6. Deeploy Helm chart

Edit `./helm/deeploy/values.yaml`:

__Deeploy General Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `host` | the hostname on which you will be running deeploy | `""` |
| `license.type` | The type of license. Either "AWS" or "DEEPLOY" | `"AWS"` |
| `license.deeployLicenseKey` | if the license type is "DEEPLOY", this is the supplied Deeploy license key | `""` |
| `license.availabilityZone` | if the license type is "AWS", this is the region where your cluster resides | `"eu-central-1"` |

__Deeploy Image Repository Values:__

Currently Deeploy is available from two image repositories

- AWS Marketplace (current default): `709825985650.dkr.ecr.us-east-1.amazonaws.com/deeploy/deeploy`
- Docker: `docker.io/deeployml`

| Parameter | Description | Default |
| --- | --- | --- |
| `images.registry` | the registry to pull the Deeploy images from | `"709825985650.dkr.ecr.us-east-1.amazonaws.com/deeploy/"` |
| `images.path` | the path to the DeeployML registry | `"/deeploy"` |
| `images.tag` | the version tag of the deeploy deployment | same as application version |
| `images.username` | if the license type is "DEEPLOY", the supplied username for the Docker registry | `""` |
| `images.password` | f the license type is "DEEPLOY", the supplied password for the Docker registry | `""` |

__Deeploy Database Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `database.host` | the hostname of the database server | `""` |
| `database.port` | the port for use of the database server | `5432` |
| `database.username` | the username to access the database. **Note**: this user needs to be a superuser | `""` |
| `database.password` | the password to access the database server | `""` |
| `database.ssl.enabled` | whether to enable SSL on the database. If `true`, must also set `database.ssl.ca`. | `false` |
| `database.ssl.ca` | the CA of your database provider. Must be set if `database.ssl.enabled` is `true`. E.g. for AWS, see [this guide](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html). | `""` |

__Deeploy Remote Blob Storage Values:__

For Remote Blob Storage you have two options:

1. **Use Remote Blob Storage (recommended)**. Deeploy currently supports AWS S3, Google Cloud Storage & Azure Blob Storage
2. **Don't configure remote Storage (not recommended)**. Deeploy spawns an on-cluster Minio service.
    This is not recommended, as it makes Deeploy statefull on the cluster.
    If you do want to use it, set `minio.enabled` to true.

| Parameter | Description | Default |
| --- | --- | --- |
| `remoteBlobStorage.enabled` | whether to use off-cluster Blob storage. If enabled, set `minio.enabled` to `false` | `true` |
| `minio.enabled` | whether to use on-cluster S3 storage. If enabled, set `remoteBlobStorage.enabled` to `false` | `false` |
| `remoteBlobStorage.type` | storage service to use with Deeploy. One of `AWS_S3`, `GCS`, `AZURE`. | `"AWS_S3"` |
| `remoteBlobStorage.aws.bucketName` | name of the remote S3 storage bucket to use | `""` |
| `remoteBlobStorage.aws.s3AccessKey` | access key for the S3 server. Only set if `remoteBlobStorage.type` is `AWS_S3`. | `""` |
| `remoteBlobStorage.aws.s3SecretKey` | secret key for the S3 server Only set if `remoteBlobStorage.type` is `AWS_S3`. | `""` |
| `remoteBlobStorage.gcp.gcloudApplicationCredentialsJson` | the json file with the credentials for the GCP service account. Only set if `remoteBlobStorage.type` is `GCS`. | `""` |
| `remoteBlobStorage.gcp.bucketName` | name of the remote GS storage bucket to use | `""` |
| `remoteBlobStorage.azure.subscriptionId` | the id of the subscription that hosts the storage account. Only set if `remoteBlobStorage.type` is `AZURE`. | `""` |
| `remoteBlobStorage.azure.containerName` | the container name to use. Only set if `remoteBlobStorage.type` is `AZURE`. | `""` |
| `remoteBlobStorage.azure.storageAccountName` | the name of the Azure Storage Account. Only set if `remoteBlobStorage.type` is `AZURE`. | `""` |
| `remoteBlobStorage.azure.tenantId` | the Tenant ID of the Azure storage service. Only set if `remoteBlobStorage.type` is `AZURE`. | `""` |
| `remoteBlobStorage.azure.clientId` | the Client ID of the Azure storage service. Only set if `remoteBlobStorage.type` is `AZURE`. | `""` |
| `remoteBlobStorage.azure.clientSecret` | the Client Secret of the Azure storage service. Only set if `remoteBlobStorage.type` is `AZURE`. | `""` |

__Deeploy SMTP Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `email.smtpHost` | the hostname of the smtp server | `""` |
| `email.port` | the port for use of the smtp server | `""` |
| `email.username` | the username to access the smtp server | `""` |
| `email.password` | the password to access the smtp server | `""` |
| `email.fromAddress` | the email address for Deeploy to send emails from, i.e. `deeploy@example.com` | `""` |

__Deeploy Monitoring Values:__

The Deeploy Monitoring feature sends anonimized usage data back to Deeploy. This helps us to improve the product.

| Parameter | Description | Default |
| --- | --- | --- |
| `monitoring.enabled` | whether to enable monitoring | `false` |
| `monitoring.credentials.username` | username for the monitoring server | `""` |
| `monitoring.credentials.password` | password for the monitoring server | `""` |

__Deeploy Security Values:__

| Parameter | Description | Default |
| --- | --- | --- |
| `security.tls.enabled` | whether to enable TLS | `true` |
| `security.adminCredentials.firstName` | first name of the main admin user | `""` |
| `security.adminCredentials.lastName` | last name of the main admin user | `""` |
| `security.adminCredentials.email` | email of the main admin user | `""` |
| `security.keyManagement.kmsType` | either `AWS` or `AZURE` | `""` |
| `security.keyManagement.aws.keyId` | ID of a KMS key used to encrypt/decrypt. Only set if `security.keyManagement.kmsType` is `AWS`. | `""` |
| `security.keyManagement.aws.accessKey` | IAM Access Key of an account that has access to the key. Only set if `security.keyManagement.kmsType` is `AWS`. | `""` |
| `security.keyManagement.aws.secretKey` | IAM Secret Key of an account that has access to the key. Only set if `security.keyManagement.kmsType` is `AWS`. | `""` |
| `security.keyManagement.azure.keyId` | ID of the Azure Vault key. Only set if `security.keyManagement.kmsType` is `AZURE`. | `""` |
| `security.keyManagement.azure.vaultName` | name of the Azure vault. Only set if `security.keyManagement.kmsType` is `AZURE`. | `""` |
| `security.keyManagement.azure.clientId` |  the Client ID of the client using the Azure Vault service. Only set if `security.keyManagement.kmsType` is `AZURE`. | `""` |
| `security.keyManagement.azure.clientSecret` | the Client Secret of the client using the Azure Vault service. Only set if `security.keyManagement.kmsType` is `AZURE`. | `""` |
| `security.keyManagement.azure.tenantId` | the Tenant ID of the Azure Vault service. Only set if `security.keyManagement.kmsType` is `AZURE`. | `""` |

1. Deploy the Deeploy stack using

    ```bash
    helm install -f ./helm/deeploy/values.yaml deeploy ./helm/deeploy --namespace deeploy
    ```

    **Important**: This might print out the following line. This is expected behavior and not a bug:

    ```verilog
    manifest_sorter.go:192: info: skipping unknown hook: "crd-install"
    ```

2. Add the s3 secret to the default service account:

    ```bash
    kubectl edit sa default -n deeploy
    ```

    and add the `s3-secret` name

    ```yaml
    secrets:
    - name: default-...
    - name: s3-secret
    ```

    Close and save.

Create first admin user.

## Troubelshooting

### `Permission Denied` errors on GKE

When running on GKE (Google Kubernetes Engine), you may encounter a ‘permission denied’ error when creating some of the resources. This is a nuance of the way GKE handles RBAC and IAM permissions, and as such you should ‘elevate’ your own privileges to that of a ‘cluster-admin’ before running the above commands. If you have already run the above commands, you should run them again after elevating your permissions.
