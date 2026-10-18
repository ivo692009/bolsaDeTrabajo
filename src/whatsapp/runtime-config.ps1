Set-StrictMode -Version Latest

function Read-DotEnvFile {
    param([Parameter(Mandatory)][string]$Path)
    $values = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $values }
    $lineNumber = 0
    foreach ($line in [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)) {
        $lineNumber++
        $trimmedLine = $line.Trim()
        if (-not $trimmedLine -or $trimmedLine.StartsWith('#')) { continue }
        if ($trimmedLine -notmatch '^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') { throw ".env tiene sintaxis inválida en la línea $lineNumber. No se mostró su contenido por seguridad." }
        $key = $Matches[1]
        $value = $Matches[2].Trim()
        if ($value.Length -ge 2 -and (($value[0] -eq '"' -and $value[$value.Length - 1] -eq '"') -or ($value[0] -eq "'" -and $value[$value.Length - 1] -eq "'"))) { $value = $value.Substring(1, $value.Length - 2) }
        else { $value = ($value -replace '\s+#.*$', '').Trim() }
        $values[$key] = $value
    }
    return $values
}

function Resolve-WhatsAppRuntimeConfiguration {
    param([Parameter(Mandatory)][string]$ProjectRoot, [int]$PortOverride = 0)
    $fileValues = Read-DotEnvFile -Path (Join-Path $ProjectRoot '.env')
    $getValue = {
        param([string]$Name, [string]$Default = '')
        $processValue = [Environment]::GetEnvironmentVariable($Name, 'Process')
        if (-not [string]::IsNullOrWhiteSpace($processValue)) { return $processValue }
        if ($fileValues.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace([string]$fileValues[$Name])) { return [string]$fileValues[$Name] }
        return $Default
    }
    $getInteger = {
        param([string]$Name, [int]$Default, [int]$Minimum, [int]$Maximum)
        $raw = & $getValue $Name ([string]$Default)
        $parsed = $Default
        if (-not [int]::TryParse([string]$raw, [ref]$parsed) -or $parsed -lt $Minimum -or $parsed -gt $Maximum) { throw "$Name must be an integer between $Minimum and $Maximum." }
        return $parsed
    }
    $port = & $getInteger 'WA_PORT' 8080 1024 65535
    $displayPhoneNumber = & $getValue 'WA_DISPLAY_PHONE_NUMBER'
    $phoneNumberSource = 'not_configured'
    if (-not [string]::IsNullOrWhiteSpace([string]$displayPhoneNumber)) { $phoneNumberSource = 'business_number' }
    else { $displayPhoneNumber = & $getValue 'WA_TEST_PHONE_NUMBER'; if (-not [string]::IsNullOrWhiteSpace([string]$displayPhoneNumber)) { $phoneNumberSource = 'meta_test_number' } }
    if ($PortOverride -gt 0) {
        if ($PortOverride -lt 1024 -or $PortOverride -gt 65535) { throw 'El parámetro Port debe estar entre 1024 y 65535.' }
        $port = $PortOverride
    }
    $bodyLimit = & $getInteger 'WA_WEBHOOK_MAX_BODY_BYTES' 1048576 1024 2147483647
    return [pscustomobject]@{
        Port = $port; MaximumBodyBytes = $bodyLimit
        AppSecret = (& $getValue 'WA_APP_SECRET')
        PreferencesHmacKey = (& $getValue 'WA_PREFERENCES_HMAC_KEY')
        VerifyToken = (& $getValue 'WA_VERIFY_TOKEN')
        AccessToken = (& $getValue 'WA_ACCESS_TOKEN')
        PhoneNumberId = (& $getValue 'WA_PHONE_NUMBER_ID')
        DisplayPhoneNumber = [string]$displayPhoneNumber
        DisplayPhoneNumberSource = $phoneNumberSource
        GraphApiVersion = (& $getValue 'WA_GRAPH_API_VERSION')
        OpenAiApiKey = (& $getValue 'OPENAI_API_KEY')
        OpenAiModel = (& $getValue 'OPENAI_MODEL' 'gpt-6-astra')
        OpenAiModerationTimeoutSeconds = (& $getInteger 'WA_OPENAI_MODERATION_TIMEOUT_SECONDS' 12 1 300)
        OpenAiResponseTimeoutSeconds = (& $getInteger 'WA_OPENAI_RESPONSE_TIMEOUT_SECONDS' 25 1 300)
        WhatsAppRequestTimeoutSeconds = (& $getInteger 'WA_WHATSAPP_REQUEST_TIMEOUT_SECONDS' 20 1 300)
    }
}
