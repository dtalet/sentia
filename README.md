# Sentia assessment #

## Definition: ##

Create a deployment script, using template and parameter files, to deploy below-listed items, in a secure manner, to the Azure subscription:

	1 - A Resource Group in West Europe

	2 - A Storage Account in the above created Resource Group, using encryption and an unique name, starting with the prefix 'sentia'

	3 - A Virtual Network in the above created Resource Group with three subnets, using 172.16.0.0/12 as the address prefix

	4 - Apply the following tags to the resource group: Environment='Test', Company='Sentia'

	5 - Create a policy definition using a template and parameter file, to restrict the resourcetypes to only allow: compute, network and storage resourcetypes

	6 - Assign the policy definition to the subscription and resource group you created previously


## Assumptions: ##

- A valid Azure *subscriptionID* is needed, where this assessment is to be deployed. Rights for creating all objects in this assessment are expected.

- The deployment is triggered with a powershell script. Installation and configuration of Azure powershell is expected. More details: *https://docs.microsoft.com/en-us/powershell/azure/install-azurerm-ps?view=azurermps-6.1.0*

- The default name for the Resource Group will be "Sentia". If a resource group with that name or other name provided already exists, that resource group will be used wherever it is located. If a resource group with that name or other name provided does not exist, it will be created in the default location "West Europe". This default name and the default location can be changed when executing the *deploy.ps1* file that triggers the deployment. More details below.

- There's no specification on the storage account SKU so *Standard_LRS* will be the default one. It can be changed in the deployment parameters file (*deployment-parameters.json*). Storage Account default name prefix "sentia" can also be changed in the same parameters file. This prefix is limited to 11 chars.

- Encryption at rest for any service (blob, file, table and queue) in Storage accounts using Microsoft Managed Keys is provided by default since August 2017. More details here: *https://azure.microsoft.com/es-es/blog/announcing-default-encryption-for-azure-blobs-files-table-and-queue-storage/*. 

- The *Virtual Network* name will be the same as the *Storage Account* name. Subnets will be named *Subnet-1*, *Subnet-2* and *Subnet-3* respectively. Subnets will be /24. Subnet names, subnet IP ranges and Virtual Network address prefix can be changed in the deployment parameters file (*deployment-parameters.json*). Valid names and CIDR values are expected.

- *Microsoft.Compute*, *Microsoft.Network* and *Microsoft.Storage* are Namespaces that contain resource providers and resource types. So all resource types within these Namespaces will be considered when applying the policy restriction.


## Start the deployment. ##

To accomplish the above assessment, the following files are necessary and must be on the same folder.

-   *deploy.ps1*	(the actual deployment launcher).
-	*deployment.json*	(the json definition of the deployment).
-	*deployment-parameters.json*	(the json parameters of the deployment).
-	*initiative-subscription.json*	(the json definition of the initiative policy applied to the subscription).
-	*initiative-resource-group.json*	(the json definition of the initiative policy applied to the resource group).
-	*initiative-parameters.json*	(the json parameter definition for both initiatives).
-	*initiative-value-list.json*	(the json values for both initiatives).
-	*start.bat* (optional)	(a Windows batch file to trigger the deployment).



Deployment can be launched executing in an elevated powershell console with administrator rights: 

		.\deploy.ps1 <subscriptionID>

Also it can be triggered from a Windows admin command prompt: 

		start.bat (previously modified to include <subscriptionID>) 


*deploy.ps1* can be executed with the following parameters:

- *subscriptionId* (mandatory). The Azure Subscription ID in the format: *xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx*

- *resourceGroupName* (optional). Defaults to "Sentia".

- *resourceGroupLocation* (optional). Defaults to "westeurope".

- *deploymentName* (optional). Defaults to "Deployment".

- *templateFilePath* (optional). Defaults to "deployment.json".

- *parametersFilePath* (optional). Defaults to "deployment-parameters.json".


		Example: .\deploy.ps1 <subscriptionID> newrg uksouth mydeploy deployment.json deployment-parameters.json 


## Files description. ##

