# SSL Certificate Creation

## Overview
This guide provides step-by-step instructions for generating a self-signed SSL/TLS certificate for `devsecops.local`, valid for **at least 365 days**, including a **Subject Alternative Name (SAN)** for `www.devsecops.local`.

---

## Steps to Generate a Self-Signed SSL Certificate

### ✅ Step 1: Generate a Private Key
- Create a **2048-bit RSA private key**:
  ```sh
  openssl genpkey -algorithm RSA -out devsecops.key -pkeyopt rsa_keygen_bits:2048
  ```

### ✅ Step 2: Create a Certificate Signing Request (CSR)
- Generate a **CSR** with necessary details:
  ```sh
  openssl req -new -key devsecops.key -out devsecops.csr -subj "/C=US/ST=NY/L=NYC/O=DevSecOps Inc/CN=devsecops.local"
  ```

### ✅ Step 3: Create a Configuration File for SAN
- Save the following content in a file called `san.cnf`:
  ```ini
  [req]
  distinguished_name=req_distinguished_name
  [req_distinguished_name]
  [ v3_ext ]
  subjectAltName = @alt_names
  [ alt_names ]
  DNS.1 = devsecops.local
  DNS.2 = www.devsecops.local
  ```

### ✅ Step 4: Generate the Self-Signed Certificate
- Use OpenSSL to create a **self-signed certificate** valid for **365 days**:
  ```sh
  openssl x509 -req -in devsecops.csr -signkey devsecops.key -out devsecops.crt -days 365 -extfile san.cnf -extensions v3_ext
  ```

### ✅ Step 5: Verify the Certificate
- Confirm that the certificate contains the correct details:
  ```sh
  openssl x509 -in devsecops.crt -text -noout
  ```

---

## Further Steps: Using the Certificate with NGINX Ingress on EKS

### **1. Create a Kubernetes Secret for TLS**
Run the following command to store the SSL certificate and key as a Kubernetes secret:
```sh
kubectl create secret tls devsecops-tls   --cert=devsecops.crt   --key=devsecops.key   -n your-namespace
```

### **2. Update the Ingress Resource to Use TLS**
Modify your **Ingress resource** to reference the TLS secret:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: devsecops-ingress
  namespace: your-namespace
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - devsecops.local
        - www.devsecops.local
      secretName: devsecops-tls  # Reference the TLS Secret
  rules:
    - host: devsecops.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

### **3. Verify the Ingress Setup**
Check if the **Ingress** is correctly created:
```sh
kubectl get ingress -n your-namespace
```
Ensure the **TLS secret** is attached:
```sh
kubectl describe ingress devsecops-ingress -n your-namespace
```

### **4. Configure Your Local System to Recognize the Self-Signed Certificate**
Since it's a **self-signed certificate**, your browser may show a **warning**. To fix this, **add the certificate to your local trusted store**:

#### **On Linux/macOS**
```sh
sudo cp devsecops.crt /usr/local/share/ca-certificates/devsecops.crt
sudo update-ca-certificates
```

#### **On Windows (via PowerShell)**
```powershell
Import-Certificate -FilePath "C:\path\to\devsecops.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

### **5. Test HTTPS Access**
Once everything is configured, you can test HTTPS access:
```sh
curl -k https://devsecops.local
```
- The **`-k` (insecure flag)** bypasses TLS verification.
- If you added the certificate to the trusted store, you **won’t need** `-k`.
