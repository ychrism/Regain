# Script simplifié pour trouver les droits WriteDacl de Carlos
Import-Module ActiveDirectory -ErrorAction Stop

$Carlos = Get-ADUser Carlos -ErrorAction Stop
$CarlosSID = $Carlos.SID.Value
$Objects = Get-ADObject -Filter * -Properties nTSecurityDescriptor, Name, ObjectClass

$Results = @()
foreach ($Obj in $Objects) {
    if ($Obj.nTSecurityDescriptor) {
        foreach ($Ace in $Obj.nTSecurityDescriptor.Access) {
            if ($Ace.IdentityReference -and $Ace.IdentityReference.Value -match $CarlosSID) {
                if ($Ace.ActiveDirectoryRights.ToString() -match "WriteDacl") {
                    $Results += [PSCustomObject]@{
                        Nom = $Obj.Name
                        Type = $Obj.ObjectClass
                    }
                }
            }
        }
    }
}

# Afficher les résultats
Write-Host "Résultats:" -ForegroundColor Yellow
$UserResults = $Results | Where-Object { $_.Type -eq "user" }
if ($UserResults) {
    Write-Host "Comptes utilisateur trouvés:" -ForegroundColor Green
    $UserResults | ForEach-Object { Write-Host "  -> $($_.Nom)" -ForegroundColor Green }
    $Answer = $UserResults[0].Nom
    Write-Host ""
    Write-Host "RÉPONSE: $Answer" -ForegroundColor Cyan
} else {
    Write-Host "Aucun compte utilisateur trouvé" -ForegroundColor Yellow
    $Results | ForEach-Object { Write-Host "  -> $($_.Nom) ($($_.Type))" -ForegroundColor Yellow }
}