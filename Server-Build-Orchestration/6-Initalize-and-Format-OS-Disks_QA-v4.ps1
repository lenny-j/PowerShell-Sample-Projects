# Public Cleared
#Last Update Dec. 02, 21

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
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist "$domainShortname\$domainAdminUsername", $secure_pass
try {
    $DiskSetupCall = invoke-command -ComputerName ${activityInput.server_fqdn} -Credential $credential -ErrorAction Stop -ScriptBlock {
        $reRunChk = Get-Volume -DriveLetter ${activityInput.driveLETTER} -ErrorAction SilentlyContinue
        if ($reRunChk -ne $null) {
            if ($reRunChk.HealthStatus -eq "Healthy") {
                [STRING]$responseText = "Disk was previously provisioned, and is healthy`n`nObjectID: " + $reRunChk.ObjectId
                return $responseText
                exit
            }
        }
        [INT]$desiredSize = ${activityInput.sizeInGB}
        $sizeChk = $desiredSize * 1GB
        [ARRAY]$disksQry = Get-Disk | Where-Object -FilterScript { ($_.partitionstyle -eq "RAW") -and ($_.size -eq $sizeChk) } | Sort-Object -Property Number;
        if ($disksQry -eq $null) {
            throw "No Configurable Disks Found - "
            exit
        }
        [INT]$targetDiskNumber = $disksQry[0].number
        try { Initialize-Disk -Number $targetDiskNumber -PartitionStyle ${activityInput.partitionStyle} -ErrorAction Stop }
        catch { throw "Error trying to INITALIZE disk (provisioning step 1 of 3) - $Error" }
        try { $PartObj = New-Partition -DiskNumber $targetDiskNumber -UseMaximumSize -DriveLetter ${activityInput.driveLETTER} -ErrorAction Stop }
        catch { throw "Error trying to CREATE partition (provisioning step 2 of 3) - $Error" }
        try { Format-Volume -Partition $PartObj -FileSystem ${activityInput.fileSystem} -AllocationUnitSize ${activityInput.allocationUnitSize} -NewFileSystemLabel ${activityInput.driveNameLABEL} -Confirm:$false -ErrorAction Stop; }
        catch { throw "Error trying to FORMAT volume (provisioning step 3 of 3) - $Error" }
    }
}
catch {
    [STRING]$responseText = "There was a problem trying to provision the disk - Additional details (if any): `n`n" + $Error[0].exception
    JSONReturn -StatusCode 1 -ResponseBody $responseText -ErrorDetails $Error[0].exception
    exit
}
if ($DiskSetupCall -ne $null) {
    if ($DiskSetupCall.GetType().Name -eq "string") { [STRING]$AnswerOutStuff = $DiskSetupCall; $scVal = 0 }
    elseif ($DiskSetupCall.GetType().Name -match "CimInstance") { $AnswerOutStuff = ($DiskSetupCall | Select driveletter, ObjectId, healthstatus) | ConvertTo-Json; $scVal = 0 }
    else { [STRING]$AnswerOutStuff = "Disk configuration returned an unexpected response - please validate the drive is healthy`n`n" + $DiskSetupCall; $scVal = 1 }
}
else { [STRING]$AnswerOutStuff = "Disk configuration returned an empty response - please validate the drive is healthy"; $scVal = 1 }
JSONReturn -StatusCode $scVal -ResponseBody $AnswerOutStuff
exit