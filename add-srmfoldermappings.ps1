if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
    if (Test-Path -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\VMware, Inc.\VMware vSphere PowerCLI' ) {
        $Regkey = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\VMware, Inc.\VMware vSphere PowerCLI'
       
    } else {
        $Regkey = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware vSphere PowerCLI'
    }
    . (join-path -path (Get-ItemProperty  $Regkey).InstallPath -childpath 'Scripts\Initialize-PowerCLIEnvironment.ps1')
}
if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
    Write-Host "VMware modules not loaded/unable to load"
    Exit 99
}


function add-foldermapping () {
 param(
 #primary and secondary folder are folder objects
	$PrimaryFolder,
	$SecondaryFolder,
	[switch]$async
)	

 #should already be connected to primary and secondary vcenter instances
  
#Primary Folder MoRef Value
  $PrimaryFolderValue = (($PrimaryFolder).ExtensionData.MoRef).Value
  $PrimaryFolderType = (($PrimaryFolder).ExtensionData.MoRef).Type
  $SecondaryFolderValue = (($SecondaryFolder).ExtensionData.MoRef).Value
  $SecondaryFolderType = (($secondaryfolder).ExtensionData.MoRef).Type
#Create new object for adding primary folder value
  $PrimaryFolderMoRef = New-Object SRM01.ManagedObjectReference
  #Add primary folder moref to object
  $PrimaryFolderMoRef.Type = $PrimaryFolderType
  $PrimaryFolderMoRef.Value = $PrimaryFolderValue
  #
  #Create new object for adding secondary folder value
  $SecondaryFolderMoRef = New-Object SRM01.ManagedObjectReference
  #Add primary folder moref to object
  $SecondaryFolderMoRef.Type = $SecondaryFolderType
  $SecondaryFolderMoRef.Value = $SecondaryFolderValue
  
  

  
Try {

  if($async){
  $global:srm01.AddFolderMappingAsync($global:mapping,$PrimaryFolderMoRef,$SecondaryFolderMoRef) # created folder mapping
   }
   else{
  $global:srm01.AddFolderMapping($global:mapping,$PrimaryFolderMoRef,$SecondaryFolderMoRef) # created folder mapping 
   }

}
Catch [Exception] {
    Write-Host -BackgroundColor Red "Issue mapping" $global:primaryVC ":" (get-VIObjectByVIView -moref $PrimaryFolderMoRef).name "to" $global:secondaryvc ":" (Get-VIObjectByVIView -MORef $SecondaryFolderMoRef).name
    Write-Host -BackgroundColor Red $_.Exception.Message
    Return
}
write-Host "vCenter " $global:PrimaryVC " " $PrimaryFolder.name  "mapped to vCenter "  $global:SecondaryVC  " "$SecondaryFOlder.name

}



