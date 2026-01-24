#!/bin/bash
# Script to test Karmada multi-cluster deployment with cluster info display
# Run this on vps9 after clusters are joined

set -e

echo "=== Karmada Multi-Cluster Test Deployment with Cluster Info ==="
echo ""

SETUP_DIR="/root/karmada-setup"
KARMADA_CONFIG="$SETUP_DIR/configs/karmada-kubeconfig"

# Step 1: Create test namespace
echo "=== Step 1: Creating Test Namespace ==="
kubectl --kubeconfig=$KARMADA_CONFIG create namespace karmada-test || echo "Namespace already exists"

# Step 2: Create ConfigMap for nginx custom page
echo ""
echo "=== Step 2: Creating ConfigMap for Custom Nginx Page ==="
cat > $SETUP_DIR/policies/nginx-configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: karmada-test
  labels:
    karmada.io/managed: "true"
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Karmada Multi-Cluster Demo</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                margin: 40px;
                background-color: #f0f0f0;
            }
            .container {
                background-color: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                max-width: 600px;
                margin: 0 auto;
            }
            h1 {
                color: #333;
                text-align: center;
                margin-bottom: 30px;
            }
            .info-box {
                background-color: #f8f9fa;
                border: 1px solid #dee2e6;
                border-radius: 5px;
                padding: 20px;
                margin-bottom: 20px;
            }
            .info-item {
                margin: 10px 0;
                display: flex;
                justify-content: space-between;
            }
            .label {
                font-weight: bold;
                color: #495057;
                min-width: 150px;
            }
            .value {
                color: #212529;
                font-family: monospace;
                background-color: #e9ecef;
                padding: 2px 8px;
                border-radius: 3px;
            }
            .cluster-badge {
                display: inline-block;
                padding: 5px 15px;
                border-radius: 20px;
                font-weight: bold;
                margin: 10px 0;
            }
            .cluster-vn { background-color: #28a745; color: white; }
            .cluster-vn2 { background-color: #20c997; color: white; }
            .cluster-us { background-color: #007bff; color: white; }
            .cluster-eu { background-color: #6610f2; color: white; }
            .cluster-jp { background-color: #dc3545; color: white; }
            .timestamp {
                text-align: center;
                color: #6c757d;
                margin-top: 20px;
                font-size: 0.9em;
            }
        </style>
        <script>
            function updateTime() {
                document.getElementById('current-time').textContent = new Date().toLocaleString();
            }
            setInterval(updateTime, 1000);
        </script>
    </head>
    <body onload="updateTime()">
        <div class="container">
            <h1>🌐 Karmada Multi-Cluster Demo</h1>

            <div class="info-box">
                <h2>Pod Information</h2>
                <div class="info-item">
                    <span class="label">Pod Name:</span>
                    <span class="value">HOSTNAME_PLACEHOLDER</span>
                </div>
                <div class="info-item">
                    <span class="label">Pod IP:</span>
                    <span class="value">POD_IP_PLACEHOLDER</span>
                </div>
                <div class="info-item">
                    <span class="label">Node Name:</span>
                    <span class="value">NODE_NAME_PLACEHOLDER</span>
                </div>
                <div class="info-item">
                    <span class="label">Namespace:</span>
                    <span class="value">NAMESPACE_PLACEHOLDER</span>
                </div>
            </div>

            <div class="info-box">
                <h2>Cluster Information</h2>
                <div class="info-item">
                    <span class="label">Cluster:</span>
                    <span class="cluster-badge cluster-CLUSTER_PLACEHOLDER">CLUSTER_PLACEHOLDER</span>
                </div>
                <div class="info-item">
                    <span class="label">Region:</span>
                    <span class="value">REGION_PLACEHOLDER</span>
                </div>
            </div>

            <div class="timestamp">
                <p>Server Time: <span id="current-time"></span></p>
                <p>Served by Karmada-managed Kubernetes cluster</p>
            </div>
        </div>
    </body>
    </html>
  startup.sh: |
    #!/bin/sh
    # Get pod information from environment and Kubernetes downward API
    POD_NAME=${HOSTNAME}
    POD_IP=${POD_IP:-$(hostname -i)}
    NODE_NAME=${NODE_NAME:-"unknown"}
    NAMESPACE=${NAMESPACE:-"unknown"}

    # Determine cluster based on node name or environment
    CLUSTER="unknown"
    REGION="unknown"

    # Map clusters to regions
    case "${KARMADA_CLUSTER}" in
        "vn")
            CLUSTER="vn"
            REGION="Vietnam (Primary)"
            ;;
        "vn2")
            CLUSTER="vn2"
            REGION="Vietnam (Secondary)"
            ;;
        "us")
            CLUSTER="us"
            REGION="United States"
            ;;
        "eu")
            CLUSTER="eu"
            REGION="Europe"
            ;;
        "jp")
            CLUSTER="jp"
            REGION="Japan"
            ;;
        *)
            CLUSTER="${KARMADA_CLUSTER:-unknown}"
            REGION="Unknown"
            ;;
    esac

    # Replace placeholders in the HTML file
    cp /usr/share/nginx/html/index.html /tmp/index.html
    sed -i "s/HOSTNAME_PLACEHOLDER/${POD_NAME}/g" /tmp/index.html
    sed -i "s/POD_IP_PLACEHOLDER/${POD_IP}/g" /tmp/index.html
    sed -i "s/NODE_NAME_PLACEHOLDER/${NODE_NAME}/g" /tmp/index.html
    sed -i "s/NAMESPACE_PLACEHOLDER/${NAMESPACE}/g" /tmp/index.html
    sed -i "s/CLUSTER_PLACEHOLDER/${CLUSTER}/g" /tmp/index.html
    sed -i "s/REGION_PLACEHOLDER/${REGION}/g" /tmp/index.html

    # Copy the modified file back
    cp /tmp/index.html /usr/share/nginx/html/index.html

    # Start nginx
    nginx -g 'daemon off;'
