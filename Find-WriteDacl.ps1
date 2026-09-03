# Recherche du compte que Carlos peut gérer via WriteDacl
Get-DomainObjectAcl -ResolveGUIDs | 
Where-Object {$_.SecurityIdentifier -eq (Get-DomainUser Carlos).ObjectSID -and $_.ActiveDirectoryRights -match "WriteDacl"} | 
ForEach-Object {Get-DomainObject -Identity $_.ObjectDN | Select-Object Name}




(Get-DomainObjectAcl -ResolveGUIDs | Where-Object {$_.SecurityIdentifier -eq (Get-DomainUser Carlos).ObjectSID -and $_.ActiveDirectoryRights -match "WriteDacl"} | ForEach-Object {Get-DomainObject -Identity $_.ObjectDN}).Name



# Voir tous les droits de Carlos
Get-DomainUser Carlos | Get-DomainObjectAcl -ResolveGUIDs | 
Format-Table ObjectDN, ActiveDirectoryRights, ObjectAceType

# Filtrer spécifiquement WriteDacl
Get-DomainUser Carlos | Get-DomainObjectAcl -ResolveGUIDs | 
Where-Object {$_.ActiveDirectoryRights -like "*WriteDacl*"} | 
ForEach-Object {
    $Target = Get-DomainObject -Identity $_.ObjectDN
    Write-Host "Carlos a WriteDacl sur: $($Target.Name)" -ForegroundColor Green
    $Target.Name
}
