#!/bin/bash
# Deploy Ingress Configuration for Airflow and Trino
# This script helps you deploy and configure ingress with authentication

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
AUTH_TYPE="basic"
NAMESPACE="default"
DRY_RUN=false
UPDATE_PASSWORDS=false

# Function to show help
show_help() {
    cat << EOF
Deploy Ingress Configuration for Airflow and Trino

USAGE:
    ./deploy-ingress.sh [OPTIONS]

OPTIONS:
    -t, --type <basic|oauth2|both>  Authentication method to deploy (default: basic)
    -n, --namespace <namespace>     Kubernetes namespace (default: default)
    -d, --dry-run                   Show what would be deployed without applying
    -u, --update-passwords          Generate new passwords for basic auth
    -h, --help                      Show this help message

EXAMPLES:
    # Deploy basic authentication
    ./deploy-ingress.sh --type basic

    # Deploy OAuth2 authentication
    ./deploy-ingress.sh --type oauth2

    # Deploy both (useful for migration)
    ./deploy-ingress.sh --type both

    # Dry run to see what would be applied
    ./deploy-ingress.sh --type basic --dry-run

    # Update basic auth passwords
    ./deploy-ingress.sh --update-passwords

BEFORE RUNNING:
    1. Ensure kubectl is configured and pointing to correct cluster
    2. Install NGINX Ingress Controller if not already installed
    3. For OAuth2, configure client credentials in ingress-oauth2.yml
    4. Update domain names in ingress files
    5. Configure DNS or /etc/hosts

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            AUTH_TYPE="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -u|--update-passwords)
            UPDATE_PASSWORDS=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            ;;
    esac
done

# Validate auth type
if [[ ! "$AUTH_TYPE" =~ ^(basic|oauth2|both)$ ]]; then
    echo -e "${RED}Invalid auth type: $AUTH_TYPE${NC}"
    echo "Must be: basic, oauth2, or both"
    exit 1
fi

# Function to generate password hash
generate_password_hash() {
    local username=$1
    local password=$2
    
    # Try docker first (most reliable)
    if command -v docker &> /dev/null; then
        hash=$(docker run --rm httpd:2.4-alpine htpasswd -nbB "$username" "$password" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -n "$hash" | base64 | tr -d '\n'
            return 0
        fi
    fi
    
    # Fallback to htpasswd if available
    if command -v htpasswd &> /dev/null; then
        hash=$(htpasswd -nbB "$username" "$password")
        echo -n "$hash" | base64 | tr -d '\n'
        return 0
    fi
    
    # Fallback to openssl
    if command -v openssl &> /dev/null; then
        hash=$(echo -n "$username:$(openssl passwd -apr1 "$password")")
        echo -n "$hash" | base64 | tr -d '\n'
        return 0
    fi
    
    echo -e "${RED}Cannot generate password hash. Install Docker, htpasswd, or OpenSSL.${NC}"
    return 1
}

# Update passwords if requested
if [ "$UPDATE_PASSWORDS" = true ]; then
    echo -e "${CYAN}Generating new passwords for Basic Auth...${NC}"
    
    # Airflow password
    read -p "Enter Airflow username (default: admin): " airflow_user
    airflow_user=${airflow_user:-admin}
    read -s -p "Enter Airflow password: " airflow_pass
    echo
    
    airflow_hash=$(generate_password_hash "$airflow_user" "$airflow_pass")
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Airflow password hash generated${NC}"
        echo -e "${CYAN}Hash: $airflow_hash${NC}"
    fi
    
    # Trino password
    echo
    read -p "Enter Trino username (default: admin): " trino_user
    trino_user=${trino_user:-admin}
    read -s -p "Enter Trino password: " trino_pass
    echo
    
    trino_hash=$(generate_password_hash "$trino_user" "$trino_pass")
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Trino password hash generated${NC}"
        echo -e "${CYAN}Hash: $trino_hash${NC}"
    fi
    
    echo
    echo -e "${YELLOW}Update these hashes in kubernetes/ingress.yml before deploying.${NC}"
    exit 0
fi

# Check prerequisites
echo -e "${CYAN}Checking prerequisites...${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}"

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"

# Check if ingress controller is installed
if ! kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx &> /dev/null; then
    echo -e "${YELLOW}⚠ NGINX Ingress Controller not found${NC}"
    echo "To install: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml"
    
    read -p "Install NGINX Ingress Controller now? (y/n): " install
    if [ "$install" = "y" ]; then
        echo -e "${CYAN}Installing NGINX Ingress Controller...${NC}"
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
        echo -e "${CYAN}Waiting for ingress controller to be ready...${NC}"
        kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
        echo -e "${GREEN}✓ NGINX Ingress Controller installed${NC}"
    fi
else
    echo -e "${GREEN}✓ NGINX Ingress Controller found${NC}"
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
KUBERNETES_DIR="$SCRIPT_DIR"

# Deploy based on auth type
echo
echo -e "${CYAN}Deploying ingress configuration...${NC}"
echo -e "Auth Type: ${AUTH_TYPE}"
echo -e "Namespace: ${NAMESPACE}"
echo -e "Dry Run: ${DRY_RUN}"

DRY_RUN_FLAG=""
if [ "$DRY_RUN" = true ]; then
    DRY_RUN_FLAG="--dry-run=client"
fi

# Deploy Basic Auth
if [ "$AUTH_TYPE" = "basic" ] || [ "$AUTH_TYPE" = "both" ]; then
    echo
    echo -e "${CYAN}Deploying Basic Authentication...${NC}"
    INGRESS_FILE="$KUBERNETES_DIR/ingress.yml"
    
    if [ -f "$INGRESS_FILE" ]; then
        kubectl apply -f "$INGRESS_FILE" -n "$NAMESPACE" $DRY_RUN_FLAG
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Basic auth ingress deployed${NC}"
        else
            echo -e "${RED}✗ Failed to deploy basic auth ingress${NC}"
        fi
    else
        echo -e "${RED}✗ ingress.yml not found at $INGRESS_FILE${NC}"
    fi
fi

# Deploy OAuth2
if [ "$AUTH_TYPE" = "oauth2" ] || [ "$AUTH_TYPE" = "both" ]; then
    echo
    echo -e "${CYAN}Deploying OAuth2 Authentication...${NC}"
    OAUTH2_FILE="$KUBERNETES_DIR/ingress-oauth2.yml"
    
    if [ -f "$OAUTH2_FILE" ]; then
        # Check if OAuth credentials are configured
        if grep -q "YOUR_CLIENT_ID\|YOUR_CLIENT_SECRET" "$OAUTH2_FILE"; then
            echo -e "${YELLOW}⚠ OAuth2 credentials not configured in ingress-oauth2.yml${NC}"
            echo "Please update client-id and client-secret before deploying."
            
            read -p "Continue anyway? (y/n): " continue
            if [ "$continue" != "y" ]; then
                echo -e "${YELLOW}Skipping OAuth2 deployment${NC}"
                exit 0
            fi
        fi
        
        kubectl apply -f "$OAUTH2_FILE" -n "$NAMESPACE" $DRY_RUN_FLAG
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ OAuth2 ingress deployed${NC}"
        else
            echo -e "${RED}✗ Failed to deploy OAuth2 ingress${NC}"
        fi
    else
        echo -e "${RED}✗ ingress-oauth2.yml not found at $OAUTH2_FILE${NC}"
    fi
fi

# Show status
if [ "$DRY_RUN" = false ]; then
    echo
    echo -e "${CYAN}Checking deployment status...${NC}"
    
    sleep 2
    
    echo
    echo -e "${CYAN}Ingresses:${NC}"
    kubectl get ingress -n "$NAMESPACE"
    
    if [ "$AUTH_TYPE" = "oauth2" ] || [ "$AUTH_TYPE" = "both" ]; then
        echo
        echo -e "${CYAN}OAuth2 Proxy Pods:${NC}"
        kubectl get pods -n "$NAMESPACE" -l app=oauth2-proxy
    fi
    
    echo
    echo -e "${CYAN}Services:${NC}"
    kubectl get svc -n "$NAMESPACE" | grep -E "airflow|trino|oauth2" || true
    
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Update /etc/hosts or DNS with ingress hostnames"
    echo "2. Configure TLS certificates (recommended)"
    echo "3. Test access to Airflow and Trino UIs"
    echo "4. Review logs if any issues: kubectl logs -n $NAMESPACE <pod-name>"
    
    echo
    echo -e "${YELLOW}Test URLs:${NC}"
    echo "  Airflow: http://airflow.datalake.local"
    echo "  Trino:   http://trino.datalake.local"
    if [ "$AUTH_TYPE" = "oauth2" ] || [ "$AUTH_TYPE" = "both" ]; then
        echo "  OAuth:   http://auth.datalake.local/oauth2"
    fi
fi

echo
echo -e "${GREEN}✓ Deployment complete!${NC}"
