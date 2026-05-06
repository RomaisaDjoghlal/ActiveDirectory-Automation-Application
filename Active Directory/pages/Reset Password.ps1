New-UDPage -Url "/Reset-Password" -Name "Reset Password" -Icon (New-UDIcon -Icon 'Lock' -Style @{ marginRight = "10px" }) -Content {
    New-UDForm -Content {
        New-UDTextbox -Id 'txtIdentity' -Label 'User Name' -Placeholder 'Username or email'
        New-UDTextbox -Id 'txtPassword' -Label 'New Password (optional)' -Type password -Placeholder 'Leave empty for unlock-only'
        New-UDCheckbox -Id 'chkUnlock' -Label 'Unlock Account'
        New-UDCheckbox -Id 'chkChangePasswordOnLogon' -Label 'Change password on logon'
    } -OnSubmit {
        try {
            # Validate user exists first
            try {
                $User = Get-ADUser -Identity $EventData.txtIdentity -Properties LockedOut, Enabled -ErrorAction Stop
                Write-Host "Processing user: $($User.Name) ($($User.SamAccountName))"
            } catch {
                Show-UDToast -Message "User '$($EventData.txtIdentity)' not found" -MessageColor red
                return
            }
            
            $SuccessActions = @()
            $HasErrors = $false
            
            # STEP 1: Reset password (ONLY if password provided)
            if (![string]::IsNullOrEmpty($EventData.txtPassword)) {
                try {
                    $SecurePassword = ConvertTo-SecureString $EventData.txtPassword -AsPlainText -Force
                    Set-ADAccountPassword -Identity $EventData.txtIdentity -NewPassword $SecurePassword -Reset -ErrorAction Stop
                    $SuccessActions += "Password reset"
                    Write-Host "✓ Password reset successful for $($User.SamAccountName)"
                } catch {
                    Show-UDToast -Message "Password reset failed: $($_.Exception.Message)" -MessageColor red
                    $HasErrors = $true
                }
            }
            
            # STEP 2: Unlock account (if requested)
            if ($EventData.chkUnlock) {
                try {
                    if ($User.LockedOut) {
                        Unlock-ADAccount -Identity $EventData.txtIdentity -ErrorAction Stop
                        $SuccessActions += "Account unlocked"
                        Write-Host "✓ Account unlocked for $($User.SamAccountName)"
                    } else {
                        $SuccessActions += "Account was not locked"
                        Write-Host "ℹ Account was not locked for $($User.SamAccountName)"
                    }
                } catch {
                    Show-UDToast -Message "Account unlock failed: $($_.Exception.Message)" -MessageColor red
                    $HasErrors = $true
                }
            }
            
            # STEP 3: Force password change (if requested)
            if ($EventData.chkChangePasswordOnLogon) {
                try {
                    Set-ADUser -Identity $EventData.txtIdentity -ChangePasswordAtLogon $true -ErrorAction Stop
                    $SuccessActions += "Password change required at logon"
                    Write-Host "✓ Password change at logon set for $($User.SamAccountName)"
                } catch {
                    Show-UDToast -Message "Failed to set password change requirement: $($_.Exception.Message)" -MessageColor red
                    $HasErrors = $true
                }
            }
            
            # Show results
            if ($SuccessActions.Count -gt 0) {
                $ActionSummary = $SuccessActions -join ", "
                $ToastColor = if ($HasErrors) { "orange" } else { "green" }
                $StatusText = if ($HasErrors) { "Completed with some errors" } else { "Successfully completed" }
                
                Show-UDToast -Message "$StatusText for '$($User.Name)': $ActionSummary" -MessageColor $ToastColor -Duration 6000
            } elseif (-not $HasErrors) {
                Show-UDToast -Message "No actions selected for '$($User.Name)'" -MessageColor orange -Duration 4000
            }
            
        } catch {
            $ErrorMessage = "Operation failed: $($_.Exception.Message)"
            Show-UDToast -Message $ErrorMessage -MessageColor red -Duration 5000
            Write-Error $ErrorMessage
        }
    } -SubmitText "Execute" -ButtonVariant "contained"
    
   
}