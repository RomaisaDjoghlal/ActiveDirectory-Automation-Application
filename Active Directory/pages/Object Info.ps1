New-UDPage -Url "/Object-Info/:guid" -Name "Object Info" -Content {
    # Extract the GUID from the URL parameter - try multiple methods
    $Guid = $null
    
    # Method 1: Try Cache RouteData (PSU v3+)
    if ($Cache:RouteData -and $Cache:RouteData.guid) {
        $Guid = $Cache:RouteData.guid
    }
    # Method 2: Try direct parameter access (PSU v2)
    elseif ($PSBoundParameters.ContainsKey('guid')) {
        $Guid = $PSBoundParameters['guid']
    }
    # Method 3: Try EventData (alternative method)
    elseif ($EventData -and $EventData.guid) {
        $Guid = $EventData.guid
    }
    
    # Debug information
    Write-Host "Debug - GUID parameter: '$Guid'"
    Write-Host "Debug - Cache:RouteData: $($Cache:RouteData | ConvertTo-Json -Compress)"
    Write-Host "Debug - PSBoundParameters: $($PSBoundParameters | ConvertTo-Json -Compress)"
    
    # Validate GUID
    if ([string]::IsNullOrEmpty($Guid)) {
        New-UDAlert -Severity error -Text "No user GUID provided in URL. Please navigate from the search page."
        return
    }
    
    # Validate GUID format
    try {
        $GuidObj = [System.Guid]::Parse($Guid)
    } catch {
        New-UDAlert -Severity error -Text "Invalid GUID format: $Guid"
        return
    }
    
    try {
        # First, try to get the user to display basic info
        $User = Get-ADUser -Identity $Guid -Properties DisplayName, SamAccountName -ErrorAction Stop
        $DisplayName = if ($User.DisplayName) { $User.DisplayName } else { $User.Name }
        
        New-UDTypography "Object - $DisplayName ($($User.SamAccountName))" -Variant h5
        New-UDHtml -Markup "<hr/>"
        
        # Check user roles (assuming $Roles is defined elsewhere in your dashboard)
        $MatchingRoles = $Roles | Where-Object { $_ -in @("Administrator", "AD Admin") }
        
        if ($MatchingRoles.Length -gt 0) {
            New-UDTypography "Double-click the values to edit them. Navigating away or pressing enter will save them to Active Directory."
            
            New-UDDataGrid -LoadRows {
                try {
                    # Get the object with all properties
                    $Object = Get-ADUser -Identity $Guid -Properties * -ErrorAction Stop
                    
                    # Filter out some system properties that shouldn't be edited
                    $ExcludeProperties = @(
                        'ObjectGUID', 'ObjectSid', 'SID', 'whenCreated', 'whenChanged', 
                        'uSNCreated', 'uSNChanged', 'instanceType', 'objectCategory',
                        'dSCorePropagationData', 'nTSecurityDescriptor', 'objectClass',
                        'distinguishedName', 'PropertyNames', 'PropertyCount'
                    )
                    
                    $Data = $Object.PSObject.Properties | Where-Object { 
                        $_.Name -notin $ExcludeProperties 
                    } | ForEach-Object {
                        [PSCustomObject]@{
                            Name = $_.Name
                            Value = if ($_.Value) { 
                                if ($_.Value -is [System.DateTime]) {
                                    $_.Value.ToString('yyyy-MM-dd HH:mm:ss')
                                } elseif ($_.Value -is [System.Array]) {
                                    $_.Value -join '; '
                                } else {
                                    $_.Value.ToString()
                                }
                            } else { 
                                "" 
                            }
                        }
                    } | Sort-Object Name
                    
                    @{
                        rows = $Data
                        rowCount = $Data.Length
                    }
                }
                catch {
                    Write-Error "Failed to load user data: $($_.Exception.Message)"
                    @{
                        rows = @()
                        rowCount = 0
                    }
                }
            } -Columns @(
                @{ field = "Name"; headerName = 'Property'; flex = 0.4; sortable = $true }
                @{ field = "Value"; headerName = 'Value'; flex = 0.6; editable = $true; sortable = $true }
            ) -OnEdit {
                try {
                    # Validate that we're not trying to edit system properties
                    $SystemProperties = @(
                        'ObjectGUID', 'ObjectSid', 'SID', 'whenCreated', 'whenChanged',
                        'uSNCreated', 'uSNChanged', 'instanceType', 'objectCategory',
                        'dSCorePropagationData', 'nTSecurityDescriptor', 'objectClass',
                        'distinguishedName'
                    )
                    
                    if ($EventData.NewRow.Name -in $SystemProperties) {
                        Show-UDToast -Message "Cannot edit system property: $($EventData.NewRow.Name)" -MessageColor red
                        return $EventData.OldRow.Value
                    }
                    
                    # Prepare the value for AD update
                    $PropertyName = $EventData.NewRow.Name
                    $NewValue = $EventData.NewRow.Value
                    
                    # Handle empty values
                    if ([string]::IsNullOrWhiteSpace($NewValue)) {
                        # Clear the attribute
                        Set-ADUser -Identity $Guid -Clear $PropertyName -ErrorAction Stop
                        Show-UDToast -Message "Cleared property: $PropertyName" -MessageColor green
                    } else {
                        # Set the attribute
                        $UpdateHash = @{}
                        $UpdateHash[$PropertyName] = $NewValue
                        Set-ADUser -Identity $Guid -Replace $UpdateHash -ErrorAction Stop
                        Show-UDToast -Message "Updated $PropertyName successfully" -MessageColor green
                    }
                    
                } catch {
                    $ErrorMessage = "Failed to update $($EventData.NewRow.Name): $($_.Exception.Message)"
                    Show-UDToast -Message $ErrorMessage -MessageColor red
                    Write-Error $ErrorMessage
                    # Return the old value to revert the change in the UI
                    return $EventData.OldRow.Value
                }
            } -Sort -Filter -Search
            
        } else {
            # Read-only view for non-admin users
            New-UDTypography "User Details (Read-only)" -Variant h6
            
            $Object = Get-ADUser -Identity $Guid -Properties * -ErrorAction Stop
            
            # Create a more user-friendly display for non-admin users
            $ImportantProperties = @(
                @{Name="Name"; Display="Full Name"},
                @{Name="SamAccountName"; Display="Username"},
                @{Name="UserPrincipalName"; Display="Email/UPN"},
                @{Name="GivenName"; Display="First Name"},
                @{Name="Surname"; Display="Last Name"},
                @{Name="DisplayName"; Display="Display Name"},
                @{Name="Title"; Display="Job Title"},
                @{Name="Department"; Display="Department"},
                @{Name="Manager"; Display="Manager"},
                @{Name="OfficePhone"; Display="Office Phone"},
                @{Name="MobilePhone"; Display="Mobile Phone"},
                @{Name="EmailAddress"; Display="Email Address"},
                @{Name="Office"; Display="Office Location"},
                @{Name="Company"; Display="Company"},
                @{Name="Description"; Display="Description"},
                @{Name="Enabled"; Display="Account Status"},
                @{Name="PasswordLastSet"; Display="Password Last Set"},
                @{Name="LastLogonDate"; Display="Last Login"},
                @{Name="whenCreated"; Display="Account Created"},
                @{Name="DistinguishedName"; Display="Location in AD"}
            )
            
            $Data = $ImportantProperties | ForEach-Object {
                $PropValue = $Object.($_.Name)
                $DisplayValue = if ($PropValue) {
                    if ($PropValue -is [System.DateTime]) {
                        $PropValue.ToString('yyyy-MM-dd HH:mm:ss')
                    } elseif ($_.Name -eq "Enabled") {
                        if ($PropValue) { "Active" } else { "Disabled" }
                    } elseif ($_.Name -eq "Manager" -and $PropValue) {
                        # Try to get manager's display name
                        try {
                            $ManagerObj = Get-ADUser -Identity $PropValue -Properties DisplayName -ErrorAction Stop
                            if ($ManagerObj.DisplayName) { $ManagerObj.DisplayName } else { $ManagerObj.Name }
                        } catch {
                            $PropValue.ToString()
                        }
                    } else {
                        $PropValue.ToString()
                    }
                } else {
                    "Not specified"
                }
                
                [PSCustomObject]@{
                    Property = $_.Display
                    Value = $DisplayValue
                }
            }
            
            New-UDTable -Data $Data -Columns @(
                New-UDTableColumn -Property Property -Title "Property" -Width 200
                New-UDTableColumn -Property Value -Title "Value"
            )
        }
        
    } catch {
        New-UDAlert -Severity error -Text "Error loading user information: $($_.Exception.Message)"
        Write-Error "Error in Object-Info page: $($_.Exception.Message)"
    }
} -Icon 'User'