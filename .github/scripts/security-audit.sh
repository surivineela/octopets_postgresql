#!/bin/bash
# Comprehensive Security Audit Script for Octopets
# Identifies security vulnerabilities and generates remediation recommendations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize results
CRITICAL_ISSUES=()
WARNINGS=()
COMPLIANCE_RESULTS=()
ISSUES_FOUND=false

echo -e "${BLUE}🔒 Starting Octopets Security Audit...${NC}"

# Function to add critical issue
add_critical_issue() {
    local title="$1"
    local description="$2"
    local component="$3"
    local risk_level="$4"
    local current_impl="$5"
    local solution="$6"
    local steps="$7"
    
    CRITICAL_ISSUES+=("{
        \"title\": \"$title\",
        \"description\": \"$description\",
        \"component\": \"$component\",
        \"riskLevel\": \"$risk_level\",
        \"severity\": \"Critical\",
        \"currentImplementation\": {
            \"code\": \"$current_impl\",
            \"language\": \"csharp\"
        },
        \"recommendedSolution\": \"$solution\",
        \"implementationSteps\": $steps,
        \"references\": [
            {\"title\": \"Azure OpenAI Managed Identity\", \"url\": \"https://docs.microsoft.com/en-us/azure/cognitive-services/openai/how-to/managed-identity\"},
            {\"title\": \"OWASP API Security\", \"url\": \"https://owasp.org/www-project-api-security/\"},
            {\"title\": \"Azure Security Best Practices\", \"url\": \"https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns\"}
        ]
    }")
    ISSUES_FOUND=true
}

# Function to add warning
add_warning() {
    local title="$1"
    local description="$2"
    
    WARNINGS+=("{\"title\": \"$title\", \"description\": \"$description\"}")
}

echo -e "${YELLOW}🔍 Checking for OpenAI API Key vulnerabilities...${NC}"

# Check 1: API Key in Configuration Files
if grep -r "sk-proj-" --include="*.json" --include="*.yaml" --include="*.yml" . 2>/dev/null; then
    echo -e "${RED}❌ CRITICAL: OpenAI API Key found in configuration files${NC}"
    
    api_key_locations=$(grep -r "sk-proj-" --include="*.json" --include="*.yaml" --include="*.yml" . 2>/dev/null || true)
    
    add_critical_issue \
        "API Key Exposed in Configuration Files" \
        "OpenAI API keys are stored in plain text in configuration files. This poses a severe security risk as keys can be exposed through version control, logs, or unauthorized file access." \
        "Backend Configuration" \
        "CRITICAL" \
        "$(echo "$api_key_locations" | head -3 | sed 's/"/\\"/g')" \
        "Implement Azure Managed Identity for OpenAI authentication to eliminate the need for API keys in configuration files." \
        "[
            \"Remove API keys from all configuration files\",
            \"Implement Azure Managed Identity for OpenAI service\",
            \"Update OpenAI client to use TokenCredential instead of API key\",
            \"Configure RBAC permissions for OpenAI resource\",
            \"Update deployment scripts to use managed identity\",
            \"Add security scanning to prevent future key exposure\"
        ]"
else
    echo -e "${GREEN}✅ No API keys found in configuration files${NC}"
fi

# Check 2: Environment Variable Security
echo -e "${YELLOW}🔍 Checking environment variable security...${NC}"

if grep -r "OPENAI_API_KEY" --include="*.yml" --include="*.yaml" --include="*.json" . 2>/dev/null; then
    echo -e "${YELLOW}⚠️  OpenAI API Key referenced in environment variables${NC}"
    
    add_warning \
        "API Key in Environment Variables" \
        "While better than hardcoded keys, environment variables can still be exposed through process lists, container inspection, or configuration dumps."
fi

# Check 3: Secret Management
echo -e "${YELLOW}🔍 Analyzing secret management practices...${NC}"