EOF

kubectl --kubeconfig=$KARMADA_CONFIG apply -f $SETUP_DIR/policies/nginx-configmap.yaml

# Step 3: Create custom nginx deployment
echo ""
echo "=== Step 3: Creating Custom Nginx Deployment ==="
cat > $SETUP_DIR/policies/nginx-deployment-with-info.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-cluster-info
  namespace: karmada-test
  labels:
    app: nginx-info
    karmada.io/managed: "true"
spec:
  replicas: 10
  selector:
    matchLabels:
      app: nginx-info
  template:
    metadata:
      labels:
        app: nginx-info
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        command: ["/bin/sh"]
        args: ["/usr/share/nginx/startup.sh"]
        ports:
        - containerPort: 80
        env:
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: KARMADA_CLUSTER
          value: "CLUSTER_NAME"  # This will be overridden by Karmada
        volumeMounts:
        - name: nginx-config
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
        - name: nginx-config
          mountPath: /usr/share/nginx/startup.sh
          subPath: startup.sh
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
          defaultMode: 0755
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-info-service
  namespace: karmada-test
  labels:
    karmada.io/managed: "true"
spec:
  selector:
    app: nginx-info
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

kubectl --kubeconfig=$KARMADA_CONFIG apply -f $SETUP_DIR/policies/nginx-deployment-with-info.yaml

# Step 4: Create cluster-specific override policies
echo ""
echo "=== Step 4: Creating Cluster-Specific Override Policies ==="
cat > $SETUP_DIR/policies/cluster-overrides.yaml << 'EOF'
apiVersion: policy.karmada.io/v1alpha1
kind: OverridePolicy
metadata:
  name: nginx-cluster-override
  namespace: karmada-test
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      name: nginx-cluster-info
  overrideRules:
    - targetCluster:
        clusterNames: ["vn"]
      overriders:
        plaintext:
          - path: "/spec/template/spec/containers/0/env/3/value"
            value: "vn"
    - targetCluster:
        clusterNames: ["vn2"]
      overriders:
        plaintext:
          - path: "/spec/template/spec/containers/0/env/3/value"
            value: "vn2"
    - targetCluster:
        clusterNames: ["us"]
      overriders:
        plaintext:
          - path: "/spec/template/spec/containers/0/env/3/value"
            value: "us"
    - targetCluster:
        clusterNames: ["eu"]
      overriders:
        plaintext:
          - path: "/spec/template/spec/containers/0/env/3/value"
            value: "eu"
    - targetCluster:
        clusterNames: ["jp"]
      overriders:
        plaintext:
          - path: "/spec/template/spec/containers/0/env/3/value"
            value: "jp"
EOF

kubectl --kubeconfig=$KARMADA_CONFIG apply -f $SETUP_DIR/policies/cluster-overrides.yaml

# Step 5: Create propagation policy
echo ""
echo "=== Step 5: Creating Propagation Policy ==="
cat > $SETUP_DIR/policies/nginx-info-propagation.yaml << 'EOF'
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: nginx-info-propagation
  namespace: karmada-test
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      name: nginx-cluster-info
    - apiVersion: v1
      kind: Service
      name: nginx-info-service
    - apiVersion: v1
      kind: ConfigMap
      name: nginx-config
  placement:
    clusterAffinity:
      clusterNames:
        - vn
        - vn2
        - us
        - eu
        - jp
    replicaScheduling:
      replicaDivisionPreference: Weighted
      replicaSchedulingType: Divided
      weightPreference:
        staticWeightList:
          - targetCluster:
              clusterNames:
                - vn
            weight: 3
          - targetCluster:
              clusterNames:
                - vn2
            weight: 3
          - targetCluster:
              clusterNames:
                - us
            weight: 2
          - targetCluster:
              clusterNames:
                - eu
            weight: 1
          - targetCluster:
              clusterNames:
                - jp
            weight: 1
