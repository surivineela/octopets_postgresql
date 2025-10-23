#!/bin/bash
# Manual Security Audit Trigger Script
# Run this to perform an immediate security assessment

echo "🔒 Octopets Security Audit Tool"
echo "==============================="
echo ""

# Check if we're in the right directory
if [ ! -f "Octopets.sln" ]; then
    echo "❌ Please run this script from the Octopets root directory"
    exit 1
fi

echo "🚀 Starting comprehensive security audit..."
echo ""

# Run the security audit
if [ -f ".github/scripts/security-audit.sh" ]; then
    chmod +x ./.github/scripts/security-audit.sh
    ./.github/scripts/security-audit.sh
else
    echo "❌ Security audit script not found. Please ensure .github/scripts/security-audit.sh exists."
    exit 1
fi

echo ""
echo "📊 Security audit complete!"
echo "📄 Results saved to: security-audit-results.json"
echo ""
echo "🔧 To apply automated fixes, run:"
echo "   make security-fix-auto"
echo ""
echo "🔄 To migrate to Managed Identity, run:"
echo "   make security-migrate-managed-identity"
echo ""
echo "📚 For detailed implementation guide, see:"
echo "   docs/security-implementation-guide.md"