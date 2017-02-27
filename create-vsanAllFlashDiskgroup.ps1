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

if (!(Get-Module -Name vmware.VimAutomation.storage -ErrorAction SilentlyContinue)){
	Import-Module vmware.VimAutomation.Storage
}

$ESXHosts = @("host1","host2")

Connect-VIServer vcenter

$ESXHosts | Foreach {
   
   Write-Host "Finding disks for $($_)"
  
    
	
	 #  Write-Host "all disks"
	 $diskgroup=1
	 

	$eh = Get-EsxCli -VMHost $_
  #Cache disk is a HPE 800gb disk
	$cacheDiskModel = "EK0800JVYPN"
  #capacity disks are 3.2TB disks
	$capacityDiskModel = "MO3200JFFCL"
	$disks = $eh.storage.core.device.list()
	$cacheSSDs = $disks | where { $_.model -eq $cacheDiskModel }
	$capacitySSDs = $disks | where { $_.model -eq $capacityDiskModel }


#adapters are P440 and P440ars
	$eh.storage.core.adapter.list() | where { $_.Description -like "*P440*"} | % {
		$localCacheSSDArray = @()
		$LocalCapacitySSDArray = @()
		$hba = $_.hbaname
		$devices= $eh.storage.nmp.device.list()
		foreach ($device in $devices){
			if ($device.workingpaths -like '*'+$hba+'*'){
				if ($cacheSSDs | where {$_.device -eq $device.device}){
					$LocalCacheSSDArray += $device
				}
				elseif ($capacitySSDs | where {$_.device -eq $device.device}){
					$LocalCapacitySSDArray += $device
				}
				
			}
		} #through all devices
		$LocalCapacitySSDString = $LocalCapacitySSDArray | % { $_.device }
		
		  

		$capacitytag=$localcapacityssdarray | %{ $eh.vsan.storage.tag.add(($_.Device), "capacityFlash") }
		
       Write-Host "Adding Storage devices to" $_
       $adddisks = $eh.vsan.storage.add($LocalCapacitySSDString, ($localcachessdarray[0].device))
       if ($adddisks -eq "true") {
            Write-Host "Disks added" -ForegroundColor Green
       } Else {
        Write-Host "Error adding disks: $adddisks" -ForegroundColor Red
       }
	} # through hbas

 
 $diskgroup+=1

 }#foreachhost
