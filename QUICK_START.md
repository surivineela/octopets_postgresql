# 🚀 Quick Start - Deploy Octopets to Azure

## 📋 One-Command Deployment

Ready to deploy? Follow these steps:

### 1. Prerequisites Check

```powershell
# Verify Azure CLI is installed and logged in
az --version
az account show

# If not logged in:
az login
```

### 2. Deploy Everything

```powershell
# Navigate to your project directory
cd c:\Users\surivineela\Documents\octopets-new

# Run the deployment script
.\deploy-azure.ps1
```

**That's it!** The script will:
- ✅ Create all Azure resources in Sweden Central
- ✅ Set up PostgreSQL database with sample data
- ✅ Deploy backend API with OpenAI integration
- ✅ Deploy React frontend
- ✅ Configure CI/CD pipelines
- ✅ Set up monitoring and logging

### 3. What You'll Get

After ~10-15 minutes, you'll have:

- **Frontend**: https://octopets-prod-web.azurestaticapps.net
- **API**: https://octopets-prod-api.azurecontainerapps.io
- **API Docs**: https://octopets-prod-api.azurecontainerapps.io/scalar/v1
- **Monitoring**: Azure Application Insights dashboard

### 4. Configure OpenAI (Optional)

Add your OpenAI API key for pet analysis features:

1. Get your key from https://platform.openai.com/api-keys
2. Go to Azure Portal → Key Vault → octopets-prod-kv
3. Add secret: `OpenAIApiKey` with your key value

### 5. Set Up CI/CD (Optional)

For automatic deployments on code changes:

1. Go to GitHub repository settings → Secrets
2. Add the secrets displayed after deployment
3. Push code changes to trigger automatic deployments

## 🎯 What's Deployed

### Infrastructure (Sweden Central)
- **PostgreSQL 15** - Production database with sample venues
- **Container Apps** - Scalable backend API hosting
- **Key Vault** - Secure secrets management
- **Application Insights** - Performance monitoring

### Frontend (West Europe)
- **Static Web Apps** - React application with CDN
- **Custom domain ready** - HTTPS with SSL certificates
- **Global CDN** - Fast loading worldwide

### Features
- 🏨 **Venue Discovery** - Browse pet-friendly locations
- ⭐ **Reviews System** - Rate and review venues
- 🤖 **AI Pet Analysis** - OpenAI-powered pet insights
- 📱 **Responsive Design** - Works on all devices
- 🔐 **Secure** - HTTPS, CORS, and proper authentication

## 📊 Costs

**Estimated monthly cost**: $30-60 USD

- PostgreSQL: ~$15
- Container Apps: ~$10-30 (scales with usage)
- Static Web Apps: ~$9
- Monitoring & Storage: ~$5

## 🆘 Need Help?

1. **Deployment issues**: Check the detailed `DEPLOYMENT_GUIDE.md`
2. **Application errors**: Monitor through Application Insights
3. **Database issues**: Check Azure Portal → PostgreSQL server
4. **Frontend issues**: Check Static Web Apps logs in Azure Portal

---

**Ready to start?** Run `.\deploy-azure.ps1` and your Octopets application will be live in minutes! 🎉