- *deploy.ps1* is a powershell script file. (It is commented inline). This file creates the resource group (point 1 of the assessment), creates and applies two initiatives (policy sets) that handle points 4, 5 and 6 of the assessment.

- *deployment.json* and *deployment-parameters.json* are standard Azure json deployment files. These files contain the parameters, variables and resources (*storage account* and *virtual network*) that form the deployment itself (points 2 and 3 of the assessment).

- *initiative-subscription.json* is the json definition of the initiative policy applied to the subscription. It contains 2 built-in policies:

	- *Allowed resource types* (that restricts allowed resource types through and array parameter 'listOfResourceTypesAllowed')
	- *Apply tag and its default value to resource groups* (that appends missing required tags to a resource group through string parameters 'tagName' and 'tagValue' )

	**This second policy is repeated because two different tags are required to be applied to the resource group in the assessment.*

	**This second policy does not enforce, other tags can coexist.*


- *initiative-resource-group.json* is the json definition of the initiative policy applied to the resource group. It contains 2 built-in policies:

	- *Allowed resource types* (that restricts allowed resource types through and array parameter 'listOfResourceTypesAllowed')
	- *Apply tag and its default value* (that appends the same tags from the resource group to its resources through string parameters 'tagName' and 'tagValue' )

	**This second policy is not required in the assessment but i thought it would be handy :).*
 
	**This second policy is repeated because two different tags are required to be applied to the resource group in the assessment, so they must be inherited in the resources within it.*

	**This second policy does not enforce, other tags can coexist.*

- *initiative-parameters.json* is the json parameter definition for both initiatives

- *initiative-value-list.json* contains the actual values used by both initiatives when assigning them.

	To gather all resource types for the above commented resource providers i have used these powershell commands:

		(Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Compute).ResourceTypes.ResourceTypeName
		(Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Network).ResourceTypes.ResourceTypeName
		(Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Storage).ResourceTypes.ResourceTypeName  


if other resource types were required to be allowed, it is enough to include them in the *Values* array named RESOURCETYPESALLOWED inside the *initiative-value-list.json* file.


if other tags were required to include in the resource group, new copies of the built-in *Apply tag and its default value to resource groups* policy must be included in the *initiative-subscription.json* file with this format:

	{        
        "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/49c88fc8-6fd1-46fd-a676-f12d1d3a4c71",
        "parameters": {
            "tagName": {
                "value": "[parameters('TAGNAMEx')]"              
            },
            "tagValue": {
                "value": "[parameters('TAGVALUEx')]"              
            }
        }
     }

replacing the x in TAGNAMEx / TAGVALUEx with the next corresponding number.


In the case for new tags for the resources in the resource group, new copies of the built-in *Apply tag and its default value* policy must be included in the *initiative-resource-group.json* file with this format:

	{        
        "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/2a0e14a6-b0a6-4fab-991a-187a4f81c498",
        "parameters": {
            "tagName": {
                "value": "[parameters('TAGNAMEx')]"              
            },
            "tagValue": {
                "value": "[parameters('TAGVALUEx')]"              
            }
        }
     }

replacing the x in TAGNAMEx / TAGVALUEx with the next corresponding number.


For both of them, these parameters must be added in the *initiative-parameters.json* file.

	"TAGNAMEx": {
       "type": "String",
       "metadata": {
          "displayName": "tag Name"           
       }
    },

    "TAGVALUEx": {
       "type": "String",
       "metadata": {
          "displayName": "tag Value"           
       }
    }
  

And finally, desired new tag values must be added in the *initiative-value-list.json* file

	"TAGNAMEx": {
      "value": "Department"
    },

    "TAGVALUEx": {
      "value": "IT"      
    }



## Time Log. ##


To tell you the truth i just don't know exactly the time spent on every step of this assessment, i changed things one time and another until i felt comfortable with the results. I would say i have been working for 3 complete working days (8 hours each). I have never worked with policies and initiatives before so most of the time was spent on that. I also changed the way tags were applied to leverage policies to make it more flexible. 

