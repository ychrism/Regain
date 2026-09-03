# ==============================================
# SCRIPT CORRIGÉ: Trouver les droits WriteDacl de Carlos
# ==============================================

# Étape 1: Importer le module ActiveDirectory
Write-Host "=== Étape 1: Import du module ActiveDirectory ===" -ForegroundColor Yellow
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

# Vérifier si le module est chargé
if (-not (Get-Module ActiveDirectory)) {
    Write-Host "ERREUR: Le module ActiveDirectory n'est pas disponible" -ForegroundColor Red
    Write-Host "Essayez avec la méthode alternative ci-dessous" -ForegroundColor Yellow
    exit
}
Write-Host "Module ActiveDirectory importé!" -ForegroundColor Green
Write-Host ""

# Étape 2: Récupérer l'utilisateur Carlos
Write-Host "=== Étape 2: Recherche de Carlos ===" -ForegroundColor Yellow
try {
    $Carlos = Get-ADUser Carlos -Properties * -ErrorAction Stop
    Write-Host "Carlos trouvé!" -ForegroundColor Green
    Write-Host "  Nom: $($Carlos.Name)" -ForegroundColor Gray
    Write-Host "  SID: $($Carlos.SID.Value)" -ForegroundColor Gray
} catch {
    Write-Host "Erreur: $($_.Exception.Message)" -ForegroundColor Red
    exit
}
Write-Host ""

# Étape 3: Récupérer les objets (sans -Properties)
Write-Host "=== Étape 3: Récupération des objets AD ===" -ForegroundColor Yellow

# Méthode 1: Utiliser Get-ADObject sans -Properties (prend les propriétés par défaut)
# Puis ajouter la propriété nTSecurityDescriptor via un autre appel
$AllObjects = Get-ADObject -Filter *
Write-Host "$($AllObjects.Count) objets trouvés (noms seulement)" -ForegroundColor Green

# Récupérer les propriétés une par une
Write-Host "Récupération des descripteurs de sécurité..." -ForegroundColor Gray
$Results = @()

foreach ($Object in $AllObjects) {
    try {
        # Récupérer les propriétés séparément
        $ObjectDetail = Get-ADObject -Identity $Object.DistinguishedName -Properties nTSecurityDescriptor, ObjectClass
        
        if ($ObjectDetail -and $ObjectDetail.nTSecurityDescriptor) {
            $SD = $ObjectDetail.nTSecurityDescriptor
            $ACLs = $SD.Access
            
            foreach ($ACL in $ACLs) {
                if ($ACL.IdentityReference -and $ACL.IdentityReference.Value -match $Carlos.SID.Value) {
                    if ($ACL.ActiveDirectoryRights.ToString() -match "WriteDacl") {
                        $Results += [PSCustomObject]@{
                            Nom = $ObjectDetail.Name
                            ObjectClass = $ObjectDetail.ObjectClass
                            DN = $ObjectDetail.DistinguishedName
                            Droits = $ACL.ActiveDirectoryRights.ToString()
                        }
                        Write-Host "  -> Carlos a WriteDacl sur: $($ObjectDetail.Name)" -ForegroundColor Green
                    }
                }
            }
        }
    } catch {
        # Ignorer les erreurs
    }
}

# Étape 4: Afficher les résultats
Write-Host ""
Write-Host "=== Résultats ===" -ForegroundColor Yellow

if ($Results.Count -gt 0) {
    $UserResults = $Results | Where-Object { $_.ObjectClass -eq "user" }
    
    if ($UserResults.Count -gt 0) {
        Write-Host "Comptes utilisateur trouvés:" -ForegroundColor Green
        foreach ($Result in $UserResults) {
            Write-Host "  -> $($Result.Nom)" -ForegroundColor Green
        }
        $Answer = $UserResults[0].Nom
        Write-Host ""
        Write-Host "RÉPONSE: $Answer" -ForegroundColor Cyan
    } else {
        Write-Host "Objets trouvés (non-utilisateurs):" -ForegroundColor Yellow
        foreach ($Result in $Results) {
            Write-Host "  -> $($Result.Nom) ($($Result.ObjectClass))" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "Aucun droit WriteDacl trouvé pour Carlos" -ForegroundColor Red
}
