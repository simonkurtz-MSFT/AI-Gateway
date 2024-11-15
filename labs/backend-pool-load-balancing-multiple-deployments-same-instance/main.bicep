@description('List of Mock webapp names used to simulate OpenAI behavior.')
param mockWebApps array = []

@description('The name of the OpenAI mock backend pool')
param mockBackendPoolName string = 'openai-backend-pool'

@description('The description of the OpenAI mock backend pool')
param mockBackendPoolDescription string = 'Load balancer for multiple OpenAI Mocking endpoints'

@description('List of OpenAI resources to create. Add pairs of name and location.')
param openAIConfig array = []

@description('Deployment Name')
param openAIDeploymentName string

@description('Azure OpenAI Sku')
@allowed([
  'S0'
])
param openAISku string = 'S0'

@description('Model Name')
param openAIModelName string

@description('Model Version2')
param openAIModelVersion2 string

@description('Model Name2')
param openAIModelName2 string

@description('Model Version')
param openAIModelVersion string

@description('Deployment Name2')
param openAIDeploymentName2 string

@description('Model Capacity')
param openAIModelCapacity int = 20

@description('The name of the API Management resource')
param apimResourceName string

@description('Location for the APIM resource')
param apimResourceLocation string = resourceGroup().location

@description('The pricing tier of this API Management service')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Basicv2'
  'Standard'
  'Standardv2'
  'Premium'
])
param apimSku string = 'Consumption'

@description('The instance size of this API Management service.')
@allowed([
  0
  1
  2
])
param apimSkuCount int = 1

@description('The email address of the owner of the service')
param apimPublisherEmail string = 'noreply@microsoft.com'

@description('The name of the owner of the service')
param apimPublisherName string = 'Microsoft'

@description('The name of the APIM API for OpenAI API')
param openAIAPIName string = 'openai'

@description('The relative path of the APIM API for OpenAI API')
param openAIAPIPath string = 'openai'

@description('The display name of the APIM API for OpenAI API')
param openAIAPIDisplayName string = 'OpenAI'

@description('The description of the APIM API for OpenAI API')
param openAIAPIDescription string = 'Azure OpenAI API inferencing API'

@description('Full URL for the OpenAI API spec')
param openAIAPISpecURL string = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-02-01/inference.json'

@description('The name of the APIM Subscription for OpenAI API')
param openAISubscriptionName string = 'openai-subscription'

@description('The description of the APIM Subscription for OpenAI API')
param openAISubscriptionDescription string = 'OpenAI Subscription'

@description('The name of the OpenAI backend pool')
param openAIBackendPoolName string = 'openai-backend-pool'

@description('The description of the OpenAI backend pool')
param openAIBackendPoolDescription string = 'Load balancer for multiple OpenAI endpoints'

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

var indexedOpenAIConfig = [ for (config, i) in openAIConfig: {
    index: i
    name: config.name
    location: config.location
    priority: config.priority
    weight: config.weight
    deployments: config.deployments
    models: config.models
}]

var tmp = [ for config in indexedOpenAIConfig: map(config.deployments, (dep, i) => { name: config.name, location: config.location, priority: config.priority, weight: config.weight, deploymentName: dep, cognitiveServicesIndex: config.index }) ]
var foo = [ for config in indexedOpenAIConfig: map(config.models, (m, i) => { name: config.name, location: config.location, priority: config.priority, weight: config.weight, modelName: m.openai_model_name, modelVersion: m.openai_model_version, deploymentName: m.openai_deployment_name, cognitiveServicesIndex: config.index }) ]
var flattenedOpenAIConfig = flatten(tmp)
var flattenedOpenAIConfigFoo = flatten(foo)

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2021-10-01' = [for config in indexedOpenAIConfig: if(length(indexedOpenAIConfig) > 0) {
  name: '${config.name}-${resourceSuffix}'
  location: config.location
  sku: {
    name: openAISku
  }
  kind: 'OpenAI'
  properties: {
    apiProperties: {
      statisticsEnabled: false
    }
    customSubDomainName: toLower('${config.name}-${resourceSuffix}')
  }
}]

// Models to the same instance cannot be deployed in parallel. Hence, we deploy them sequentially by setting batchSize to 1: https://www.seifbassem.com/blogs/posts/tips-bicep-azureopenai-loop/
@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for (config, i) in flattenedOpenAIConfigFoo: if(length(flattenedOpenAIConfigFoo) > 0) {
    name: config.deploymentName
    parent: cognitiveServices[config.cognitiveServicesIndex]
    properties: {
      model: {
        format: 'OpenAI'
        name: config.modelName
        version: config.modelVersion
      }
    }
    sku: {
        name: 'Standard'
        capacity: openAIModelCapacity
    }
}]




// // Models to the same instance cannot be deployed in parallel. Hence, we deploy them sequentially by setting batchSize to 1.
// @batchSize(1)
// resource deployment2 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for (config, i) in indexedOpenAIConfig: if(length(indexedOpenAIConfig) > 0) {
//     name: openAIDeploymentName2
//     parent: cognitiveServices[i]
//     properties: {
//       model: {
//         format: 'OpenAI'
//         name: openAIModelName2
//         version: openAIModelVersion2
//       }
//     }
//     sku: {
//         name: 'Standard'
//         capacity: openAIModelCapacity
//     }
// }]








