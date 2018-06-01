<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER deploymentName
    The deployment name.

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

param(
 [Parameter(Mandatory=$True)]
 [string]
 $subscriptionId,

 [string]
 $resourceGroupName = "Sentia",

 [string]
 $resourceGroupLocation = "westeurope",

 [string]
 $resourceEnvironment = "Test",

 [string]
 $resourceCompany = "Sentia",

 [string]
 $deploymentName = "Deployment",

 [string]
 $templateFilePath = "deployment.json",

 [string]
 $parametersFilePath = "deployment_parameters.json"
)

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# sign in
Write-Host "Logging in...";
Login-AzureRmAccount;

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.network","microsoft.storage");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    $resourceGroup = New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation -Tag @{ Environment=$resourceEnvironment; Company=$resourceCompany }
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}


$deploymentName=$deploymentName + "_" + (get-date).ToString("dd-MM-yy-hh-mm-ss")

# Start the deployment
Write-Host "Starting deployment...";
if(Test-Path $parametersFilePath) {
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
} else {
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath;
}



$policydefinitions = "initiative.json"
$policysetparameters = "initiative_parameters.json"
$listofallowedresourcetypes = "listOfAllowedResourceTypes.json"

$policyset= New-AzureRmPolicySetDefinition -Name "resource-types-allowed" -DisplayName "Allowed Resource Types" -Description "This policy restricts the resource types to only allow: compute, network and storage resource types" -PolicyDefinition $policydefinitions -Parameter $policysetparameters
 
New-AzureRmPolicyAssignment -PolicySetDefinition $policyset -Name "allowed-resource-types-subscription-assigment" -Scope /subscriptions/$subscriptionId -PolicyParameter $listofallowedresourcetypes

New-AzureRmPolicyAssignment -PolicySetDefinition $policyset -Name "allowed-resource-types-resourcegroup-assignment" -Scope $resourceGroup.ResourceId -PolicyParameter $listofallowedresourcetypes 


