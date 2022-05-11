# Public Cleared
<# Version 2.0
Last Update 03.16.15
For GRC Standard C.1.e "Disabled Accounts - Group Membership Prune"
#>

Import-Module ActiveDirectory

# Set Logfile/Reportfile location
[STRING]$TimeStamp = Get-Date -Format "MM-dd-yy_HH-mm"
$LogFile = ".\c1e-UsersData-TEMP" + $TimeStamp + ".log"
$ReportFile = ".\c1e-DisabledWGroups-Exceptions" + $TimeStamp + ".csv"
"DisplayName;SamaccountName;Memberof" | Add-Content $LogFile

$TargetDomainIDs = @("<DFQDN>")


foreach ($DomainServer in $TargetDomainIDs)
{
	#Write-Host "Searching: " $DomainServer "for users..."
	
	$TargetUsers = @() # Reset for each domain
	Get-ADUser -Server $DomainServer -Properties name,memberof,Enabled,iscriticalsystemobject -Filter { Enabled -eq $false } | %{ if ($_.memberof.count -gt 0) { $TargetUsers += $_ } }
	
	Write-Host "Found " $TargetUsers.Count "in " $DomainServer "..."
	Sleep 2
		
	#If Account Objects in Violation are FOUND; perform actions to correct -->
	
	foreach ($Account in $TargetUsers)
	{
		
		if ($Account.iscriticalsystemobject -ne $true)
		{
			#Filter for Built-Ins | Do Something
			
			#Report OFFENDING user account details
			
			# Exapnded Inventory Dump, if needed
			#$Account | Export-Csv $InventoryDump -NoTypeInformation -Append
			#$GrpsTmp1 = $Account | Select -ExpandProperty Memberof; $GrpsTmp1 = $GrpsTmp1 -replace ",","."; $GrpsTmp1 | Add-Content $InventoryDump
			
			$Account.Name + ";" + $Account.SamaccountName + ";" + $Account.Memberof | Add-Content $LogFile
							
			foreach ($GroupDN in $Account.Memberof)
				{
					
					
					"Removing: " + $GroupDN + " for: " + $Account.SamaccountName | Add-Content $LogFile #-- COMMENTED OUT FOR TESTING--- THisis an important LOG File Line
					
					# PRODUCTION Corrective COMMAND -->
					Remove-ADGroupMember -Server $DomainServer -Identity $GroupDN -Member $Account.SamaccountName -Confirm:$false
					
				} 
			
			
		}
		if ($Error.Count -gt 0)
		{
			#Log errors encountered PER USER Query & Update
			"Error Reported when attempting Script Action: " + $Error | Add-Content $LogFile
			$Error.Clear()
			Sleep 25
		}
		
		Sleep -Milliseconds 5
	}
	
	
}

# Post Data Collection Report Clean Up
$TableData = Import-Csv -Path $LogFile -Delimiter ";"
$TableData | Export-Csv -NoTypeInformation -Path $ReportFile
Remove-Item -Path $LogFile
Sleep 2

$EmailFrom = "<SRC>"
$EmailTo = "<DEST>"
$Subject = "Reporting - c-1-e: Disabled Users GROUP Memberships"
$Body = "See Attachment for: Disabled Users In WITH Group Memberships. `n This is for GRC Line c.1.e"

$smtpClient = new-object system.net.mail.smtpClient
$smtpClient.Host = 'smtp<DNS>'

$emailMessage = New-Object System.Net.Mail.MailMessage
$emailMessage.From = $EmailFrom
$emailMessage.To.Add($EmailTo)
$emailMessage.Subject = $Subject
$emailMessage.Body = $Body
$emailMessage.Attachments.Add($ReportFile)
$SMTPClient.Send($emailMessage)