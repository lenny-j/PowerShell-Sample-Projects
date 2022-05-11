# Public Cleared
# Last Update: Dec. 2020

# Data collect and env setup

# You need output place
$ThisLogFile = "LDAP-Connect-and-Bind-Monitor.csv" # One file - per Domain

# Requery until manually stopped
$Run = $true

# Dyno server target list
$SiteQry = Get-ADDomainController -Filter {(Domain -eq "DDC.<DDC>") -and ((Site -eq "01") -or (Site -eq "02"))} | Select HostName
[ARRAY]$BackendSvrs = $SiteQry.Hostname

# for the BIND testing
$access = new-object "System.Net.NetworkCredential" -ArgumentList "DDC\USERNAME",((Get-Credential("access")).GetNetworkCredential().Password)

## START: Run Loop
While ($Run -eq $true) {

# Reset Report Row Contents
$MasterReportTBL = @()


# Start the foreach Server Loop
foreach ($TgtHostName in $BackendSvrs) {

    Write-Host "Testing " $TgtHostName

    #Timestamp for this round of call attempts
    $TimeStamp = Get-Date -Format MMddyy_hh-mm-ss_tt

    # Compose, or RECompose the LDAP Connection, filter, and other deets
    
    $null = [System.Reflection.Assembly]::LoadWithPartialName('System.DirectoryServices.Protocols')
    $null = [System.Reflection.Assembly]::LoadWithPartialName('System.Net')

    [STRING]$LDAPDirectoryService = $TgtHostName + ':' + "389"; ## Revisit for other ports at some point 

    $LDAPServer = New-Object System.DirectoryServices.Protocols.LdapConnection $LDAPDirectoryService
    # Seems right to me
    $LDAPServer.SessionOptions.ProtocolVersion = 3
    $LDAPServer.SessionOptions.RootDseCache = $false
    $LDAPServer.SessionOptions.AutoReconnect = $false
    $LDAPServer.SessionOptions.PingKeepAliveTimeout = 0
    $LDAPServer.AutoBind = $false;



    #$DomainDN = "dc=DDC"; # this level causes a CMD fail; it double queries for some DNS data
    $DomainDN = "OU=Users,dc=DDC";
    $dseLDAPFilter = '(objectClass=*)'
    $knownLDAPFilter = "(samaccountname=USERNAME)"; # Used for the KNOWN data fetch test

    $dseScope = [System.DirectoryServices.Protocols.SearchScope]::Base
    $knownScope = [System.DirectoryServices.Protocols.SearchScope]::Subtree

    $AttributeList = @("*")

    $dseSearchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest -ArgumentList $null,$dseLDAPFilter,$dseScope,$AttributeList
    $knownSearchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest -ArgumentList $DomainDN,$knownLDAPFilter,$knownScope,$AttributeList





    # Try a CONNECT - first; and deal with the results



    try {
            $dseResponse = "" #Clear it
                #Write-Host "Connect call to" $TgtHostName -ForegroundColor Green
            $LDAPServer.AuthType = [System.DirectoryServices.Protocols.AuthType]::Anonymous
            $dseResponse = $LDAPServer.SendRequest($dseSearchRequest)
        }

    catch {
            Write-Host "dse Connect Failed";
            #Pause
        }


    # Capture the CONNECT results - to your table... 
        # use if/else on the output marker... of some sort


    if ($dseResponse.ResultCode -ne "Success") {
    
        # connect didn't seem to work
    

        $NewRow = ""
        $NewRow = New-Object psobject
        $NewRow | Add-Member -MemberType NoteProperty -Name TimeStamp -Value $TimeStamp
    
        [STRING]$TgtRowData = ""
        $TgtRowData = $TgtHostName
        $NewRow | Add-Member -MemberType NoteProperty -Name TargetServer -Value $TgtRowData
    
        [STRING]$TgtRowrspData = ""
        $TgtRowrspData = "ConnectCall - " + $Error[0].exception.message

        $NewRow | Add-Member -MemberType NoteProperty -Name Action-Response -Value $TgtRowrspData
        $NewRow | Add-Member -MemberType NoteProperty -Name Action-Status -Value "Dwn"
        Write-Host "Connect - FAILED:  " $Error[0].exception.message -ForegroundColor Red
    
    

        $MasterReportTBL += $NewRow

    }

    else {

        $NewRow = ""
        $NewRow = New-Object psobject
        $NewRow | Add-Member -MemberType NoteProperty -Name TimeStamp -Value $TimeStamp
    
        [STRING]$TgtRowData = ""
        $TgtRowData = $TgtHostName
        $NewRow | Add-Member -MemberType NoteProperty -Name TargetServer -Value $TgtRowData
    
        [STRING]$TgtRowrspData = ""
        $TgtRowrspData = "ConnectCall - " + $dseResponse.Entries[0].Attributes.servername[0]
        $NewRow | Add-Member -MemberType NoteProperty -Name Action-Response -Value $TgtRowrspData
        $NewRow | Add-Member -MemberType NoteProperty -Name Action-Status -Value "Up"
        Write-Host "Connect - Ok" -ForegroundColor Green
    
        $MasterReportTBL += $NewRow

    }







    # If the connect works ok - bind, and search for some known results




    try {
            $knownResponse = "" #Clear it
                #Write-Host "Bind & Srch call to" $TgtHostName -ForegroundColor Green
            $LDAPServer.AuthType = [System.DirectoryServices.Protocols.AuthType]::Basic
            $Bind = $LDAPServer.Bind($access);
            #$LDAPServer.Bind($access);
            #$LDAPServer.Bind()
        
            $knownResponse = $LDAPServer.SendRequest($knownSearchRequest)  
        }

    catch {
            # Write-Host "Bind - FAILED:  " $Error[0].exception.message -ForegroundColor Red;
            #Pause
        }






    # Capture the BIND results - to your table... 
        # use if/else on the output marker... of some sort




    if ($knownResponse.ResultCode -ne "Success") {
    
        # connect didn't seem to work
    

        $NewRow = ""
        $NewRow = New-Object psobject
        $NewRow | Add-Member -MemberType NoteProperty -Name TimeStamp -Value $TimeStamp
    
        [STRING]$TgtRowData = ""
        $TgtRowData = $TgtHostName
        $NewRow | Add-Member -MemberType NoteProperty -Name TargetServer -Value $TgtRowData
    
        [STRING]$TgtRowrspData = ""
        $TgtRowrspData = "BIND and Srch Call - " + $Error[0].exception.message

        $NewRow | Add-Member -MemberType NoteProperty -Name Action-Response -Value $TgtRowrspData
    
        $NewRow | Add-Member -MemberType NoteProperty -Name Action-Status -Value "Fail"
    
        Write-Host "Bind - FAILED:  " $Error[0].exception.message -ForegroundColor Red;
        $MasterReportTBL += $NewRow

    }

    else {

        $NewRow = ""
        $NewRow = New-Object psobject
        $NewRow | Add-Member -MemberType NoteProperty -Name TimeStamp -Value $TimeStamp
    
        [STRING]$TgtRowData = ""
        $TgtRowData = $TgtHostName
        $NewRow | Add-Member -MemberType NoteProperty -Name TargetServer -Value $TgtRowData
    
        [STRING]$TgtRowrspData = ""
        $TgtRowrspData = "BIND and Srch Call - " + $knownResponse.Entries[0].DistinguishedName

        $NewRow | Add-Member -MemberType NoteProperty -Name Action-Response -Value $TgtRowrspData

    
    
        if ($knownResponse.Entries[0].DistinguishedName -eq "CN=TGTOBJECT") {
            $NewRow | Add-Member -MemberType NoteProperty -Name Action-Status -Value "Success"
        }
        else {
            $NewRow | Add-Member -MemberType NoteProperty -Name Action-Status -Value "Fail - No DN Match"
        }
        
    
        Write-Host "Bind - Ok"-ForegroundColor Green
        $MasterReportTBL += $NewRow

    }


    # Write to Report File


    $MasterReportTBL | Export-Csv $ThisLogFile -NoTypeInformation -Append


    # In all cases, reset and rest
        # Clear DNS Cache, for good measure
        #"Clear-DNSClientCache" ref.: https://docs.microsoft.com/en-us/powershell/module/dnsclient/clear-dnsclientcache?view=win10-ps

    $LDAPServer.Dispose();
    Clear-DnsClientCache
    Sleep 5

#Pause
# STOP: forEach Target Server Loop
}



## STOP: while Run Loop
}