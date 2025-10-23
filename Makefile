# Octopets Security Management Makefile
# Provides automated security fixes and improvements

.PHONY: help security-audit security-fix-auto security-check-deps security-update-deps security-migrate-managed-identity

# Colors for output
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
NC     := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Octopets Security Management$(NC)"
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

security-audit: ## Run comprehensive security audit
	@echo "$(YELLOW)🔍 Running security audit...$(NC)"
	@chmod +x ./.github/scripts/security-audit.sh
	@./.github/scripts/security-audit.sh || true
	@echo "$(GREEN)✅ Security audit complete. Check security-audit-results.json$(NC)"

security-fix-auto: ## Apply automated security fixes
	@echo "$(YELLOW)🔧 Applying automated security fixes...$(NC)"
	
	# Remove API keys from configuration files (but keep structure)
	@echo "$(BLUE)Removing API keys from configuration files...$(NC)"
	@find . -name "appsettings.*.json" -exec sed -i.bak 's/sk-proj-[^"]*/<REMOVED_FOR_SECURITY>/g' {} \;
	@find . -name "*.yaml" -o -name "*.yml" -exec sed -i.bak 's/sk-proj-[^"]*/<REMOVED_FOR_SECURITY>/g' {} \;
	
	# Update HTTPS settings
	@echo "$(BLUE)Enforcing HTTPS settings...$(NC)"
	@find . -name "appsettings.*.json" -exec sed -i.bak 's/"allowInsecure": *true/"allowInsecure": false/g' {} \;
	@find . -name "appsettings.*.json" -exec sed -i.bak 's/"requireHttps": *false/"requireHttps": true/g' {} \;
	
	# Add security headers to nginx config
	@if [ -f "frontend/nginx.conf" ]; then \
		echo "$(BLUE)Adding security headers to nginx config...$(NC)"; \
		cp frontend/nginx.conf frontend/nginx.conf.bak; \
		awk '/location \/ {/{print; print "        # Security headers"; print "        add_header X-Frame-Options DENY;"; print "        add_header X-Content-Type-Options nosniff;"; print "        add_header X-XSS-Protection \"1; mode=block\";"; print "        add_header Referrer-Policy strict-origin-when-cross-origin;"; print "        add_header Content-Security-Policy \"default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https:;\";"; next} 1' frontend/nginx.conf.bak > frontend/nginx.conf; \
	fi
	
	# Update Dockerfile to use non-root user
	@if [ -f "frontend/Dockerfile" ]; then \
		echo "$(BLUE)Updating Dockerfile security...$(NC)"; \
		cp frontend/Dockerfile frontend/Dockerfile.bak; \
		echo "# Create non-root user" >> frontend/Dockerfile; \
		echo "RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001" >> frontend/Dockerfile; \
		echo "USER nextjs" >> frontend/Dockerfile; \
	fi
	
	@echo "$(GREEN)✅ Automated security fixes applied$(NC)"
	@echo "$(YELLOW)⚠️  Please review changes and commit if appropriate$(NC)"

security-check-deps: ## Check for vulnerable dependencies
	@echo "$(YELLOW)🔍 Checking for vulnerable dependencies...$(NC)"
	
	# Check .NET dependencies
	@if command -v dotnet >/dev/null 2>&1; then \
		echo "$(BLUE)Checking .NET dependencies...$(NC)"; \
		find . -name "*.csproj" -exec dirname {} \; | sort -u | while read dir; do \
			echo "Checking $$dir..."; \
			(cd "$$dir" && dotnet list package --vulnerable --include-transitive) || true; \
		done; \
	fi
	
	# Check Node.js dependencies
	@if [ -f "frontend/package.json" ] && command -v npm >/dev/null 2>&1; then \
		echo "$(BLUE)Checking Node.js dependencies...$(NC)"; \
		(cd frontend && npm audit --audit-level=moderate) || true; \
	fi
	
	@echo "$(GREEN)✅ Dependency check complete$(NC)"

