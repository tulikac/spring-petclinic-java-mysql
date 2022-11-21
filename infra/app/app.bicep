param name string
param location string = resourceGroup().location
param tags object = {}

param allowedOrigins array = []
param appCommandLine string = ''
param applicationInsightsName string = ''
param appServicePlanId string
param appSettings object = {}
param serviceName string = 'app'

module app 'appservice.bicep' = {
  name: '${name}-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    allowedOrigins: allowedOrigins
    appCommandLine: appCommandLine
    applicationInsightsName: applicationInsightsName
    appServicePlanId: appServicePlanId
    appSettings: appSettings
    runtimeName: 'java'
    runtimeVersion: '17-java17'
    scmDoBuildDuringDeployment: true
  }
}

output APP_IDENTITY_PRINCIPAL_ID string = app.outputs.identityPrincipalId
output APP_NAME string = app.outputs.name
output APP_URI string = app.outputs.uri