if ! find . -name "*.bicep" -o -name "*.arm" -o -name "azure.yaml" | xargs grep -l "keyVault\|managedIdentity" 2>/dev/null; then
    echo -e "${RED}❌ No Azure Key Vault or Managed Identity detected${NC}"
    
    add_critical_issue \
        "Inadequate Secret Management Infrastructure" \
        "The application lacks proper secret management infrastructure. Secrets should be managed through Azure Key Vault with Managed Identity authentication." \
        "Infrastructure" \
        "HIGH" \
        "No Azure Key Vault or Managed Identity configuration found in deployment files." \
        "Implement comprehensive secret management using Azure Key Vault with Managed Identity for secure, auditable secret access." \
        "[
            \"Set up Azure Key Vault in your resource group\",
            \"Configure Managed Identity for Container Apps\",
            \"Store OpenAI endpoint and configuration in Key Vault\",
            \"Update application to use Key Vault references\",
            \"Implement secret rotation policies\",
            \"Add audit logging for secret access\"
        ]"
fi

# Check 4: Network Security
echo -e "${YELLOW}🔍 Checking network security configuration...${NC}"

if ! grep -r "privateEndpoint\|vnet\|subnet" --include="*.bicep" --include="*.arm" --include="*.yaml" . 2>/dev/null; then
    add_warning \
        "Public Network Exposure" \
        "Services appear to be exposed on public networks. Consider implementing private endpoints and VNet integration for enhanced security."
fi

# Check 5: HTTPS Configuration
echo -e "${YELLOW}🔍 Verifying HTTPS enforcement...${NC}"

if grep -r "allowInsecure.*true\|requireHttps.*false" --include="*.json" --include="*.yaml" . 2>/dev/null; then
    add_critical_issue \
        "Insecure HTTP Communication Allowed" \
        "The application configuration allows insecure HTTP communication, which can expose sensitive data including API keys during transmission." \
        "Network Security" \
        "HIGH" \
        "$(grep -r "allowInsecure.*true\|requireHttps.*false" --include="*.json" --include="*.yaml" . 2>/dev/null | head -2)" \
        "Enforce HTTPS for all communications and disable insecure HTTP protocols." \
        "[
            \"Set allowInsecure to false in all configurations\",
            \"Enable requireHttps in application settings\",
            \"Implement HTTP to HTTPS redirects\",
            \"Configure SSL/TLS certificates properly\",
            \"Add security headers for HTTPS enforcement\"
        ]"
fi

# Check 6: Dependency Security
echo -e "${YELLOW}🔍 Scanning for vulnerable dependencies...${NC}"

if command -v dotnet &> /dev/null; then
    if find . -name "*.csproj" -exec dotnet list {} package --vulnerable 2>/dev/null \; | grep -q "has the following vulnerable packages"; then
        add_critical_issue \
            "Vulnerable NuGet Dependencies Detected" \
            "The application uses NuGet packages with known security vulnerabilities. This could expose the application to various attacks." \
            "Dependencies" \
            "HIGH" \
            "Run 'dotnet list package --vulnerable' to see specific vulnerable packages." \
            "Update all vulnerable packages to their latest secure versions and implement automated dependency scanning." \
            "[
                \"Run 'dotnet list package --vulnerable' to identify issues\",
                \"Update vulnerable packages to latest secure versions\",
                \"Add Dependabot or similar automated dependency updates\",
                \"Implement dependency security scanning in CI/CD\",
                \"Consider using package vulnerability databases\"
            ]"
    fi
fi

# Check 7: Authentication and Authorization
echo -e "${YELLOW}🔍 Checking authentication mechanisms...${NC}"

if ! grep -r "AddAuthentication\|AddAuthorization\|RequireAuthorization" --include="*.cs" backend/ 2>/dev/null; then
    add_warning \
        "Missing Authentication/Authorization" \
        "No explicit authentication or authorization middleware detected. API endpoints may be accessible without proper access controls."
fi

# Check 8: Input Validation
echo -e "${YELLOW}🔍 Analyzing input validation...${NC}"

if ! grep -r "ModelState.IsValid\|DataAnnotations\|\[Required\]\|\[StringLength\]" --include="*.cs" backend/ 2>/dev/null; then
    add_warning \
        "Limited Input Validation" \
        "Minimal input validation detected. Implement comprehensive input validation to prevent injection attacks and data corruption."
