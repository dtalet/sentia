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

 [hashtable]
 $tags = @{Environment="Test";Company="Sentia"},

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

Import-Module -Name AzureRM


$ErrorActionPreference = "Stop"

# sign in
Write-Host "Logging in...";
Login-AzureRmAccount;

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.network","microsoft.storage","microsoft.compute");
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
    Write-Host "Resource group '$resourceGroupName' does not exist.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation' and settings tags...";
    $resourceGroup = New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation -Tag $tags
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
    
    Write-Host "Enforcing tags to existing resource group...";
    Set-AzureRmResourceGroup -Name $resourceGroupName -Tag $tags
    
}


# Start the deployment
Write-Host "Starting deployment...";

Write-Host "Setting deployment name...";
$deploymentName=$deploymentName + "_" + (get-date).ToString("yyyyMMddHHmmss")

if(Test-Path $parametersFilePath) {
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
} else {
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath;
}



Write-Host "Enforcing tags from resource group to resources...";

foreach ($g in $resourceGroup)
{
    Get-AzureRmResource -ResourceGroupName $g.ResourceGroupName | ForEach-Object {Set-AzureRmResource -ResourceId $_.ResourceId -Tag $g.Tags -Force}
}




$policydefinitions = "initiative.json"
$policysetparameters = "initiative_parameters.json"

#(Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Compute).ResourceTypes.ResourceTypeName
#(Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Network).ResourceTypes.ResourceTypeName
#(Get-AzureRmResourceProvider -ProviderNamespace Microsoft.Storage).ResourceTypes.ResourceTypeName

$listofallowedresourcetypes = "listOfAllowedResourceTypes.json"

Write-Host "Creating initiative policy set...";
$policyset= New-AzureRmPolicySetDefinition -Name "resource-types-allowed" -DisplayName "Allowed Resource Types" -Description "This policyset restricts the resource types allowed" -PolicyDefinition $policydefinitions -Parameter $policysetparameters

Write-Host "Assigning initiative policy set to subscription...";
New-AzureRmPolicyAssignment -PolicySetDefinition $policyset -Name "allowed-resource-types-subscription-assigment" -Description "This policy assignment restricts the resource types to only allow: compute, network and storage resource types" -Scope /subscriptions/$subscriptionId -PolicyParameter $listofallowedresourcetypes

Write-Host "Assigning initiative policy set to resource group...";
New-AzureRmPolicyAssignment -PolicySetDefinition $policyset -Name "allowed-resource-types-resourcegroup-assignment" -Description "This policy assignment restricts the resource types to only allow: compute, network and storage resource types" -Scope $resourceGroup.ResourceId -PolicyParameter $listofallowedresourcetypes


