New-UDPage -Url "/Create-User" -Name "Create User" -Content {
    New-UDForm -Content {
        New-UDAlert -Text "Remplissez les informations pour créer un utilisateur CNAS."

        New-UDTextbox -Id 'FirstName' -Label 'Prénom'
        New-UDTextbox -Id 'LastName' -Label 'Nom'
        New-UDTextbox -Id 'UserName' -Label "Nom d'ouverture de session"
        New-UDTextbox -Id 'Password' -Label 'Mot de passe' -Type password

        # Sélecteur OU
        New-UDSelect -Id 'OU' -Label 'Unité Organisationnelle' -Option {
            # Racine CNAS-Users
            New-UDSelectOption -Name "Direction Générale" -Value "OU=DirectionGenerale,OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz"
            New-UDSelectOption -Name "Service Prestations" -Value "OU=ServicePrestations,OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz"
            New-UDSelectOption -Name "Service Recouvrement" -Value "OU=ServiceRecouvrement,OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz"
            New-UDSelectOption -Name "Service Financier" -Value "OU=ServiceFinancier,OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz"
            New-UDSelectOption -Name "Controle Médical" -Value "OU=ControleMedical,OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz"
            New-UDSelectOption -Name "Centre Informatique" -Value "OU=CentreInformatique,OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz"

            # Centres Paiement
            New-UDSelectOption -Name "Centre Paiement - Medea Ville" -Value "OU=MedeaVille,OU=CentresPaiement,OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz"
            New-UDSelectOption -Name "Centre Paiement - Berrouaghia" -Value "OU=Berrouaghia,OU=CentresPaiement,OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz"
            New-UDSelectOption -Name "Centre Paiement - Ksar El Boukhari" -Value "OU=KsarElBoukhari,OU=CentresPaiement,OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz"
            New-UDSelectOption -Name "Centre Paiement - Tablat" -Value "OU=Tablat,OU=CentresPaiement,OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz"
            New-UDSelectOption -Name "Centre Paiement - Chellalet" -Value "OU=Chellalet,OU=CentresPaiement,OU=CNAS-Users,DC=ag26,DC=cnas,DC=dz"
        }
    } -OnValidate {
        if (-not $EventData.FirstName -or -not $EventData.LastName -or -not $EventData.UserName -or -not $EventData.Password -or -not $EventData.OU) {
            New-UDFormValidationResult -ValidationError "Tous les champs sont obligatoires."
        }
        else {
            New-UDFormValidationResult -Valid
        }
  } -OnSubmit {
    try {
        $securePass = ConvertTo-SecureString $EventData.Password -AsPlainText -Force
        $upn = "$($EventData.UserName)@ag26.cnas.dz"

        # Création utilisateur
        $newUser = New-ADUser `
            -Name "$($EventData.FirstName) $($EventData.LastName)" `
            -GivenName $EventData.FirstName `
            -Surname $EventData.LastName `
            -SamAccountName $EventData.UserName `
            -UserPrincipalName $upn `
            -Path $EventData.OU `
            -AccountPassword $securePass `
            -ChangePasswordAtLogon $true `
            -Enabled $false `
            -PassThru

        # Wait a moment for AD to process
        Start-Sleep -Seconds 2

        # Now explicitly enable the account
        Enable-ADAccount -Identity $EventData.UserName

        # Verify the account is enabled
        $user = Get-ADUser -Identity $EventData.UserName -Properties Enabled
        if (-not $user.Enabled) {
            Write-Warning "Account created but still disabled. Trying again..."
            Enable-ADAccount -Identity $EventData.UserName
            Start-Sleep -Seconds 1
            $user = Get-ADUser -Identity $EventData.UserName -Properties Enabled
        }

        # Attribution automatique au bon groupe CNAS
        switch -Wildcard ($EventData.OU) {
            "*DirectionGenerale*"    { Add-ADGroupMember -Identity "GRP-Users-Direction" -Members $EventData.UserName }
            "*ServicePrestations*"   { Add-ADGroupMember -Identity "GRP-Users-Prestations" -Members $EventData.UserName }
            "*ServiceRecouvrement*"  { Add-ADGroupMember -Identity "GRP-Users-Recouvrement" -Members $EventData.UserName }
            "*ServiceFinancier*"     { Add-ADGroupMember -Identity "GRP-Users-Financier" -Members $EventData.UserName }
            "*ControleMedical*"      { Add-ADGroupMember -Identity "GRP-Users-ControleMedical" -Members $EventData.UserName }
            "*CentreInformatique*"   { Add-ADGroupMember -Identity "GRP-Users-Informatique" -Members $EventData.UserName }

            "*MedeaVille*"           { Add-ADGroupMember -Identity "GRP-Users-Centre-MedeaVille" -Members $EventData.UserName }
            "*Berrouaghia*"          { Add-ADGroupMember -Identity "GRP-Users-Centre-Berrouaghia" -Members $EventData.UserName }
            "*KsarElBoukhari*"       { Add-ADGroupMember -Identity "GRP-Users-Centre-KsarElBoukhari" -Members $EventData.UserName }
            "*Tablat*"               { Add-ADGroupMember -Identity "GRP-Users-Centre-Tablat" -Members $EventData.UserName }
            "*Chellalet*"            { Add-ADGroupMember -Identity "GRP-Users-Centre-Chellalet" -Members $EventData.UserName }
        }

        # Final status check
        $finalUser = Get-ADUser -Identity $EventData.UserName -Properties Enabled
        $status = if ($finalUser.Enabled) { "✅ activé" } else { "⚠️ créé mais désactivé" }
        
        Show-UDToast -Message "Utilisateur $($EventData.UserName) $status dans $($EventData.OU) et ajouté au groupe correspondant."
        
    } catch {
        Show-UDToast -Message "❌ Erreur lors de la création: $($_.Exception.Message)" -MessageType Error
        Write-Error $_.Exception.Message
    }
}
}

