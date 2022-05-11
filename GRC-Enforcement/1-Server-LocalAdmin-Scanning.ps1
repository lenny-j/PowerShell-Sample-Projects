# Public Cleared
# Last Update: 03-30-2020

##
# Step 1
# Inventories Creation / Stage
# // We need current lists of servers, apps, Known Admins
##


# -->
## Master Server Inventory -->
# -->


if (Test-Path "SvcNowSrc.csv") { Remove-Item "SvcNowSrc.csv" }

# Create a connection to ServiceNow and Download the Report!
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # Added Dec 2019; REQUIRED to establish ServiceNow connection; SN rejects Tls1
$env:PWSValidation = "<ID>"
[STRING]$ChainBuild1 = . ".\functionsgen.exe"
$wc = New-Object System.Net.WebClient
$credCache = new-object System.Net.CredentialCache
$creds = new-object System.Net.NetworkCredential("<USER>", $ChainBuild1)
$credCache.Add("https://<TENANT>.service-now.com/", "Basic", $creds)
$wc.Credentials = $credCache

# This report has changed over time - ID 947a0960131d1380e4553262f244b096 was most recently updated 03-26-20
# the report queries based on a more recent "SOX" dropdown ; the  'old' used before 03-2020 no longer returns data

$wc.DownloadFile("https://<TENANT>.service-now.com/sys_report_template.do?CSV&jvar_report_id=947a0960131d1380e4553262f244b096", "SvcNowSrc.csv") # New Report as of Jan 2020

$wc.Dispose();

$MasterServerInv = Import-Csv "SvcNowSrc.csv"

# -->
## Application Inventory -->
# -->

# Fetch Distinct list of applications
$ApplicationsInv = $MasterServerInv.'rel_u_appname.name' | Sort -Unique

# Fetch Distinct list of Servers
$DistinctServersInv = $MasterServerInv.'app_name' | Sort -Unique

# -->
## Known Admins Inventory -->
# -->

# This will be used to "filter out" the Wintel Groups; approved 09.28.17

$KnownADMPeeps = Import-Csv .\Known_Admin_Objects_MASTER.csv
# [] 'domaininclsam' -- Mostly interested in matching on THIS Attr [] 'samaccountname'




############################################################################################################################
############################################################################################################################

# Ok - Now we have initial inventories avail.

############################################################################################################################
############################################################################################################################


##
# Step 2
# Query Local Admins for EACH Server
#
##

# Dump Admin Group membership to a HASH that will be sourced during output creation
# We need to manage DOWN / NO CONNECT servers; e.g. no ping?

$ResultsMasterHash = @{ }

for ($i = 0; $i -lt $DistinctServersInv.Count; $i++)
{
	
	[STRING]$HostTargetTrimed = $DistinctServersInv[$i].Trim()
	$qryresultsbuffer = @() # Resting Location for data to be passed to HASH TBL
	
	Write-Host "Ping... " $HostTargetTrimed -ForegroundColor 'Green'
	
	$PingTest = Test-Connection $HostTargetTrimed -Count 1 -Quiet
	Write-Host "The Ping Test Returned:" $PingTest
	
	if ($PingTest -eq $true)
	{
		
		$TgtAdminGrp = $null
		$TgtAdminGrp = [ADSI]("WinNT://" + $HostTargetTrimed + "/Administrators,group")
		
		if ($TgtAdminGrp.Path -eq $null)
		{
			
			# We Assume there was a connection or call error - Record it!
			$TgtAdminGrp.Invoke("Members") # Literal Call Execution is needed to Collect error info
			
			Write-Host "ERROR on calling Admin Group: " + $Error[0].Exception.Message
			$ResultsMasterHash.Add($HostTargetTrimed, $Error[0].Exception.Message)
			
		}
		
		else
		{
			
			# Seems like we have a ping resp and a conneciton - let's gather user data
			
			Write-Host "Requesting info from" $HostTargetTrimed
			Write-Host "Local Administrators:"
			
			foreach ($UserItem in $TgtAdminGrp.Invoke("Members"))
			{
				
				$MemberEntry = [ADSI]($Useritem)
				$qryresultsline = ($MemberEntry.Path -replace "WinNT://", "")
				Write-Host ($MemberEntry.Path -replace "WinNT://", "")
				
				$qryresultsbuffer += $qryresultsline # This is a place holder for data to be passed to HASH TBL
				
			}
			
			# Add ServerName && Results Array
			$ResultsMasterHash.Add($HostTargetTrimed, $qryresultsbuffer)
			
		} ## End ELSE
		
	} ## end master
	
	if ($PingTest -ne $true)
	{
		Write-Host "ERROR on " $HostTargetTrimed;
		Test-Connection $HostTargetTrimed -Count 1
		$ResultsMasterHash.Add($HostTargetTrimed, $Error[0].Exception.Message)
		
	}
	
	# END Query and Add to Hash
}


