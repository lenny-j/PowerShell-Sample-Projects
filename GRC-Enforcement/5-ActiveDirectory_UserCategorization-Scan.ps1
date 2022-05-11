# Public Cleared
#Last Update: 07.14.15
#Most Recent Updates include: Addl. "Role" Templates Filtering && "PARTNERS" Filtering


$DomainServer = "<DC>.<DOMAIN>"
Import-Module ActiveDirectory

[STRING]$TimeStamp = Get-Date -Format "MM-dd-yy_HH-mm"

$InvAllEmployeesGrps = Get-ADGroup -Filter { name -like "*ALL Employees" } -Server $DomainServer
$InvAllContractosGrps = Get-ADGroup -Filter { name -like "*ALL Contractors" } -Server $DomainServer
$InvAllAuditorsGrps = Get-ADGroup -Filter { name -like "*ALL Auditors" } -Server $DomainServer

Sleep 2
$InvAllGroupsCombined = $InvAllEmployeesGrps + $InvAllContractosGrps + $InvAllAuditorsGrps

$GroupsCombinedMbrRoster = @()
$ProdStatusMasterUserInv = @()
$CandidateViolations = @()

foreach ($ComplGrp in $InvAllGroupsCombined) {

	# Dump Memberships

	Get-ADGroupMember -Identity $ComplGrp.name -Server $DomainServer | % { $GroupsCombinedMbrRoster += $_.samaccountname }
	Sleep -Milliseconds 2

}

## Need to add-in for "Special" Groups | This will be a Recursive Call for a handful of folks

Get-ADGroupMember -Identity "All Business Partners" -Server $DomainServer -Recursive | % { $GroupsCombinedMbrRoster += $_.samaccountname }

$CmpnyLttrs = @()
$CompanyLettersInv = @()

$USA_TargetOUs = @()
$WRB_TargetOUs = @()

foreach ($SecGrp in $InvAllGroupsCombined) {

	$CompanyLettersInv += $SecGrp.Name -replace "([a-z]+)\s([a-z]+)\s([a-z]+)", '$1'

}

$Trimmed = $CompanyLettersInv | Select $_ -Unique

# If I loop thru these search & replace... then run the resulting list thru TRIM && Distincit; I'll get the DN Filters to set for USER object Search Scopes
# See lines above

# Then... Setup the OU Query ... set this to ONE Level from Known Permanent Parents of """" and "" Users""
#for each item in Trimmed; search ONELEVE for OU that Matches the Company Letters Value; this get's added to a Master OU Query Target List

foreach ($Company in $Trimmed) {

	# Master Parent OU Search

	$Filter = "*" + $Company + "*"
	Get-ADOrganizationalUnit -Filter { name -like $Filter } -Server $DomainServer -SearchBase 'OU=<DDC>' -SearchScope OneLevel | % { $USA_TargetOUs += $_.DistinguishedName }

	Get-ADOrganizationalUnit -Filter { name -like $Filter } -Server $DomainServer -SearchBase 'OU=Users<DDC>' -SearchScope OneLevel | % { $WRB_TargetOUs += $_.DistinguishedName }

	#Pause

}


# With ONE Level; fetch the child OU that Matches on ANY of the Compnay Letters Inventory 

$CombinedOUTargets = $USA_TargetOUs + $WRB_TargetOUs


foreach ($Container in $CombinedOUTargets) {

	#Write-Host "Searching $Container ..."

	Get-ADUser -Filter { enabled -eq $true } -SearchBase $Container -Server $DomainServer | % { if ($_.DistinguishedName -notmatch "Service Account") { $ProdStatusMasterUserInv += $_.samaccountname } }
	#Pause

}


# Compare a b; REPORT Only Variances | $ProdStatusMasterUserInv && $GroupsCombinedMbrRoster
#$Diff1 | %{if ($_.SideIndicator -eq "<=") {Write-Host "Here is a Diff " $_.InputObject; Pause}}
## Then ... we need to have master lists of USERs and MEMBERs; Comp them and report ONLY Variances; This is Your Exception Inventory

# 06.23 Update to correct for false positives in compare; I needed to SORT and select UNIQUE for the compare lists:

$ProdStatusMasterUserInvSORTED = $ProdStatusMasterUserInv | Sort -Unique
$GroupsCombinedMbrRosterSORTED = $GroupsCombinedMbrRoster | Sort -Unique
$DiffsMaster1 = Compare $ProdStatusMasterUserInvSORTED $GroupsCombinedMbrRosterSORTED

$DiffsMaster1 | % { if ($_.SideIndicator -eq "<=") { $CandidateViolations += $_.InputObject } }


# Working items to REPORT the candidate accounts

$CandidateFile = ".\Candidates" + $TimeStamp + ".log"
$CandidateViolations | Add-Content $CandidateFile


$ReportFile = ".\ReportFile" + $TimeStamp + ".log"
"samaccountname;displayname;canonicalname" | Add-Content $ReportFile

foreach ($DigID in $CandidateViolations) {
	$MOCompare = $null
	Get-ADUser -Identity $DigID -Properties displayname, canonicalname, memberof -Server $DomainServer | % { Sleep -Milliseconds 2; $MOCompare = $_.memberof | Out-String; if (($MOCompare -notmatch "GRC-ServiceAccounts") -and ($MOCompare -notmatch "GRC-RoleUserTemplates")) { $_.SamaccountName + ";" + $_.DisplayName + ";" + $_.CanonicalName | Add-Content $ReportFile } }

}


$ReportContents = Import-Csv -Path $ReportFile -Delimiter ";"
$OutPutFile = ".\C1A_ReportData" + $TimeStamp + ".csv"
$ReportContents | Export-Csv -Path $OutPutFile -NoTypeInformation



$EmailFrom = "<>"
$EmailTo = "<>"
$Subject = "Reporting: C.1.A: Standard Group Membership - Exceptions"
$Body = "See Attachment for C.1.A: Standard Groups `nThese are users who are NOT a member of at least ONE of the Standard groups e.g. Employess, Contractors, Auditors"
	
$smtpClient = new-object system.net.mail.smtpClient
$smtpClient.Host = "smtp.<>"
	
$emailMessage = New-Object System.Net.Mail.MailMessage
$emailMessage.From = $EmailFrom
$emailMessage.To.Add($EmailTo)
$emailMessage.Subject = $Subject
$emailMessage.Body = $Body
$emailMessage.Attachments.Add($OutPutFile)
$SMTPClient.Send($emailMessage)
