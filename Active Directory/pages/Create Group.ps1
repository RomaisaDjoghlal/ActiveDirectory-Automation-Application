New-UDPage -Url "/Create-Group" -Name "Create Group" -Content {
    New-UDTypography -Text "Create CNAS Group" -Variant h4
    New-UDElement -Tag 'br'
    
    New-UDForm -Content {
        New-UDTextbox -Id "groupName" -Label 'Group Name' -Placeholder 'Enter group name (will be prefixed with GRP-Users-)'
        
        New-UDSelect -Id 'scope' -Label 'Group Scope' -Option {
            New-UDSelectOption -Name 'Global' -Value 'Global'
            New-UDSelectOption -Name 'Domain Local' -Value 'DomainLocal'
            New-UDSelectOption -Name 'Universal' -Value 'Universal'
        } -DefaultValue 'Global'
        
        New-UDSelect -Id 'category' -Label 'Group Type' -Option {
            New-UDSelectOption -Name 'Security' -Value 'Security'
            New-UDSelectOption -Name 'Distribution' -Value 'Distribution'
        } -DefaultValue 'Security'
        
        New-UDTextbox -Id "description" -Label 'Description (Optional)' -Placeholder 'Enter group description'
        
    } -SubmitText "Create Group" -ButtonVariant "contained" -OnValidate {
        if (-not $EventData.groupName -or $EventData.groupName.Trim() -eq "") {
            New-UDFormValidationResult -ValidationError "Group name is required"
        } else {
            New-UDFormValidationResult -Valid
        }
        
    } -OnSubmit {
        try {
            # Clean the group name and add prefix
            $cleanName = $EventData.groupName.Trim() -replace '[^a-zA-Z0-9-]', ''
            $fullGroupName = "GRP-Users-$cleanName"
            
            # Check if group already exists
            try {
                Get-ADGroup -Identity $fullGroupName -ErrorAction Stop
                Show-UDToast -Message "Group '$fullGroupName' already exists!" -MessageColor error -Duration 4000
                return
            } catch {
                # Group doesn't exist, continue
            }
            
            # Set description
            $desc = if ($EventData.description -and $EventData.description.Trim() -ne "") {
                $EventData.description.Trim()
            } else {
                "CNAS Security group for $cleanName"
            }
            
            # Create the group
            New-ADGroup -Name $fullGroupName -GroupScope $EventData.scope -GroupCategory $EventData.category -Path "OU=CNAS-Groups,DC=ag26,DC=cnas,DC=dz" -Description $desc -ErrorAction Stop
            
            Show-UDToast -Message "Group '$fullGroupName' created successfully!" -MessageColor success -Duration 4000
            
            # Clear form
            Set-UDElement -Id 'groupName' -Properties @{value = ''}
            Set-UDElement -Id 'description' -Properties @{value = ''}
            
        } catch {
            Show-UDToast -Message "Error: $($_.Exception.Message)" -MessageColor error -Duration 5000
        }
    }
    
} -Icon (New-UDIcon -Icon 'UserPlus')