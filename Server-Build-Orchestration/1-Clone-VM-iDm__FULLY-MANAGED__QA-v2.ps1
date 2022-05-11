# Public Cleared
# Code Copy for QA Custom Activity '' Last Update Aug. 18, 21
# originally sourced from 'Clone-VM-iDm__FULLY-MANAGED__v2.ps1'

#:server identity & config info
${activityInput.vcenter_server} = "<VCENTER HOST>"
${activityInput.servername} = "<TARGET SERVER>"
${activityInput.os} = "Windows 2016 Standard"
${activityInput.patchwave_ad_group} = "<AD GROUP>" # Expected as a DN Value
${activityInput.cust_spec} = "Windows 2020" # for some basic config settings - APPLIED within vCenter; sourced fr VM Profiles Table as [STRING]
#:server STORAGE Related & config
${activityInput.cluster} = "<>"
${activityInput.array} = "<>"
${activityInput.DSfncode} = "<>" # This is DataStore Function Code
${activityInput.storage_format} = "thin"  # This is a new one !! Thin -or- Thick provision 
${activityInput.thisRITMNumber} = ""
#:tha 'PRE-PROC' Pwsh Natives
$vm_template_name = "2016-tmpl-nonprod" # Staged in PRE--PROCESSING, so it's a native Pwsh Var
$domainShortname # Staged in PRE--PROCESSING, so it's a native Pwsh Var && Not used interactivly
$domainAdminUsername # Staged in PRE--PROCESSING, so it's a native Pwsh Var && Not used interactivly
$domain_pass # Staged in PRE--PROCESSING, so it's a native Pwsh Var && Not used interactivly

function JSONReturn {
    param (
        [Parameter(Mandatory = $true)]
        [STRING]$StatusCode,
        [Parameter(Mandatory = $true)]
        $ResponseBody,
        [Parameter(Mandatory = $false)]
        [STRING]$ErrorDetails
    )
    $theResults = @{status_code = $StatusCode; output = $ResponseBody; error_details = $ErrorDetails }
    $theResultsJSON = $theResults | ConvertTo-Json -Depth 10
    Return $theResultsJSON
}
$secure_pass = ConvertTo-SecureString -String $domain_pass -AsPlainText -Force 
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "$domainShortname\$domainAdminUsername", $secure_pass
$ForceSilence = & powershell.exe -command 'Import-Module VMware.VimAutomation.Cis.Core;Set-PowerCliConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false'
$VCModLoad = Get-Module -ListAvailable VMWare.Vim* | Import-Module | Out-Null
$vmsite = "${activityInput.servername}".substring(0, 5)
if ("${activityInput.os}" -like '*LINUX*') {
    $patch_wave = 'UNIX' + '-' + $vmsite
}
elseif (($vmsite -eq '<SITE1>') -or ($vmsite -eq '<SITE2>')) {
    $patch_wave = 'Staging'
}
else {
    $patch_wave = "${activityInput.patchwave_ad_group}".split(",")[0]
    $patch_wave = $patch_wave.TrimStart("CN=WSUS")
    $patch_wave = $patch_wave.TrimStart("-")
}
if ("${activityInput.vcenter_server}" -match "@") {
    $vCenterSERVER = ("${activityInput.vcenter_server}" -split "@")[1]
}
else { $vCenterSERVER = "${activityInput.vcenter_server}" }
try {
    Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false -ErrorAction Stop | Out-Null
    $VCMgtConn = Connect-VIServer $vCenterSERVER -Credential $cred -ErrorAction Stop
    $datastore = ""
    $datastore = Get-DatastoreCluster "${activityInput.cluster}_${activityInput.array}_${activityInput.DSfncode}_SC" | Get-Datastore | Sort-Object FreeSpaceGB -Descending | Select-Object -First 1
    if (($datastore.count -ne 1) -or (($datastore.GetType()).name -ne "VmfsDatastoreImpl")) {
        [STRING]$datastoreToStr = ""
        if ($datastore -ne "") { $datastoreToStr = $datastore | Out-String }
        $jsonBodyTxt = @{'message' = "There was a problem trying to locate the correct datastore\n\nThis was the response from vCenter (if any): \n\n $datastoreToStr" } # Used to add a .message child element
        JSONReturn -StatusCode "1" -ResponseBody $jsonBodyTxt -ErrorDetails $datastoreToStr
        exit
    }
    try {
        $GuestExistsCheck = get-vm -Name "${activityInput.servername}" -ErrorAction Stop
    } 
    catch {
        if ($Error[0].Exception.Message -notmatch "not found") {
            $jsonBodyTxt = @{'message' = "There was a problem trying to search vCenter to see if the server already exists\n\n " + $Error[0].Exception.Message } # Used to add a .message child element
            JSONReturn -StatusCode "1" -ResponseBody $jsonBodyTxt -ErrorDetails $Error[0].Exception.Message
            Exit
        }
    }
    if ($GuestExistsCheck.name -eq "${activityInput.servername}") {
        if ($GuestExistsCheck.notes -match "${activityInput.thisRITMNumber}") {
            $ProvisionRespObj = $GuestExistsCheck
        }
        else {
            $jsonBodyTxt = @{'message' = "An EXISTING VM was found - but was NOT created by this request. Please verify servername" } # Used to add a .message child element
            JSONReturn -StatusCode "1" -ResponseBody "An EXISTING VM was found - but was NOT created by this request. Please verify servername." -ErrorDetails "VM Already Exists"
            exit
        }
    }
    else {
        $DestFolderCheck = Get-Folder -Name $patch_wave -ErrorAction Stop
        $ProvisionRespCALL = new-vm -name "${activityInput.servername}" -location "$patch_wave" -resourcepool "${activityInput.cluster}" -datastore "$datastore" -template "$vm_template_name" -OSCustomizationspec "${activityInput.cust_spec}" -diskstorageformat "${activityInput.storage_format}" -Notes "${activityInput.thisRITMNumber}" -ErrorAction Stop
        $ProvisionRespObj = get-vm -Name $ProvisionRespCALL.name -ErrorAction Stop
    }
    $MACAddrData = get-networkadapter -vm $ProvisionRespObj -ErrorAction STOP | Select-Object -ExpandProperty MACAddress
}
catch {
    $jsonBodyTxt = @{'message' = "There was a problem trying to provision ${activityInput.servername}\n\n" + $Error[0].exception.message } # Used to add a .message child element
    JSONReturn -StatusCode "1" -ResponseBody $jsonBodyTxt -ErrorDetails $Error[0].exception.message
    exit
}
$GracefulClose = Disconnect-viserver * -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
$VMResultsObj = ($ProvisionRespObj | Select-Object PersistentID)# we can DROP the out-string here if needed - to remove the excessive line feeds
$Body = @{'VMGuid' = $VMResultsObj.PersistentId; 'MacAddress' = $MACAddrData; 'PwshRuntimeServer' = ($ENV:COMPUTERNAME) }
JSONReturn -StatusCode "0" -ResponseBody $Body
exit