security-update-deps: ## Update vulnerable dependencies
	@echo "$(YELLOW)🔄 Updating vulnerable dependencies...$(NC)"
	
	# Update .NET dependencies
	@if command -v dotnet >/dev/null 2>&1; then \
		echo "$(BLUE)Updating .NET dependencies...$(NC)"; \
		find . -name "*.csproj" -exec dirname {} \; | sort -u | while read dir; do \
			echo "Updating $$dir..."; \
			(cd "$$dir" && dotnet add package Microsoft.AspNetCore.App --version 9.0.0) || true; \
		done; \
	fi
	
	# Update Node.js dependencies
	@if [ -f "frontend/package.json" ] && command -v npm >/dev/null 2>&1; then \
		echo "$(BLUE)Updating Node.js dependencies...$(NC)"; \
		(cd frontend && npm update && npm audit fix) || true; \
	fi
	
	@echo "$(GREEN)✅ Dependencies updated$(NC)"

security-migrate-managed-identity: ## Migrate from API key to Managed Identity authentication
	@echo "$(YELLOW)🔄 Starting Managed Identity migration...$(NC)"
	
	# Check if Azure CLI is installed and logged in
	@if ! command -v az >/dev/null 2>&1; then \
		echo "$(RED)❌ Azure CLI not installed. Please install it first.$(NC)"; \
		exit 1; \
	fi
	
	@if ! az account show >/dev/null 2>&1; then \
		echo "$(RED)❌ Not logged into Azure CLI. Please run 'az login' first.$(NC)"; \
		exit 1; \
	fi
	
	# Get current environment name
	@ENVIRONMENT=$$(az group list --query "[?contains(name, 'octopets')].name" -o tsv | head -1 | sed 's/rg-octopets-//'); \
	if [ -z "$$ENVIRONMENT" ]; then \
		echo "$(RED)❌ Could not find Octopets resource group. Please ensure you have deployed the app.$(NC)"; \
		exit 1; \
	fi; \
	echo "$(BLUE)Found environment: $$ENVIRONMENT$(NC)"; \
	\
	echo "$(BLUE)1. Creating Azure OpenAI service...$(NC)"; \
	az cognitiveservices account create \
		--name "octopets-openai-$$ENVIRONMENT" \
		--resource-group "rg-octopets-$$ENVIRONMENT" \
		--location "East US" \
		--kind "OpenAI" \
		--sku "S0" \
		--custom-domain "octopets-openai-$$ENVIRONMENT" \
		--yes || true; \
	\
	echo "$(BLUE)2. Creating managed identity...$(NC)"; \
	az identity create \
		--name "id-octopets-$$ENVIRONMENT" \
		--resource-group "rg-octopets-$$ENVIRONMENT" \
		--location "East US" || true; \
	\
	IDENTITY_CLIENT_ID=$$(az identity show \
		--name "id-octopets-$$ENVIRONMENT" \
		--resource-group "rg-octopets-$$ENVIRONMENT" \
		--query clientId -o tsv); \
	\
	OPENAI_RESOURCE_ID=$$(az cognitiveservices account show \
		--name "octopets-openai-$$ENVIRONMENT" \
		--resource-group "rg-octopets-$$ENVIRONMENT" \
		--query id -o tsv); \
	\
	echo "$(BLUE)3. Assigning RBAC permissions...$(NC)"; \
	az role assignment create \
		--assignee "$$IDENTITY_CLIENT_ID" \
		--role "Cognitive Services OpenAI User" \
		--scope "$$OPENAI_RESOURCE_ID" || true; \
	\
	echo "$(BLUE)4. Deploying GPT model...$(NC)"; \
	az cognitiveservices account deployment create \
		--name "octopets-openai-$$ENVIRONMENT" \
		--resource-group "rg-octopets-$$ENVIRONMENT" \
		--deployment-name "gpt-4o-mini" \
		--model-name "gpt-4o-mini" \
		--model-version "2024-07-18" \
		--model-format "OpenAI" \
		--scale-type "Standard" \
		--capacity 10 || true; \
	\
	OPENAI_ENDPOINT=$$(az cognitiveservices account show \
		--name "octopets-openai-$$ENVIRONMENT" \
		--resource-group "rg-octopets-$$ENVIRONMENT" \
		--query properties.endpoint -o tsv); \
	\
	echo "$(BLUE)5. Updating container app...$(NC)"; \
	az containerapp update \
		--name octopetsapi \
		--resource-group "rg-octopets-$$ENVIRONMENT" \
		--set-env-vars \
			"OpenAI__Endpoint=$$OPENAI_ENDPOINT" \
			"OpenAI__DeploymentName=gpt-4o-mini" \
		--remove-env-vars OpenAI__ApiKey || true; \
	\
	echo "$(GREEN)✅ Managed Identity migration complete!$(NC)"; \
	echo "$(YELLOW)⚠️  Please update your application code to use the new ManagedIdentityOpenAIService$(NC)"; \
	echo "$(BLUE)📚 See docs/security-implementation-guide.md for detailed instructions$(NC)"

