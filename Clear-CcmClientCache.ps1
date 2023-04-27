$machine = Read-Host "Enter PC San number to Clear CCM Cache"

#check if machine is online
if (Test-Connection -ComputerName $machine -Count 1 -quiet) {
    Write-Host "$machine is Online!" -ForegroundColor Green
    Invoke-Command -ComputerName $machine -ScriptBlock {
        #List CCM Cache objects
            $CMObject = New-Object -ComObject “UIResource.UIResourceMgr”
            $CMCacheObjects = $CMObject.GetCacheInfo()
            $CMCacheObjects.GetCacheElements()

        ## Initialize the CCM resource manager com object
            [__comobject]$CCMComObject = New-Object -ComObject 'UIResource.UIResourceMgr'

        ## Get the CacheElementIDs to delete
            $CacheInfo = $CCMComObject.GetCacheInfo().GetCacheElements()

        ## Remove cache items
            ForEach ($CacheItem in $CacheInfo) {
                $null = $CCMComObject.GetCacheInfo().DeleteCacheElement([string]$($CacheItem.CacheElementID))
            }
    
        Write-Host "CCM Cache cleared!" -ForegroundColor Green
        #List CCM Cache objects
        $CMObject = New-Object -ComObject “UIResource.UIResourceMgr”
        $CMCacheObjects = $CMObject.GetCacheInfo()
        $CMCacheObjects.GetCacheElements()
    }

} else {
    Write-Host "$PcName is currently Offline Or unreachable - ending script!" -ForegroundColor Red
}