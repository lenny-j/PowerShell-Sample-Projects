# Public Cleared
# Last Update Aug. 18, 21
#Defaults
${activityInput.target_midserver}
${activityInput.vm_template_sys_id}
$domainShortname # Staged in PRE--PROCESSING, so it's a native Pwsh Var && Not used interactivly
$domainAdminUsername # Staged in PRE--PROCESSING, so it's a native Pwsh Var && Not used interactivly
$domain_pass # --> AS Session Native Var - from Pre-Processing
#This Script
${activityInput.vcenter_server} = "<VCENTER>"
${activityInput.servername} = "<TARGET SERVER>" 
${activityInput.cpu} = "2"  ## RunScript Source: workflow.scratchpad.cpu = current.variables.vm_cpu;
${activityInput.ram} = "1024"  ## RunScript Source: workflow.scratchpad.ram = current.variables.vm_ram * 1024;
${activityInput.vlan} = "vLan<#>" # this is a test value - that  is assigned

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
try {
    Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false -ErrorAction Stop | Out-Null
    $VCMgtConn = Connect-VIServer $vCenterSERVER -Credential $cred -ErrorAction Stop
    $vmObjectcheck = get-vm ${activityInput.servername} -ErrorAction STOP
    if ($vmObjectcheck.count -ne 1) {
        $jsonBodyTxt = @{'message' = "Search for VM returned an unexpected number of VM objects of: " + $vmObjectcheck.count } # Used to add a .message child element
        JSONReturn -StatusCode "1" -ResponseBody $jsonBodyTxt
        exit
    }
}
catch {
    $jsonBodyTxt = @{'message' = "There was a problem trying to connect to vCenter -OR- could not find the Virtual Machine\n\n" + $Error[0].Exception.Message } # Used to add a .message child element
    JSONReturn -StatusCode "1" -ResponseBody $jsonBodyTxt -ErrorDetails $Error[0].Exception.Message
    exit
}
try {
    set-vm ${activityInput.servername} -NumCPU "${activityInput.cpu}" -MemoryMB "${activityInput.ram}" -Confirm:$False -ErrorAction Stop | Out-Null
}
catch {
    $jsonBodyTxt = @{'message' = "There was a problem trying to update CPU, and/or Memory for ${activityInput.servername} \n\n" + $Error[0].Exception.Message } # Used to add a .message child element
    JSONReturn -StatusCode "1" -ResponseBody $jsonBodyTxt -ErrorDetails $Error[0].Exception.Message
    exit
}
try {
    $vdportgroup = Get-VDPortgroup -Name "${activityInput.vlan}" -ErrorAction Stop
    get-networkadapter -vm ${activityInput.servername} -ErrorAction Stop | set-networkadapter -Portgroup $vdportgroup -confirm:$false -ErrorAction Stop | out-null
}
catch {
    $jsonBodyTxt = @{'message' = "There was a problem trying to update vLan for ${activityInput.servername} \n\n" + $Error[0].Exception.Message } # Used to add a .message child element
    JSONReturn -StatusCode "1" -ResponseBody $jsonBodyTxt -ErrorDetails $Error[0].Exception.Message
    exit
}
try {
    $confirmQryVMObj = get-vm ${activityInput.servername} -ErrorAction STOP
}
catch {
    $jsonBodyTxt = @{'message' = "There was a problem trying to confirm CPU, and/or Memory, or vLan for ${activityInput.servername}\n\n" + $Error[0].Exception.Message } # Used to add a .message child element
    JSONReturn -StatusCode "1" -ResponseBody $jsonBodyTxt -ErrorDetails $Error[0].exception.message
    exit
}
$GracefulClose = Disconnect-viserver * -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
$VMResultsObjDATA = ($confirmQryVMObj  | Select name, PersistentId, numcpu, memorygb)
JSONReturn -StatusCode "0" -ResponseBody $VMResultsObjDATA
exit