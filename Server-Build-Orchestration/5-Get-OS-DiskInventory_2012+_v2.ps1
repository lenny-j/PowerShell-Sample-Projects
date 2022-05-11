# Public Cleared
# Last Update Nov. 10, 2021

# Need to manage OS Version Compatability; Namely - WS 2008 don't have these cmds!
# Opportunity to return the disks an an ARRAY - within the JSON package
# to allow better parsing of the attributes

# Requires - > 
${activityInput.domain} = "<DOMAIN>"
${activityInput.domain_admin} = "<ADMIN>"
${activityInput.domain_pass} = "<PASS>"
${activityInput.server_fqdn} = "<SERVER>"

# Results Manager Function
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

# Get some Remote PS Creds Setup
$secure_pass = ConvertTo-SecureString -String $domain_pass -AsPlainText -Force 
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist "$domainShortname\$domainAdminUsername", $secure_pass

# Remote call - can return an object into VAR; fix this
try {

    $InvokeCallResp = 
    Invoke-Command -computer ${activityInput.server_fqdn} -credential $credential -ScriptBlock {
    
        $AnswerTbl = @();
        
        # I'm returning ALLLLLLl disks - even those already configured! - legacy was filtering based on 'PartitionStyle == RAW'
        ##$disks = Get-Disk | Where-Object -FilterScript {$_.PartitionStyle -eq "RAW"} | Sort-Object -Property Number
        $disks = Get-Disk | Sort-Object -Property Number;
        $disks | % {
            $RowEntry = New-Object -TypeName psobject;
            $RowEntry | Add-Member -MemberType NoteProperty -Name "DiskNumber" -Value $_.Number;
            $RowEntry | Add-Member -MemberType NoteProperty -Name "SizeInGB" -Value ($_.size / 1GB);
            $RowEntry | Add-Member -MemberType NoteProperty -Name "PartitionStyle" -Value $_.PartitionStyle;
            $AnswerTbl += $RowEntry;
        };
    
        return $AnswerTbl

    } -ErrorAction Stop

    # End TRY OPEN
}

catch {
    # Problem with the Invoke - Overall ... like can't find host, etc.
    JSONReturn -StatusCode 1 -ErrorDetails $Error[0].exception -ResponseBody "It Didn't Work!"
    exit
}

JSONReturn -StatusCode 0 -ResponseBody ($InvokeCallResp | Select-Object DiskNumber, SizeInGB, PartitionStyle)


<#Example Orch Response - Nov. 10th test:

{
    "output": [
        {
            "DiskNumber": 0,
            "SizeInGB": 80,
            "PartitionStyle": "GPT"
        },
        {
            "DiskNumber": 1,
            "SizeInGB": 50,
            "PartitionStyle": "GPT"
        },
        {
            "DiskNumber": 2,
            "SizeInGB": 50,
            "PartitionStyle": "MBR"
        },
        {
            "DiskNumber": 3,
            "SizeInGB": 5,
            "PartitionStyle": "RAW"
        }
    ],
    "status_code": "0",
    "error_details": ""
}
#>