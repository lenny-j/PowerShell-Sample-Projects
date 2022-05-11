# Public Cleared
# Last Update: Sep. 9, 2021

# Inputs & Vars
#Defaults
${activityInput.target_midserver}
${activityInput.vm_template_sys_id} ## TOOOOTALLY needed - for creds parsing !!
$domainShortname # Staged in PRE--PROCESSING, so it's a native Pwsh Var && Not used interactivly
$domainAdminUsername # Staged in PRE--PROCESSING, so it's a native Pwsh Var && Not used interactivly
$domain_pass # --> AS Session Native Var - from Pre-Processing
#This Script
${activityInput.vcenter_server} = "<VCENTER>"
${activityInput.servername} = "<TARGET SERVER>"

$secure_pass = ConvertTo-SecureString -String $domain_pass -AsPlainText -Force 
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "$domainShortname\$domainAdminUsername", $secure_pass
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
$ForceSilence = & powershell.exe -command 'Import-Module VMware.VimAutomation.Cis.Core;Set-PowerCliConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false'
$VCModLoad = Get-Module -ListAvailable VMWare.Vim* | Import-Module | Out-Null
if ("${activityInput.vcenter_server}" -match "@") {
    $vCenterSERVER = ("${activityInput.vcenter_server}" -split "@")[1]
}
else { $vCenterSERVER = "${activityInput.vcenter_server}" }
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false -ErrorAction Stop | Out-Null
$VCMgtConn = Connect-VIServer $vCenterSERVER -Credential $cred -ErrorAction Stop
try {
    $CURRENT_disks = @()
    $vmObject = get-vm ${activityInput.servername} -Erroraction stop
    $CURRENT_disks = Get-HardDisk -VM $vmObject -ErrorAction Stop
    if ($CURRENT_disks.Count -lt 1) {
        # That's odd - we don't have any disk hardware? Send it back !!
        JSONReturn -StatusCode 1 -ResponseBody "Initial disk inventory did not appear to return any results. Please confirm at least an OS disk is present." -ErrorDetails "Initial disk inventory did not appear to return any results. Please confirm at least an OS disk is present."
        exit
    }
}
catch {
    # fetch call(s) didn't work
    JSONReturn -StatusCode 1 -ResponseBody "There was a problem trying to query for initial disk inventory" -ErrorDetails $Error[0].exception.message
    exit
}

$srcCLoneDiskInvARRAY = @()
foreach ($Resource in $CURRENT_disks) {
    $srcCLoneDiskInvARRAY += @{"disk_uid" = $Resource.Uid; "storageFormat" = $Resource.storageformat.ToString(); "size" = $Resource.CapacityGB }
}
$GracefulClose = Disconnect-viserver * -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
JSONReturn -StatusCode 0 -ResponseBody @{disk_inv_from_clone = $srcCLoneDiskInvARRAY }
exit