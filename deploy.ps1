<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

#>

param(
 [Parameter(Mandatory=$True)]
 [string]
 $subscriptionId,   # The subscription id where the template will be deployed.

 [string]
 $resourceGroupName = "Sentia",  # The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 [string]
 $resourceGroupLocation = "westeurope",     # resource group location.

 [string]
 $deploymentName = "Deployment",    # The deployment name.

 [string]
 $templateFilePath = "deployment.json",     # path to the template file.

 [string]
 $parametersFilePath = "deployment-parameters.json"     # path to the parameters file.
)



# Function that registers resource providers

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

# Import powershell required module

Import-Module -Name AzureRM         


# Determines how PowerShell responds to a non-terminating error. Displays the error message and stops executing.

$ErrorActionPreference = "Stop"


# sign in
Write-Host "Logging in...";
Login-AzureRmAccount;


# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId;



# Register resource providers. I have considered the 4 related to this assessment.

$resourceProviders = @("microsoft.network","microsoft.storage","microsoft.compute",'microsoft.policyinsights');
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}


# Variables for the initiative files.

$initiativesubscription = "initiative-subscription.json"
$initiativeresourcegroup = "initiative-resource-group.json"
$initiativeparameters = "initiative-parameters.json"
$initiativevaluelist = "initiative-value-list.json"


# Creating initiative policy set for the subscription

Write-Host "Creating initiative policy set for the subscription...";
$policyset= New-AzureRmPolicySetDefinition -Name "initiative-subscription" -DisplayName "Allowed Resource Types and tag assignment (subscription)" -Description "This policyset restricts the resource types allowed and assigns tags at the subscription level" -PolicyDefinition $initiativesubscription -Parameter $initiativeparameters


# Assigning initiative policy set to the subscription

Write-Host "Assigning initiative policy set to the subscription...";
New-AzureRmPolicyAssignment -PolicySetDefinition $policyset -Name "initiative-subscription-assignment" -Description "This policy assignment restricts the resource types to only allow compute, network and storage resource types and assigns tags at the subscription level" -Scope /subscriptions/$subscriptionId -PolicyParameter $initiativevaluelist



#Create or check for existing resource group

$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup) 
{
    Write-Host "Resource group '$resourceGroupName' does not exist.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation' ...";    
    $resourceGroup = New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
    
}


# Creating initiative policy set for the resource group

Write-Host "Creating initiative policy set for the resource group...";
$policyset= New-AzureRmPolicySetDefinition -Name "initiative-resource-group" -DisplayName "Allowed Resource Types and tag assignment (resource group)" -Description "This policyset restricts the resource types allowed and assigns tags at the resource group level" -PolicyDefinition $initiativeresourcegroup -Parameter $initiativeparameters


# Assigning initiative policy set to the resource group

Write-Host "Assigning initiative policy set to the resource group...";
New-AzureRmPolicyAssignment -PolicySetDefinition $policyset -Name "initiative-resource-group-assignment" -Description "This policy assignment restricts the resource types to only allow compute, network and storage resource types and assigns tags at the resource group level" -Scope $resourceGroup.ResourceId -PolicyParameter $initiativevaluelist


# Start the deployment
Write-Host "Starting deployment...";

# Setting the deployment name append with a time mark to keep track of every deployment.

Write-Host "Setting deployment name...";
$deploymentName=$deploymentName + "_" + (get-date).ToString("yyyyMMddHHmmss")


# Execute the deployment
if(Test-Path $parametersFilePath) {
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
} else {
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath;
}





