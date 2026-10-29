# Run on the Hyper-V host, VM must be off
$vmName = 'CL2'
$vm   = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter "ElementName='$vmName'"
$vssd = $vm.GetRelated('Msvm_VirtualSystemSettingData') |
        Where-Object { $_.VirtualSystemType -eq 'Microsoft:Hyper-V:System:Realized' }

"Old: $($vssd.BIOSGUID)  $($vssd.BIOSSerialNumber)"
$vssd.BIOSGUID         = '{' + [guid]::NewGuid().ToString().ToUpper() + '}'
$vssd.BIOSSerialNumber = ((1..7 | ForEach-Object { '{0:D4}' -f (Get-Random -Maximum 10000) }) -join '-').Substring(0, 32)

$vsms   = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemManagementService
$result = $vsms.ModifySystemSettings($vssd.GetText(2))
"ReturnValue: $($result.ReturnValue)   (0 = done, 4096 = job started)"
"New: $($vssd.BIOSGUID)  $($vssd.BIOSSerialNumber)"
