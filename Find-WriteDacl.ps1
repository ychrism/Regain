# ==============================================
# MÉTHODE AVEC GET-ACL (Plus Robuste)
# ==============================================

Write-Host "=== Recherche des droits WriteDacl de Carlos avec Get-ACL ===" -ForegroundColor Yellow

# Importer le module AD
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

# Si le module n'est pas disponible, utiliser ADSI
if (-not (Get-Module ActiveDirectory)) {
    Write-Host "Module ActiveDirectory non disponible, utilisation d'ADSI..." -ForegroundColor Yellow
}

# Étape 1: Trouver Carlos
Write-Host "Recherche de Carlos..." -ForegroundColor Gray
try {
    # Essayer avec Get-ADUser d'abord
    $Carlos = Get-ADUser Carlos -Properties objectSid, DistinguishedName -ErrorAction SilentlyContinue
    if ($Carlos) {
        $CarlosDN = $Carlos.DistinguishedName
        $CarlosSID = $Carlos.SID.Value
        Write-Host "Carlos trouvé avec Get-ADUser" -ForegroundColor Green
    }
} catch {
    # Si Get-ADUser échoue, utiliser ADSI
    $DomainDN = "DC=CEH,DC=CYBERSPHERE,DC=com"
    $Root = [ADSI]"LDAP://$DomainDN"
    $Searcher = New-Object DirectoryServices.DirectorySearcher($Root)
    $Searcher.Filter = "(sAMAccountName=Carlos)"
    $Searcher.PropertiesToLoad.AddRange(@("distinguishedName", "objectSid"))
    $Result = $Searcher.FindOne()
    
    if ($Result) {
        $CarlosDN = $Result.Properties.distinguishedName[0]
        $CarlosSID = $Result.Properties.objectSid[0]
        Write-Host "Carlos trouvé avec ADSI" -ForegroundColor Green
    }
}

if (-not $CarlosDN) {
    Write-Host "ERREUR: Carlos non trouvé!" -ForegroundColor Red
    exit
}

Write-Host "  DN: $CarlosDN" -ForegroundColor Gray
Write-Host "  SID: $CarlosSID" -ForegroundColor Gray
Write-Host ""

# Étape 2: Trouver tous les utilisateurs du domaine
Write-Host "Recherche des ACLs WriteDacl..." -ForegroundColor Gray

$DomainDN = "DC=CEH,DC=CYBERSPHERE,DC=com"
$ADSI = [ADSI]"LDAP://$DomainDN"
$Searcher = New-Object DirectoryServices.DirectorySearcher($ADSI)
$Searcher.Filter = "(objectClass=user)"
$Searcher.PropertiesToLoad.AddRange(@("name", "distinguishedName", "objectSid", "nTSecurityDescriptor"))
$Searcher.PageSize = 1000
$Users = $Searcher.FindAll()

Write-Host "$($Users.Count) utilisateurs trouvés" -ForegroundColor Green
Write-Host ""

$Results = @()

foreach ($User in $Users) {
    try {
        $UserDN = $User.Properties.distinguishedName[0]
        $UserName = $User.Properties.name[0]
        
        # Utiliser Get-ACL pour obtenir les permissions
        try {
            $ACL = Get-ACL -Path "AD:\$UserDN" -ErrorAction SilentlyContinue
            
            foreach ($AccessRule in $ACL.Access) {
                # Vérifier si Carlos a des permissions
                if ($AccessRule.IdentityReference.Value -match $CarlosSID) {
                    # Vérifier WriteDacl (ou GenericAll qui inclut WriteDacl)
                    $Rights = $AccessRule.ActiveDirectoryRights
                    
                    if (($Rights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl) -or 
                        ($Rights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)) {
                        
                        $Results += [PSCustomObject]@{
                            Nom = $UserName
                            DN = $UserDN
                            Droits = $Rights.ToString()
                        }
                        
                        Write-Host "  -> Carlos a WriteDacl sur: $UserName" -ForegroundColor Green
                        Write-Host "     Droits: $($Rights.ToString())" -ForegroundColor Gray
                    }
                }
            }
        } catch {
            # Si Get-ACL échoue, utiliser la méthode ADSI directe
            try {
                $UserObject = [ADSI]"LDAP://$UserDN"
                $SD = $UserObject.ObjectSecurity
                
                if ($SD) {
                    foreach ($AccessRule in $SD.Access) {
                        if ($AccessRule.IdentityReference.Value -match $CarlosSID) {
                            if (($AccessRule.ActiveDirectoryRights -band 0x40000) -or # WriteDacl
                                ($AccessRule.ActiveDirectoryRights -band 0x10000000)) { # GenericAll
                                
                                $Results += [PSCustomObject]@{
                                    Nom = $UserName
                                    DN = $UserDN
                                    Droits = $AccessRule.ActiveDirectoryRights.ToString()
                                }
                                
                                Write-Host "  -> Carlos a WriteDacl sur: $UserName" -ForegroundColor Green
                            }
                        }
                    }
                }
            } catch {
                # Ignorer les erreurs
            }
        }
    } catch {
        # Ignorer les erreurs
    }
}

# Étape 3: Afficher les résultats
Write-Host ""
Write-Host "=== Résultats ===" -ForegroundColor Yellow

if ($Results.Count -gt 0) {
    Write-Host "Carlos peut gérer les utilisateurs suivants:" -ForegroundColor Green
    foreach ($Result in $Results) {
        Write-Host "  -> $($Result.Nom)" -ForegroundColor Green
        Write-Host "     Droits: $($Result.Droits)" -ForegroundColor Gray
    }
    
    $Answer = $Results[0].Nom
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "RÉPONSE FINALE: $Answer" -ForegroundColor Yellow -BackgroundColor Black
    Write-Host "==================================================" -ForegroundColor Cyan
} else {
    Write-Host "Aucun compte utilisateur trouvé avec WriteDacl pour Carlos" -ForegroundColor Yellow
    
    # Vérifier si Carlos a des droits sur d'autres objets
    Write-Host ""
    Write-Host "Vérification des autres objets (groupes, etc.)..." -ForegroundColor Gray
    
    $Searcher.Filter = "(objectClass=group)"
    $Groups = $Searcher.FindAll()
    
    foreach ($Group in $Groups) {
        try {
            $GroupDN = $Group.Properties.distinguishedName[0]
            $GroupName = $Group.Properties.name[0]
            
            $ACL = Get-ACL -Path "AD:\$GroupDN" -ErrorAction SilentlyContinue
            foreach ($AccessRule in $ACL.Access) {
                if ($AccessRule.IdentityReference.Value -match $CarlosSID) {
                    if (($AccessRule.ActiveDirectoryRights -band 0x40000) -or 
                        ($AccessRule.ActiveDirectoryRights -band 0x10000000)) {
                        Write-Host "  -> Carlos a WriteDacl sur le groupe: $GroupName" -ForegroundColor Yellow
                    }
                }
            }
        } catch {}
    }
}
