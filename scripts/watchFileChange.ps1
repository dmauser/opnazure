$ProgressPreference = 'SilentlyContinue'
$ResourceGroup = 'webapprafa'
$StorageAccountName = 'storageaccountwebapba76'
$Location = 'CentralUS'
$ContainerName = 'test'

$StorageHT = @{
    ResourceGroupName = $ResourceGroup
    Name              = $StorageAccountName
    SkuName           = 'Standard_LRS'
    Location          =  $Location
}
#$StorageAccount = New-AzStorageAccount @StorageHT

$StorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName
$Context = $StorageAccount.Context
$Container = Get-AzStorageContainer -Context $Context -Container test

$global:Blob1HT = @{
    File             = 'C:\Projects\VSProjects\opnazure\bicep\uiFormDefinition.json'
    Container        = $Container.Name
    Blob             = "uiFormDefinition.json"
    Context          = $Context
    #StandardBlobTier = 'Hot'
}
#Set-AzStorageBlobContent @Blob1HT -confirm:$false -force

##################################################################

$folder = 'C:\Projects\VSProjects\opnazure\bicep'
$filter = 'uiFormDefinition.json'

#$fsw = New-Object IO.FileSystemWatcher $folder, $filter -Property @{IncludeSubdirectories = $false;NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'}
$fsw = New-Object IO.FileSystemWatcher $folder, $filter -Property @{IncludeSubdirectories = $false;NotifyFilter = [IO.NotifyFilters]'LastWrite'}
$global:eventTime = ""
Register-ObjectEvent $fsw Changed -SourceIdentifier FileChanged -Action {
    $name = $Event.SourceEventArgs.Name
    $changeType = $Event.SourceEventArgs.ChangeType
    $timeStamp = $Event.TimeGenerated

    if($global:eventTime.second -ne $Event.TimeGenerated.second){
        Write-Host "The file '$name' was $changeType at $timeStamp" -fore white
        Set-AzStorageBlobContent @Blob1HT -confirm:$false -force
    }
    $global:eventTime = $Event.TimeGenerated
}
#Unregister-Event FileChanged