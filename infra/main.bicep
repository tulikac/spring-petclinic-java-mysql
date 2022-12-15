targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param appName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param mySQLServerName string = ''
param mySQLServerAdminName string = 'petclinic'
@secure()
param mySQLServerAdminPassword string
param mySQLDatabaseName string = 'petclinic'
param keyVaultName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''

@description('Id of the user or app to assign application roles')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'B1'
    }
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

// The application database server
module mySQLServer './core/database/mysql/mysql-server.bicep' = {
  name: 'mysql-server'
  scope: rg
  params: {
    name: !empty(mySQLServerName) ? mySQLServerName : '${abbrs.dBforMySQLServers}${resourceToken}'
    location: location
    tags: tags
    adminName: mySQLServerAdminName
    adminPassword: mySQLServerAdminPassword
    keyVaultName: keyVault.outputs.name
  }
}

// The application database
module mySQLDatabase './core/database/mysql/mysql-db.bicep' = {
  name: 'mysql-database'
  scope: rg
  params: {
    databaseName: !empty(mySQLDatabaseName) ? mySQLDatabaseName : 'petclinic'
    serverName: mySQLServer.outputs.name
  }
}

// The application backend
module app './app/app.bicep' = {
  name: 'app'
  scope: rg
  params: {
    name: !empty(appName) ? appName : '${abbrs.webSitesAppService}petclinic-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    appSettings: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: monitoring.outputs.applicationInsightsConnectionString
      AZURE_KEY_VAULT_ENDPOINT: keyVault.outputs.endpoint
      SPRING_PROFILES_ACTIVE: 'azure,mysql'
      MYSQL_URL: mySQLDatabase.outputs.endpoint
      MYSQL_USER: mySQLServerAdminName
    }
  }
}

// Give the API access to KeyVault
module appKeyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'app-keyvault-access'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: app.outputs.APP_IDENTITY_PRINCIPAL_ID
  }
}

// Data outputs
output MYSQL_URL string = mySQLDatabase.outputs.endpoint
output MYSQL_USER string = mySQLServerAdminName

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SPRING_PROFILES_ACTIVE string = 'azure,mysql'
