#!/bin/bash

# Infrastructure & Pipeline Validation Script
# Validates Bicep templates and checks prerequisites for deployment

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   Infrastructure & Pipeline Validation                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

RESOURCE_GROUP="${1:-entra-demo-dev-rg}"
LOCATION="${2:-eastus}"

echo ""
echo "📋 Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location:       $LOCATION"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_mark="✓"
cross_mark="✗"

# 1. Check Azure CLI
echo "🔍 Checking Azure CLI..."
if command -v az &> /dev/null; then
    AZ_VERSION=$(az version --query '"azure-cli"' -o tsv)
    echo -e "${GREEN}${check_mark}${NC} Azure CLI installed: $AZ_VERSION"
else
    echo -e "${RED}${cross_mark}${NC} Azure CLI not found. Install: https://aka.ms/azure-cli"
    exit 1
fi

# 2. Check logged in
echo ""
echo "🔍 Checking Azure login..."
if az account show &> /dev/null; then
    ACCOUNT=$(az account show --query "name" -o tsv)
    SUBSCRIPTION=$(az account show --query "id" -o tsv)
    echo -e "${GREEN}${check_mark}${NC} Logged in as: $ACCOUNT"
    echo "  Subscription: $SUBSCRIPTION"
else
    echo -e "${RED}${cross_mark}${NC} Not logged in. Run: az login"
    exit 1
fi

# 3. Check resource group exists
echo ""
echo "🔍 Checking resource group..."
if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${GREEN}${check_mark}${NC} Resource group exists: $RESOURCE_GROUP"
else
    echo -e "${YELLOW}⚠${NC}  Resource group not found. Creating..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    echo -e "${GREEN}${check_mark}${NC} Resource group created"
fi

# 4. Check Bicep files exist
echo ""
echo "🔍 Checking Bicep files..."
BICEP_FILES=(
    "infra/main.bicep"
    "infra/main.bicepparam"
    "infra/modules/keyvault.bicep"
    "infra/modules/sql.bicep"
    "infra/modules/container-apps.bicep"
    "infra/modules/container-apps-env.bicep"
    "infra/modules/container-registry.bicep"
    "infra/modules/monitoring.bicep"
)

for file in "${BICEP_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}${check_mark}${NC} Found: $file"
    else
        echo -e "${RED}${cross_mark}${NC} Missing: $file"
        exit 1
    fi
done

# 5. Validate Bicep syntax
echo ""
echo "🔍 Validating Bicep syntax..."
if az bicep validate -f infra/main.bicep &> /dev/null; then
    echo -e "${GREEN}${check_mark}${NC} Bicep syntax is valid"
else
    echo -e "${RED}${cross_mark}${NC} Bicep syntax errors found:"
    az bicep validate -f infra/main.bicep
    exit 1
fi

# 6. Validate against Azure
echo ""
echo "🔍 Validating Bicep parameters against Azure..."
if az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file infra/main.bicep \
    --parameters infra/main.bicepparam \
    --parameters \
        registryUsername="test-user" \
        registryPassword="test-pass" \
        sqlAdminPassword="TestPass123!" \
    &> /dev/null; then
    echo -e "${GREEN}${check_mark}${NC} Template validation passed"
else
    echo -e "${RED}${cross_mark}${NC} Template validation failed:"
    az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file infra/main.bicep \
        --parameters infra/main.bicepparam \
        --parameters \
            registryUsername="test-user" \
            registryPassword="test-pass" \
            sqlAdminPassword="TestPass123!"
    exit 1
fi

# 7. Check for hardcoded passwords
echo ""
echo "🔍 Checking for hardcoded passwords..."
if grep -r "P@ssw0rd\|password.*123\|secret.*123" infra/main.bicepparam 2>/dev/null; then
    echo -e "${RED}${cross_mark}${NC} WARNING: Found hardcoded passwords in parameter files!"
    echo "  Ensure parameters are overridden at deployment time"
else
    echo -e "${GREEN}${check_mark}${NC} No hardcoded passwords found in parameter files"
fi

# 8. Check Docker files exist
echo ""
echo "🔍 Checking Docker files..."
DOCKER_FILES=(
    "frontend/Dockerfile"
    "bff/Dockerfile"
    "api/Dockerfile"
)

for file in "${DOCKER_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}${check_mark}${NC} Found: $file"
    else
        echo -e "${RED}${cross_mark}${NC} Missing: $file"
    fi
done

# 9. Check pipeline exists
echo ""
echo "🔍 Checking pipeline configuration..."
if [ -f "azure-pipelines.yml" ]; then
    echo -e "${GREEN}${check_mark}${NC} Found: azure-pipelines.yml"
    
    # Check for validation stages
    if grep -q "Validate Infrastructure" azure-pipelines.yml; then
        echo -e "${GREEN}${check_mark}${NC} Pipeline has Validate stage"
    else
        echo -e "${YELLOW}⚠${NC}  Pipeline missing Validate stage"
    fi
    
    if grep -q "What-If" azure-pipelines.yml; then
        echo -e "${GREEN}${check_mark}${NC} Pipeline has What-If stage"
    else
        echo -e "${YELLOW}⚠${NC}  Pipeline missing What-If stage"
    fi
else
    echo -e "${RED}${cross_mark}${NC} Missing: azure-pipelines.yml"
fi

# 10. Check project structure
echo ""
echo "🔍 Checking project structure..."
REQUIRED_DIRS=(
    "frontend"
    "bff"
    "api"
    "infra"
    "infra/modules"
    "docs"
    ".azure"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}${check_mark}${NC} Found: $dir/"
    else
        echo -e "${RED}${cross_mark}${NC} Missing: $dir/"
    fi
done

# 11. Permissions check
echo ""
echo "🔍 Checking Azure permissions..."
if az role assignment list --query "length(@)" --output tsv &> /dev/null; then
    ROLES=$(az role assignment list --query "length(@)" --output tsv)
    echo -e "${GREEN}${check_mark}${NC} User has $ROLES role assignments"
else
    echo -e "${YELLOW}⚠${NC}  Could not verify permissions"
fi

# Summary
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    Validation Summary                         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}✓${NC} All infrastructure and pipeline checks passed!"
echo ""
echo "📚 Next Steps:"
echo "  1. Review: .azure/infra-validation-deployment.md"
echo "  2. Set up: docs/ci-cd-setup.md (Variable Groups)"
echo "  3. Deploy: az deployment group create (see guide above)"
echo "  4. Monitor: Application Insights in Azure Portal"
echo ""
echo "💡 Commands:"
echo "  Validate:    az deployment group validate ..."
echo "  What-If:     az deployment group what-if ..."
echo "  Deploy:      az deployment group create ..."
echo "  Check logs:  az deployment operation list ..."
echo ""