EOF

kubectl --kubeconfig=$KARMADA_CONFIG apply -f $SETUP_DIR/policies/nginx-info-propagation.yaml

# Step 6: Wait for deployment
echo ""
echo "=== Step 6: Waiting for Deployment Distribution ==="
echo "Waiting 30 seconds for Karmada to distribute workloads..."
sleep 30

# Step 7: Create port-forward script for each cluster
echo ""
echo "=== Step 7: Creating Access Scripts ==="
cat > $SETUP_DIR/scripts/access-nginx-clusters.sh << 'EOF'
#!/bin/bash
# Script to access nginx pods from different clusters

echo "=== Nginx Cluster Info Access Script ==="
echo ""
echo "This script will create port-forwards to access nginx from each cluster"
echo "You can then access them via browser at different ports:"
echo ""
echo "  - http://localhost:8001 -> Vietnam Primary (vn)"
echo "  - http://localhost:8002 -> Vietnam Secondary (vn2)"
echo "  - http://localhost:8003 -> United States (us)"
echo "  - http://localhost:8004 -> Europe (eu)"
echo "  - http://localhost:8005 -> Japan (jp)"
echo ""

CLUSTERS=("vn:8001" "vn2:8002" "us:8003" "eu:8004" "jp:8005")

for cluster_port in "${CLUSTERS[@]}"; do
    cluster="${cluster_port%:*}"
    port="${cluster_port#*:}"

    echo "Setting up port-forward for $cluster on port $port..."

    # Get first pod in the cluster
    pod=$(kubectl --kubeconfig=/root/karmada-setup/configs/kubeconfig-$cluster get pods -n karmada-test -o name 2>/dev/null | head -1)

    if [ -n "$pod" ]; then
        kubectl --kubeconfig=/root/karmada-setup/configs/kubeconfig-$cluster port-forward -n karmada-test $pod $port:80 &
        echo "✓ Port-forward started for $cluster"
    else
        echo "✗ No pods found in $cluster"
    fi
done

echo ""
echo "Port-forwards started. Press Ctrl+C to stop all."
echo "Open your browser and visit the URLs above to see cluster info."

# Wait for interrupt
wait
EOF

chmod +x $SETUP_DIR/scripts/access-nginx-clusters.sh

# Step 8: Create monitoring script
echo ""
echo "=== Step 8: Creating Monitoring Script ==="
cat > $SETUP_DIR/scripts/monitor-nginx-info.sh << 'EOF'
#!/bin/bash
echo "=== Nginx Cluster Info Deployment Status ==="
echo "Date: $(date)"
echo ""

CLUSTERS=("vn" "vn2" "us" "eu" "jp")
TOTAL_PODS=0

echo "Pod Distribution:"
echo "=================="
for cluster in "${CLUSTERS[@]}"; do
    count=$(kubectl --kubeconfig=/root/karmada-setup/configs/kubeconfig-$cluster get pods -n karmada-test --no-headers 2>/dev/null | wc -l || echo "0")
    TOTAL_PODS=$((TOTAL_PODS + count))
    printf "%-10s: %2d pods" "$cluster" "$count"

    # Get one pod IP as example
    if [ "$count" -gt 0 ]; then
        pod_ip=$(kubectl --kubeconfig=/root/karmada-setup/configs/kubeconfig-$cluster get pods -n karmada-test -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
        echo " (example IP: $pod_ip)"
    else
        echo ""
    fi
done
echo "=================="
echo "Total pods : $TOTAL_PODS"
echo ""

echo "To access the nginx pods:"
echo "1. From vps9: Run /root/karmada-setup/scripts/access-nginx-clusters.sh"
echo "2. From your local machine: Set up SSH tunnels to vps9"
echo ""
echo "Example SSH tunnel from local:"
echo "ssh -L 8001:localhost:8001 -L 8002:localhost:8002 -L 8003:localhost:8003 -L 8004:localhost:8004 -L 8005:localhost:8005 root@46.250.232.0"
EOF

chmod +x $SETUP_DIR/scripts/monitor-nginx-info.sh

# Run monitoring script
$SETUP_DIR/scripts/monitor-nginx-info.sh

echo ""
echo "✓ Deployment completed!"
echo ""
echo "To access nginx with cluster info:"
echo "1. SSH to vps9 and run: $SETUP_DIR/scripts/access-nginx-clusters.sh"
echo "2. Or set up SSH tunnels from your local machine"
echo ""
echo "Each nginx page will show:"
echo "- Pod name and IP"
echo "- Cluster name and region"
echo "- Node information"
echo "- Real-time timestamp"
