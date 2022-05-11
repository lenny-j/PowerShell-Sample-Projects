# Public Cleared
# Last Update Sep 14, 21

# List of EXPECTED Values coming from the workflow
#Defaults
${activityInput.target_midserver}
${activityInput.vm_template_sys_id} # NEEDEDEDEDEDED for creds parsing : D
$domainShortname # Staged in PRE--PROCESSING, so it's a native Pwsh Var && Not used interactivly
$domainAdminUsername # Staged in PRE--PROCESSING, so it's a native Pwsh Var && Not used interactivly
$domain_pass # --> AS Session Native Var - from Pre-Processing

#This Script
${activityInput.vcenter_server}
${activityInput.servername}
${activityInput.disk_inv_from_clone}
${activityInput.desired_disks_to_add}


# MUST USE SINGLE QUOTEs Here 

$DisksToAddRawSrc = '${activityInput.desired_disks_to_add}'
$DiskInvFrCloneRawSrc = '${activityInput.disk_inv_from_clone}'


[ARRAY]$Desired_Disk_InvARRAY = $DisksToAddRawSrc | ConvertFrom-JSON
# Parse the incoming disk_inv_from_clone; this ALLOWS me to use -> $DiskInvFrCloneARRY.count
$ClonedInvSrc = $DiskInvFrCloneRawSrc | ConvertFrom-Json
[ARRAY]$DiskInvFrCloneARRAY = $ClonedInvSrc.disk_inv_from_clone
if ( (($Desired_Disk_InvARRAY.count).GetType().Name -ne "Int32") -or (($DiskInvFrCloneARRAY.count).GetType().Name -ne "Int32") ) {
    JSONReturn -StatusCode 1 -ResponseBody PROBLEM...
    exit
}
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

# Initialize PowerCLI
$ForceSilence = & powershell.exe -command 'Import-Module VMware.VimAutomation.Cis.Core;Set-PowerCliConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false'
$VCModLoad = Get-Module -ListAvailable VMWare.Vim* | Import-Module | Out-Null
# This - is prob. not needed - as the split is happening elsewhere in the Orch. workflow
if ("${activityInput.vcenter_server}" -match "@") {
    $vCenterSERVER = ("${activityInput.vcenter_server}" -split "@")[1]
}
else { $vCenterSERVER = "${activityInput.vcenter_server}" }

# Open Connection
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false -ErrorAction Stop | Out-Null
$VCMgtConn = Connect-VIServer $vCenterSERVER -Credential $cred -ErrorAction Stop
# Start - the business
try {
    
    $vmObject = get-vm ${activityInput.servername} -Erroraction stop
    $CURRENT_disks = Get-HardDisk -VM $vmObject -ErrorAction Stop

    if ($CURRENT_disks.Count -lt 1) {
        # That's odd - we don't have any disk hardware? Send it back !!
        JSONReturn -StatusCode 1 -ResponseBody "Query for current disk inventory did not appear to return any results. Please confirm at least an OS disk is present." -ErrorDetails "Initial disk inventory did not appear to return any results. Please confirm at least an OS disk is present."
        exit
    }

}
catch {
    # fetch call(s) didn't work
    [STRING]$errTxt = $Error[0].exception.message
    [STRING]$ansTxt = "There was a problem trying to query current disk details: \n\n" + $errTxt
    JSONReturn -StatusCode 1 -ResponseBody $ansTxt -ErrorDetails $errTxt
    exit
}
# Case 1 - make new disks    
if ($CURRENT_disks.count -eq $DiskInvFrCloneARRAY.count) {


    try {

        foreach ($TgtNewDisk in $Desired_Disk_InvARRAY) {
            New-HardDisk -VM $vmObject -CapacityGB $TgtNewDisk.size -storageformat $TgtNewDisk.storageFormat -Erroraction stop | New-ScsiController -Type Paravirtual -Erroraction stop | Out-Null
        }

    }
    catch {
        # Problem when trying to ADD new disk hardware trying 
        [STRING]$errTxt = $Error[0].exception.message
        [STRING]$ansTxt = "There was a problem when trying to add new disk hardware: \n\n" + $errTxt
        JSONReturn -StatusCode 1 -ResponseBody $ansTxt -ErrorDetails $errTxt
        exit
    }
    # Once Complete - report and exit !
    JSONReturn -StatusCode 0 -ResponseBody "DONE"
    exit
}
if ($CURRENT_disks.count -eq ($DiskInvFrCloneARRAY.count + $Desired_Disk_InvARRAY.count)) {
    # Case 2 - nothing to do here
    # No Work Expected - report that - and END 
    JSONReturn -StatusCode 0 -ResponseBody "Disk hardware has already been added. This activity is complete"
    exit
}
if (($CURRENT_disks.count -gt $DiskInvFrCloneARRAY.count) -and ($CURRENT_disks.count -lt $Desired_Disk_InvARRAY.count + $DiskInvFrCloneARRAY.count)) {
    # case 3 - make someone fix it
    $curCount = $CURRENT_disks.count
    $desCount = ($Desired_Disk_InvARRAY.count + $DiskInvFrCloneARRAY.count)
    [STRING]$ansTxt = "The number of hard disks is unexpected. This REQUIRES manual remediation.\n\nCurrent disk count: " + $curCount + "\nDesired disk count: " + $desCount
    JSONReturn -StatusCode 1 -ResponseBody $ansTxt -ErrorDetails "The number of hard disks is unexpected."
    exit
}
# in all cases - exit
exit