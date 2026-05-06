New-UDPage -Url "/Search-Users" -Name "Search Users" -Content {
    New-UDTypography -Text "Search for users in your organization" -Variant h4
    New-UDElement -Tag 'p'
    
    New-UDCard -Content {
        New-UDForm -Content {
            # Simple text search
            New-UDTextbox -Label 'Search by Name (First or Last)' -Id 'nameSearch' -Placeholder 'e.g., Ahmed, Bensaid, or Ahmed Bensaid'
            
            # Department dropdown based on your structure
            New-UDSelect -Label 'Department' -Id 'department' -Option {
                New-UDSelectOption -Name 'All Departments' -Value ''
                New-UDSelectOption -Name 'Direction Generale' -Value 'DirectionGenerale'
                New-UDSelectOption -Name 'Service Prestations' -Value 'ServicePrestations'
                New-UDSelectOption -Name 'Service Recouvrement' -Value 'ServiceRecouvrement'
                New-UDSelectOption -Name 'Service Financier' -Value 'ServiceFinancier'
                New-UDSelectOption -Name 'Controle Medical' -Value 'ControleMedical'
                New-UDSelectOption -Name 'Centre Informatique' -Value 'CentreInformatique'
            } -DefaultValue ''
            
            # Payment Centers dropdown
            New-UDSelect -Label 'Payment Center' -Id 'paymentCenter' -Option {
                New-UDSelectOption -Name 'All Centers' -Value ''
                New-UDSelectOption -Name 'Medea Ville' -Value 'MedeaVille'
                New-UDSelectOption -Name 'Berrouaghia' -Value 'Berrouaghia'
                New-UDSelectOption -Name 'Ksar El Boukhari' -Value 'KsarElBoukhari'
                New-UDSelectOption -Name 'Tablat' -Value 'Tablat'
                New-UDSelectOption -Name 'Chellalet' -Value 'Chellalet'
            } -DefaultValue '' -Multiple:$false
            
            # Account status
            New-UDSelect -Label 'Account Status' -Id 'accountStatus' -Option {
                New-UDSelectOption -Name 'All Users' -Value ''
                New-UDSelectOption -Name 'Active Users Only' -Value 'enabled'
                New-UDSelectOption -Name 'Disabled Users Only' -Value 'disabled'
            } -DefaultValue ''
            
        } -OnSubmit {
            # Clear previous error messages
            $Session:ErrorMessage = $null
            
            # Debug: Show raw form data
            Write-Host "Raw EventData:"
            $EventData | Format-List | Out-String | Write-Host
            
            # Clean up form values - handle cases where display names are sent instead of values
            $departmentValue = $EventData.department
            $paymentCenterValue = $EventData.paymentCenter  
            $accountStatusValue = $EventData.accountStatus
            
            # Convert display names to empty strings if they match the "All" options
            if ($departmentValue -eq 'All Departments') {
                $departmentValue = ''
            }
            if ($paymentCenterValue -eq 'All Centers') {
                $paymentCenterValue = ''
            }
            if ($accountStatusValue -eq 'All Users') {
                $accountStatusValue = ''
            }
            
            Write-Host "Cleaned values:"
            Write-Host "Department: '$departmentValue'"
            Write-Host "Payment Center: '$paymentCenterValue'"
            Write-Host "Account Status: '$accountStatusValue'"
            
            # Build filter based on user-friendly inputs
            $filters = @()
            
            # Name search - search both first and last names
            if ($EventData.nameSearch -and $EventData.nameSearch.Trim() -ne '') {
                $searchTerm = $EventData.nameSearch.Trim()
                $nameFilter = "((Name -like '*$searchTerm*') -or (GivenName -like '*$searchTerm*') -or (Surname -like '*$searchTerm*'))"
                $filters += $nameFilter
            }
            
            # Account status filter
            if ($accountStatusValue -eq 'enabled') {
                $filters += "Enabled -eq `$true"
            } elseif ($accountStatusValue -eq 'disabled') {
                $filters += "Enabled -eq `$false"
            }
            
            # Build the initial filter
            if ($filters.Count -gt 0) {
                $baseFilter = $filters -join " -and "
            } else {
                $baseFilter = "*"
            }
            
            try {
                # Get all users first with base filter
                Write-Host "Base Filter: $baseFilter"
                
                $rawUsers = Get-ADUser -Filter $baseFilter -Properties Department, Title, Manager, LastLogonDate, Created, Enabled, DistinguishedName, Description, ObjectGUID
                Write-Host "Raw users found: $($rawUsers.Count)"
                
                # Apply OU-based filtering in PowerShell (more reliable than AD filter)
                # Only filter by department if a specific department is selected (not empty or null)
                if (![string]::IsNullOrEmpty($departmentValue)) {
                    Write-Host "Filtering by department: '$departmentValue'"
                    $rawUsers = $rawUsers | Where-Object { 
                        $_.DistinguishedName -like "*OU=$departmentValue,OU=CNAS-Users*" 
                    }
                    Write-Host "Users after department filter: $($rawUsers.Count)"
                } else {
                    Write-Host "No department filter applied - showing all departments"
                }
                
                # Only filter by payment center if a specific center is selected (not empty or null)
                if (![string]::IsNullOrEmpty($paymentCenterValue)) {
                    Write-Host "Filtering by payment center: '$paymentCenterValue'"
                    $rawUsers = $rawUsers | Where-Object { 
                        $_.DistinguishedName -like "*OU=$paymentCenterValue*" 
                    }
                    Write-Host "Users after payment center filter: $($rawUsers.Count)"
                } else {
                    Write-Host "No payment center filter applied - showing all centers"
                }
                
                # Process users to extract department from DistinguishedName if Department field is empty
                $Session:Objects = $rawUsers | ForEach-Object {
                    $user = $_
                    
                    # Extract department from DistinguishedName if Department is empty
                    if ([string]::IsNullOrEmpty($user.Department)) {
                        if ($user.DistinguishedName -match 'OU=([^,]+),OU=CNAS-Users') {
                            $ouName = $matches[1]
                            # Map OU names to friendly department names
                            switch ($ouName) {
                                'DirectionGenerale' { $user | Add-Member -NotePropertyName 'DepartmentFromOU' -NotePropertyValue 'Direction Generale' -Force }
                                'ServicePrestations' { $user | Add-Member -NotePropertyName 'DepartmentFromOU' -NotePropertyValue 'Service Prestations' -Force }
                                'ServiceRecouvrement' { $user | Add-Member -NotePropertyName 'DepartmentFromOU' -NotePropertyValue 'Service Recouvrement' -Force }
                                'ServiceFinancier' { $user | Add-Member -NotePropertyName 'DepartmentFromOU' -NotePropertyValue 'Service Financier' -Force }
                                'ControleMedical' { $user | Add-Member -NotePropertyName 'DepartmentFromOU' -NotePropertyValue 'Controle Medical' -Force }
                                'CentreInformatique' { $user | Add-Member -NotePropertyName 'DepartmentFromOU' -NotePropertyValue 'Centre Informatique' -Force }
                                default { 
                                    if ($user.DistinguishedName -match 'OU=([^,]+),OU=CentresPaiement') {
                                        $centerName = $matches[1]
                                        $user | Add-Member -NotePropertyName 'DepartmentFromOU' -NotePropertyValue "Centre de Paiement - $centerName" -Force
                                    } else {
                                        $user | Add-Member -NotePropertyName 'DepartmentFromOU' -NotePropertyValue $ouName -Force
                                    }
                                }
                            }
                        } else {
                            $user | Add-Member -NotePropertyName 'DepartmentFromOU' -NotePropertyValue 'Unknown' -Force
                        }
                    } else {
                        $user | Add-Member -NotePropertyName 'DepartmentFromOU' -NotePropertyValue $user.Department -Force
                    }
                    
                    # Extract job title from OU if Title is empty (most specific OU)
                    if ([string]::IsNullOrEmpty($user.Title)) {
                        if ($user.DistinguishedName -match '^CN=[^,]+,OU=([^,]+)') {
                            $mostSpecificOU = $matches[1]
                            $user | Add-Member -NotePropertyName 'JobTitleFromOU' -NotePropertyValue $mostSpecificOU -Force
                        } else {
                            $user | Add-Member -NotePropertyName 'JobTitleFromOU' -NotePropertyValue 'Not Specified' -Force
                        }
                    } else {
                        $user | Add-Member -NotePropertyName 'JobTitleFromOU' -NotePropertyValue $user.Title -Force
                    }
                    
                    return $user
                }
                
                $Session:SearchPerformed = $true
                
                # Debug information
                Write-Host "Department selected: '$departmentValue'"
                Write-Host "Payment Center selected: '$paymentCenterValue'"
                Write-Host "Final result count: $($Session:Objects.Count)"
                
                # Additional debug - show a sample of found users' DNs
                if ($Session:Objects.Count -gt 0) {
                    Write-Host "Sample Distinguished Names:"
                    $Session:Objects | Select-Object -First 3 | ForEach-Object {
                        Write-Host "  - $($_.DistinguishedName)"
                        Write-Host "  - ObjectGUID: $($_.ObjectGUID)"
                    }
                }
                
            } catch {
                $Session:Objects = @()
                $Session:ErrorMessage = "Search failed: $($_.Exception.Message)"
                Write-Host "Search Error: $($_.Exception.Message)"
            }
            
            Sync-UDElement -Id 'adObjects'
        } -SubmitText "Search Users" -ButtonVariant "contained"
    }
    
    New-UDDynamic -Id 'adObjects' -Content {
        if ($Session:ErrorMessage) {
            New-UDAlert -Severity error -Text $Session:ErrorMessage
            return
        }
        
        if (-not $Session:SearchPerformed) {
            New-UDTypography -Text "Use the search form above to find users in your organization" -Variant body1
            return
        }
        
        if ($Session:Objects -eq $null -or $Session:Objects.Count -eq 0) {
            New-UDAlert -Severity info -Text "No users found matching your search criteria. Try adjusting your filters or use a different search term."
            return
        }
        
        New-UDTypography -Text "Found $($Session:Objects.Count) user(s)" -Variant h6
        New-UDElement -Tag 'p'
        
        New-UDTable -Title 'Search Results' -Data $Session:Objects -Columns @(
            New-UDTableColumn -Property Name -Title "Full Name" -Filter
            New-UDTableColumn -Property SamAccountName -Title "Username" -Filter
            New-UDTableColumn -Property DepartmentFromOU -Title "Department" -Filter
            New-UDTableColumn -Property JobTitleFromOU -Title "Job Title" -Filter
            New-UDTableColumn -Property Enabled -Title "Status" -Render {
                if ($EventData.Enabled) {
                    New-UDChip -Label "Active" -Color success
                } else {
                    New-UDChip -Label "Disabled" -Color error
                }
            }
            New-UDTableColumn -Property LastLogonDate -Title "Last Login" -Render {
                if ($EventData.LastLogonDate) {
                    $EventData.LastLogonDate.ToString('dd/MM/yyyy HH:mm')
                } else {
                    "Never"
                }
            }
            New-UDTableColumn -Property Created -Title "Created" -Render {
                if ($EventData.Created) {
                    $EventData.Created.ToString('dd/MM/yyyy')
                } else {
                    "Unknown"
                }
            }
        ) -Filter -Sort -Export
    }
}
