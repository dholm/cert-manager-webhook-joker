# cert-manager webhook for joker.com DNS
cert-manager ACME DNS01 webhook provider for joker.com.

## Prequesites
The following components needs to be already installed on a Kubernetes cluster:
 * Kubernetes (>= v1.11.0) [](https://kubernetes.io/)
 * cert-manager (>= v0.14.0) [](https://cert-manager.io/docs/installation/kubernetes/)
 * helm (>= v3.0.0) [](https://helm.sh/docs/intro/install/)

At joker.com you need to enable Dynamic DNS to get credentials for API access. You can find the documentation [here](https://joker.com/faq/content/6/496/en/let_s-encrypt-support.html).
 
## Installation
 1. Create a Kubernetes secret which will hold your joker DynDNS authentication credentials (base64 representation):
 
```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: joker-credentials
  namespace: kube-system
data:
  username: <joker Username>
  password: <joker Password>
EOF
```
 
 2. Grant permission to get the secret to `cert-manager-webhook-joker` service account:

 ```yaml
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cert-manager-webhook-joker:secret-reader
  namespace: kube-system
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["joker-credentials"]
  verbs: ["get", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cert-manager-webhook-joker:secret-reader
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cert-manager-webhook-joker:secret-reader
subjects:
- apiGroup: ""
  kind: ServiceAccount
  name: cert-manager-webhook-joker
EOF
```

 3. Clone the github repository:
 
```console
git clone https://github.com/4nx/cert-manager-webhook-joker.git
```

 4. Choose a unique group name to identify your company or organization (e.g. `acme.yourcompany.com`) and install the Helm chart with:

```console
helm upgrade --install cert-manager-webhook-joker --namespace cert-manager deploy/cert-manager-webhook-joker
```

 5. Create a certificate issuer with the letsencrypt staging ca for testing purposes (you must insert your e-mail address):

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging-test
spec:
  acme:
    # Change to your letsencrypt email
    email: <your email>
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
    - dns01:
        webhook:
          groupName: acme.yourcompany.com
          solverName: joker
          config:
            baseURL: https://svc.joker.com/nic/replace
            dnsType: TXT
            userNameSecretRef:
              name: joker-credentials
              key: username
            passwordSecretRef:
              name: joker-credentials
              key: password
EOF
```

 6. Issue a test certificate (replace the test urls in here):

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: example-tls
spec:
  secretName: example-com-tls
  commonName: example.com
  dnsNames:
  - example.com
  - "*.example.com"
  issuerRef:
    name: letsencrypt-staging-test
    kind: ClusterIssuer
EOF
```

## Development
All DNS providers must run the DNS01 provider conformance testing suite, else they will have undetermined behaviour when used with cert-manager.

__It is essential that you configure and run the test suite when creating a DNS01 webhook.__

Before you can run the test suite, you need to download the test binaries:

```console
./scripts/fetch-test-binaries.sh
```

Then duplicate the .sample files in testdata/joker/ and update the configuration with the appropriate Joker.com credentials.

Now you can run the test suite with:

```sh
TEST_ZONE_NAME=example.com. go test .
```