// resource apimService 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
//   name: '${apimResourceName}-${resourceSuffix}'
//   location: apimResourceLocation
//   sku: {
//     name: apimSku
//     capacity: (apimSku == 'Consumption') ? 0 : ((apimSku == 'Developer') ? 1 : apimSkuCount)
//   }
//   properties: {
//     publisherEmail: apimPublisherEmail
//     publisherName: apimPublisherName
//   }
//   identity: {
//     type: 'SystemAssigned'
//   }
// }

// var roleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
// resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in indexedOpenAIConfig: if(length(indexedOpenAIConfig) > 0) {
//     scope: cognitiveServices[i]
//     name: guid(subscription().id, resourceGroup().id, config.name, roleDefinitionID)
//     properties: {
//         roleDefinitionId: roleDefinitionID
//         principalId: apimService.identity.principalId
//         principalType: 'ServicePrincipal'
//     }
// }]

// resource api 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
//     name: openAIAPIName
//     parent: apimService
//     properties: {
//       apiType: 'http'
//       description: openAIAPIDescription
//       displayName: openAIAPIDisplayName
//       format: 'openapi-link'
//       path: openAIAPIPath
//       protocols: [
//         'https'
//       ]
//       subscriptionKeyParameterNames: {
//         header: 'api-key'
//         query: 'api-key'
//       }
//       subscriptionRequired: true
//       type: 'http'
//       value: openAIAPISpecURL
//     }
//   }

// resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
//   name: 'policy'
//   parent: api
//   properties: {
//     format: 'rawxml'
//     value: loadTextContent('policy.xml')
//   }
// }

// resource backendOpenAI 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = [for (config, i) in flattenedOpenAIConfig: if(length(flattenedOpenAIConfig) > 0) {
//   name: '${config.name}-${config.deploymentName}'
//   parent: apimService
//   properties: {
//     description: 'Azure OpenAI backend for ${config.name} with deployment ${config.deploymentName}'
//     //url: '${cognitiveServices[i].properties.endpoint}openai/${config.deploymentName}'
//     url: '${cognitiveServices[config.cognitiveServicesIndex].properties.endpoint}openai/${config.deploymentName}'
//     protocol: 'http'
//     circuitBreaker: {
//       rules: [
//         {
//           failureCondition: {
//             count: 1
//             errorReasons: [
//               'Server errors'
//             ]
//             interval: 'PT5M'
//             statusCodeRanges: [
//               {
//                 min: 429
//                 max: 429
//               }
//             ]
//           }
//           name: 'openAIBreakerRule'
//           tripDuration: 'PT1M'
//           acceptRetryAfter: true    // respects the Retry-After header
//         }
//       ]
//     }
//   }
// }]

// resource backendMock 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = [for (mock, i) in mockWebApps: if(length(indexedOpenAIConfig) == 0 && length(mockWebApps) > 0) {
//   name: mock.name
//   parent: apimService
//   properties: {
//     description: 'backend description'
//     url: '${mock.endpoint}/openai'
//     protocol: 'http'
//     circuitBreaker: {
//       rules: [
//         {
//           failureCondition: {
//             count: 3
//             errorReasons: [
//               'Server errors'
//             ]
//             interval: 'PT5M'
//             statusCodeRanges: [
//               {
//                 min: 429
//                 max: 429
//               }
//             ]
//           }
//           name: 'mockBreakerRule'
//           tripDuration: 'PT1M'
//           acceptRetryAfter: true    // respects the Retry-After header
//         }
//       ]
//     }
//   }
// }]

// resource backendPoolOpenAI 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = if(length(indexedOpenAIConfig) > 1) {
//   name: openAIBackendPoolName
//   parent: apimService
//   #disable-next-line BCP035 // suppress the false positive as protocol and url are not needed in the Pool type
//   properties: {
//     description: openAIBackendPoolDescription
//     type: 'Pool'
// //    protocol: 'http'  // the protocol is not needed in the Pool type
// //    url: '${cognitiveServices[0].properties.endpoint}/openai'   // the url is not needed in the Pool type
//     pool: {
//       services: [for (config, i) in indexedOpenAIConfig: {
//           id: '/backends/${backendOpenAI[i].name}'
//           priority: config.priority
//           weight: config.weight
//         }
//       ]
//     }
//   }
// }

// resource backendPoolMock 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = if(length(indexedOpenAIConfig) == 0 && length(mockWebApps) > 1) {
//   name: mockBackendPoolName
//   parent: apimService
//   #disable-next-line BCP035 // suppress the false positive as protocol and url are not needed in the Pool type
//   properties: {
//     description: mockBackendPoolDescription
//     type: 'Pool'
// //    protocol: 'http'  // the protocol is not needed in the Pool type
// //    url: '${mockWebApps[0].endpoint}/openai'   // the url is not needed in the Pool type
//     pool: {
//       services: [for (webApp, i) in mockWebApps: {
//           id: '/backends/${backendMock[i].name}'
//           priority: webApp.priority
//           weight: webApp.weight
//         }
//       ]
//     }
//   }
// }

// resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = {
//   name: openAISubscriptionName
//   parent: apimService
//   properties: {
//     allowTracing: true
//     displayName: openAISubscriptionDescription
//     scope: '/apis/${api.id}'
//     state: 'active'
//   }
// }

// output apimServiceId string = apimService.id

// output apimResourceGatewayURL string = apimService.properties.gatewayUrl

// #disable-next-line outputs-should-not-contain-secrets
// output apimSubscriptionKey string = apimSubscription.listSecrets().primaryKey