function login-srmserverapi () {

	param(
		$srmServerAddr,
		$user,
		$password,
		$remoteUser,
		$remotePassword
	)



[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$global:web01 = New-WebServiceProxy("https://" + $srmServerAddr + ":9086/srm.wsdl") -Namespace SRM01
 
 
$global:srm01 = New-Object SRM01.Srmbinding
$global:srm01.url = "https://" + $srmServerAddr + ":9086/vcdr/extapi/sdk"
$global:srm01.CookieContainer = New-Object System.Net.CookieContainer
 
 
$global:mof01 = New-Object SRM01.ManagedObjectReference
$global:mof01.type = "SrmServiceInstance"
$global:mof01.value = $global:mof01.type
 
 
$global:srmApi01 = ($global:srm01.RetrieveContent($global:mof01)).srmApi
$global:protection01 = ($global:srm01.RetrieveContent($global:mof01)).protection
$global:recovery01 = ($global:srm01.RetrieveContent($global:mof01)).recovery
$global:mapping = ($global:srm01.RetrieveContent($global:mof01)).InventoryMapping


Try {
#

$global:srm01.SrmLoginSites($global:mof01, $user, $password, $remoteuser, $remotepassword,'')
}
Catch [Exception] {
    Write-Host -BackgroundColor Red "Unable to connect to SRM $srmServerAddr"
    Write-Host -BackgroundColor Red $_.Exception.Message
    Return
}
Write-Host -ForegroundColor Yellow "Connected to SRM $srmServerAddr"
 



}


function add-recursivefoldermapping () {
	#recursive function to decent through two sets of folders, match names, and add foldermappings
	param (
	$primaryfolder,
	$secondaryFolder
	)
	$primaryFolderArr = $primaryFolder.extensiondata.childentity
	$secondaryFolderArr = $secondaryFolder.extensiondata.childentity



	#if there are children, map children
	if($primaryFolderArr){
		foreach ($primaryFolderMoRef in $primaryFolderArr){
			try {
				$primarySubFOlder = get-viobjectbyviview -moref $primaryFolderMoRef -Server $global:primaryVC -ErrorAction stop
			}
			catch [Exception] {
    			Write-Host -BackgroundColor Red "Error with" $primaryFolderMoRef "in" $global:primaryvc "under folder" $PrimaryFolder.name
    			Write-Host -BackgroundColor Red $_.Exception.Message
    			break
			}
			foreach ($secondaryFolderMoRef in $secondaryFolderArr){
				try {
					$secondarySubFOlder = get-viobjectbyviview -moref $secondaryFolderMoRef -Server $global:secondaryVC -ErrorAction stop
				}
				catch [Exception] {
					Write-Host -BackgroundColor Red "Error with" $secondaryFolderMoRef "in" $global:secondaryvc "under folder" $secondaryFolder.name
					break
				}
				if($primarySubFOlder.name -eq $secondarySubFOlder.name){
					#instead of just mapping the folders, 
					add-recursivefoldermapping -primaryfolder $primarySubFOlder -secondaryfolder $secondarySubFOlder
				}
			}
		}
	}
	else{
		#map current folders
	add-foldermapping -primaryfolder $primaryfolder -secondaryfolder $secondaryFolder -async:$true
	
	}
	
}

##
#need to add the export/import functionality followed by running addthat mapping in order to create missing folders

function copy-folderstructuretovc () {
	param(
		$primaryFolder,
		$SecondaryFolder
	)
	$primaryFolderArr = $primaryFolder.extensiondata.childentity
	$secondaryFolderArr = $secondaryFolder.extensiondata.childentity

	#if there are children, map children
	if($primaryFolderArr){
		foreach ($primaryFolderMoRef in $primaryFolderArr){
			try {
				$primarySubFOlder = $null
				$primarySubFOlder = get-viobjectbyviview -moref $primaryFolderMoRef -Server $global:primaryVC -ErrorAction stop
			}
			catch [Exception] {
    			Write-Host -BackgroundColor Red "Error with" $primaryFolderMoRef "in" $global:primaryvc "under folder" $PrimaryFolder.name
    			Write-Host -BackgroundColor Red $_.Exception.Message
    			break
			}
			#check if folder already exists
			try {
				$secondarySubFOlder = $null
				$secondarysubfolder=Get-Folder -Name $primarySubFOlder.name -Location ($SecondaryFolder) -NoRecursion -Server $global:secondaryvc -ErrorAction Stop
			}
			catch [Exception]{
				#do noth ing
			}
			if($Secondarysubfolder){
				Write-Host $primarySubFOlder.name "already exists in" $SecondaryFolder.name "in vCenter" $global:secondaryvc
			}
			else{
				#create folder
				try {
					$secondarysubfolder=New-Folder -Name $primarySubFOlder.name -Location ($SecondaryFolder) -Server $global:secondaryvc -ErrorAction Stop
					Write-Host "Creating folder" $primarySubFOlder.name "in" $secondaryfolder
				}
				catch [Exception]{
					Write-Host -BackgroundColor Red "Error creating" $primarysubFolder.name "in" $SecondaryFolder.name "in vCenter" $global:secondaryvc
	    			Write-Host -BackgroundColor Red $_.Exception.Message
					break
				}
			}
			#recurse
			copy-folderstructuretovc -primaryfolder $primarySubFOlder -secondaryfolder $secondarySubFOlder		
		}
	}
}
##


###main
#
$global:primaryVC = "primaryvc"
$global:secondaryVC = "secondaryvc"
$user = "username"
#note single quotes seem to work best below
$password = 'mypass'
$primarySRMServerAddr="primarysrmserver"
$secondarySRMServerAddr="primarysrmserver"

login-srmserverapi   -srmserveraddr $primarySRMServerAddr -user $user -password $password -remoteuser $user -remotepassword $password

Connect-VIServer $global:primaryvc
Connect-VIServer $global:secondaryvc -notdefault

$PrimaryFolder = (get-datacenter "myprimarydc" -Server $global:primaryvc).getvmfolder()
$secondaryFolder = (Get-Datacenter "mydrdc" -Server $global:secondaryvc).getvmfolder()

#replicate folder structure
copy-folderstructuretovc -primaryfolder $PrimaryFolder -secondaryFolder $SecondaryFolder

#add folder mappings primary -> secondary
add-recursivefoldermapping -primaryfolder $PrimaryFolder -secondaryFolder $SecondaryFolder

#login to secondary srm server

login-srmserverapi   -srmserveraddr $secondarySRMServerAddr -user $user -password $password -remoteuser $user -remotepassword $password

#swap VC variables so that we can go reverse
$global:primaryVC = "secondaryvc"
$global:secondaryVC = "primaryvc"

#add folder mapping secondary -> primary
add-recursivefoldermapping -primaryfolder $SecondaryFolder -secondaryFolder $PrimaryFolder