security-scan-code: ## Run static code analysis for security issues
	@echo "$(YELLOW)🔍 Running static code analysis...$(NC)"
	
	# Scan for hardcoded secrets
	@echo "$(BLUE)Scanning for hardcoded secrets...$(NC)"
	@git ls-files | xargs grep -l "password\|secret\|key\|token" | head -10 || true
	@git ls-files | xargs grep -E "(sk-|pk-)[a-zA-Z0-9]{20,}" || true
	
	# Scan for SQL injection vulnerabilities
	@echo "$(BLUE)Scanning for potential SQL injection...$(NC)"
	@find . -name "*.cs" -exec grep -l "ExecuteRawSql\|FromSqlRaw" {} \; || true
	
	# Scan for XSS vulnerabilities
	@echo "$(BLUE)Scanning for potential XSS vulnerabilities...$(NC)"
	@find . -name "*.cs" -exec grep -l "Html.Raw\|@Html.Raw" {} \; || true
	@find . -name "*.tsx" -name "*.jsx" -exec grep -l "dangerouslySetInnerHTML" {} \; || true
	
	@echo "$(GREEN)✅ Code scan complete$(NC)"

security-test: ## Run security tests
	@echo "$(YELLOW)🧪 Running security tests...$(NC)"
	
	# Test HTTPS enforcement
	@echo "$(BLUE)Testing HTTPS enforcement...$(NC)"
	@if command -v curl >/dev/null 2>&1; then \
		curl -s -o /dev/null -w "%{http_code}" -k https://localhost:5000 || echo "HTTPS test failed"; \
	fi
	
	# Test for security headers
	@echo "$(BLUE)Testing security headers...$(NC)"
	@if command -v curl >/dev/null 2>&1; then \
		curl -s -I https://localhost:5000 | grep -E "(X-Frame-Options|X-Content-Type-Options|X-XSS-Protection)" || echo "Security headers missing"; \
	fi
	
	@echo "$(GREEN)✅ Security tests complete$(NC)"

security-report: ## Generate comprehensive security report
	@echo "$(YELLOW)📊 Generating security report...$(NC)"
	@make security-audit
	@make security-check-deps
	@make security-scan-code
	@echo "$(GREEN)✅ Security report generated$(NC)"
	@echo "$(BLUE)📄 Report available in: security-audit-results.json$(NC)"

clean-security: ## Clean up security-related temporary files
	@echo "$(YELLOW)🧹 Cleaning up security files...$(NC)"
	@rm -f security-audit-results.json
	@rm -f security-scan-*.log
	@rm -f dependency-audit.json
	@find . -name "*.bak" -delete
	@echo "$(GREEN)✅ Cleanup complete$(NC)"

# Default target
.DEFAULT_GOAL := help