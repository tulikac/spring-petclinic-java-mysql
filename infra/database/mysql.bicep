param name string
param location string = resourceGroup().location
param tags object = {}

param databaseName string
param keyVaultName string
param mysqlAdminName string
param mysqlAdminPassKey string = 'AZURE-MYSQL-ADMIN-PASSWORD'

@secure()
param mysqlAdminPassword string

resource mysqlServer 'Microsoft.DBforMySQL/servers@2017-12-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    capacity: 2
    size: string(51200)
    family: 'Gen5'
  }
  properties: {
    createMode: 'Default'
    version: '5.7'
    administratorLogin: mysqlAdminName
    administratorLoginPassword: mysqlAdminPassword
    storageProfile: {
      storageMB: 51200
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    sslEnforcement: 'Disabled'
  }
}

resource database 'Microsoft.DBforMySQL/servers/databases@2017-12-01' = {
  parent: mysqlServer
  name: databaseName
  properties: {
    charset: 'utf8'
    collation: 'utf8_general_ci'
  }
}

resource firewallRule_all_azure_ips 'Microsoft.DBforMySQL/servers/firewallRules@2017-12-01' = {
  parent: mysqlServer
  name: 'AllowAzureIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource mysqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: mysqlAdminPassKey
  properties: {
    value: mysqlAdminPassword
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

output name string = mysqlServer.name
output mysqlAdminName string = '${mysqlAdminName}@${mysqlServer.name}'
output mysqlAdminPassUrl string = mysqlAdminPasswordSecret.properties.secretUri
output jdbcUrl string = 'jdbc:mysql://${mysqlServer.properties.fullyQualifiedDomainName}:3306/${databaseName}?useSSL=true&requireSSL=false'
output databaseName string = database.name