## Great ... now we have MEMBERSHIP as a hash


for ($i = 0; $i -lt $MasterServerInv.Count; $i++)
{
	#<----- Start FOR EACH Server Loop
	
	## WE Should test that this loops to the LAST/FINAL server in the CSV - just to be sure
	
	# Make sure no extra spaces
	$ServerName = $MasterServerInv[$i].app_name.Trim()
	
	# Some Debug Stuff
	Write-Host "i is $i - and servername is $ServerName"
	
	# Add Column(s) to the current record/row
	$MasterServerInv[$i] | Add-Member -MemberType NoteProperty -Name Administrators -Value $null
	$MasterServerInv[$i] | Add-Member -MemberType NoteProperty -Name Exceptions -Value $null
	
	## Move to HASH Create ()()
	
	$qryresultsbuffer = @()
	############## What's this all about??
	$qryresultscompare = @()
	
	Write-Host "Fetching Stored info of" $ServerName
	Write-Host "Local Administrators:"
	Write-Host $ResultsMasterHash[$ServerName]
	
	
	
	
	
	## REPLACE with the HASH TBL ENTRY DATA OUTPUT -->
	$qryresultsbuffer = $ResultsMasterHash[$ServerName] # This object will get appened to NoteProperty
	
	foreach ($DistinctItem in $ResultsMasterHash[$ServerName])
	{
		# We Need an additional parse step and co-creation of a comparison list ... because our "KTAs" do not have a domain component
		$qryresultslinecp = $DistinctItem -replace '(.*/)(.*)', '$2'
		$qryresultscompare += $qryresultslinecp
	}
	
	# Do Something With the RESULTs
	$MemberShipListContent = $qryresultsbuffer | Out-String # We are using String Conversion because this is an array
	$MasterServerInv[$i].Administrators = $MemberShipListContent
	
	## Let's Compose the Exceptions by comparing to known admins
	$ExcepDataCP = @()
	#$ExcepDataCP = compare $qryresultscompare $KnownADMPeeps.domaininclsam # This is how to INCLUDE the domain component ... but you'll need to fix the direction of the slash
	$ExcepDataCP = compare $qryresultscompare $KnownADMPeeps.samaccountname
	$ExcepDataVals = $ExcepDataCP | Where "SideIndicator" -eq "<="
	
	# Next line may require OUT STRING !!
	$MasterServerInv[$i].Exceptions = $ExcepDataVals.InputObject | Out-String # AGAIN, String conversion is needed because this is probably an array
	
	#Pause
	
	#<----- End FOR EACH Server Loop
}




############################################################################################################################
############################################################################################################################

# Ok - Now we Should have ALL the Admin Group Membership Data Avail. in :: $MasterServerInvComb

############################################################################################################################
############################################################################################################################


##
# Step 3
# Create the Output/Report File(s)
#
##


# Cool ... now ... how do we create the report file??
# Simple _ FULL  _ Export

$MasterServerInv | Export-Csv TestReportMIS.csv -NoTypeInformation

# NOW ... we parse Distinct apps ... and create INDIVIDUAL Report files

foreach ($AppTargetThing in $ApplicationsInv)
{
	
	Write-Host "Working on " $AppTargetThing
	
	$ThisRptContent = @()
	
	$ThisRptContent = $MasterServerInv | Where "rel_u_appname.name" -eq $AppTargetThing.trim()
	
    $ThisRptFileNameSRC = $AppTargetThing -replace "/","-"

	[STRING]$ThisRptFileName = "output\" + $ThisRptFileNameSRC + "Output.csv"
	
	
	$ThisRptContent | Export-Csv -Path "$ThisRptFileName" -NoTypeInformation
	
	#Pause
	
}