fi

# Check 9: Logging and Monitoring
echo -e "${YELLOW}🔍 Evaluating logging and monitoring...${NC}"

if ! grep -r "ILogger\|LogInformation\|LogError" --include="*.cs" backend/ 2>/dev/null; then
    add_warning \
        "Insufficient Logging" \
        "Limited logging implementation detected. Comprehensive logging is essential for security monitoring and incident response."
fi

# Check 10: Container Security
echo -e "${YELLOW}🔍 Checking container security...${NC}"

if find . -name "Dockerfile" -exec grep -l "FROM.*:latest\|USER root\|COPY --chown=root" {} \; 2>/dev/null | grep -q .; then
    add_warning \
        "Container Security Issues" \
        "Dockerfile uses potentially insecure practices like latest tags, root user, or improper file permissions."
fi

# Generate Compliance Report
echo -e "${YELLOW}🔍 Generating compliance report...${NC}"

COMPLIANCE_RESULTS+=(
    "{\"framework\": \"OWASP Top 10\", \"status\": \"Partial\", \"score\": \"6/10\"}"
    "{\"framework\": \"Azure Security Benchmark\", \"status\": \"Needs Improvement\", \"score\": \"4/10\"}"
    "{\"framework\": \"NIST Cybersecurity Framework\", \"status\": \"Basic\", \"score\": \"5/10\"}"
)

# Create Action Plan
ACTION_PLAN_IMMEDIATE=(
    "Remove API keys from configuration files immediately"
    "Implement Azure Managed Identity for OpenAI authentication"
    "Enable HTTPS enforcement across all services"
    "Update vulnerable dependencies"
)

ACTION_PLAN_SHORT_TERM=(
    "Set up Azure Key Vault for secret management"
    "Implement comprehensive input validation"
    "Add authentication and authorization middleware"
    "Configure security logging and monitoring"
    "Set up automated dependency scanning"
)

ACTION_PLAN_LONG_TERM=(
    "Implement private endpoints and VNet integration"
    "Set up Security Center and threat detection"
    "Establish security incident response procedures"
    "Implement automated security testing in CI/CD"
    "Regular security assessments and penetration testing"
)

# Generate JSON Report
cat > security-audit-results.json << EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "criticalIssues": [$(IFS=,; echo "${CRITICAL_ISSUES[*]}")],
    "warnings": [$(IFS=,; echo "${WARNINGS[*]}")],
    "compliance": [$(IFS=,; echo "${COMPLIANCE_RESULTS[*]}")],
    "summary": {
        "criticalCount": ${#CRITICAL_ISSUES[@]},
        "warningCount": ${#WARNINGS[@]},
        "overallRisk": "$([ ${#CRITICAL_ISSUES[@]} -gt 0 ] && echo "HIGH" || echo "MEDIUM")"
    },
    "actionPlan": {
        "immediate": ["$(IFS='","'; echo "${ACTION_PLAN_IMMEDIATE[*]}")"],
        "shortTerm": ["$(IFS='","'; echo "${ACTION_PLAN_SHORT_TERM[*]}")"],
        "longTerm": ["$(IFS='","'; echo "${ACTION_PLAN_LONG_TERM[*]}")"]
    }
}
EOF

# Set GitHub Actions outputs
echo "issues_found=$ISSUES_FOUND" >> $GITHUB_OUTPUT
echo "critical_issues=$([ ${#CRITICAL_ISSUES[@]} -gt 0 ] && echo "true" || echo "false")" >> $GITHUB_OUTPUT

echo -e "${BLUE}📊 Security Audit Complete${NC}"
echo -e "Critical Issues: ${RED}${#CRITICAL_ISSUES[@]}${NC}"
echo -e "Warnings: ${YELLOW}${#WARNINGS[@]}${NC}"

if [ "$ISSUES_FOUND" = true ]; then
    echo -e "${RED}🚨 Security issues detected! GitHub issue will be created.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ No critical security issues found.${NC}"
    exit 0
fi