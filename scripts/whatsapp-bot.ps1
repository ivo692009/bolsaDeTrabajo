[CmdletBinding()]
param(
    [switch]$SelfTest,
    [int]$Port = 8080,
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ObjectField {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function ConvertTo-NormalizedText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $builder = New-Object System.Text.StringBuilder
    foreach ($character in $normalized.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }
    return ([regex]::Replace($builder.ToString().ToLowerInvariant(), '\s+', ' ')).Trim()
}

function ConvertTo-WhatsAppE164 {
    param([string]$Number)
    $digits = [regex]::Replace([string]$Number, '\D', '')
    if ($digits.Length -lt 8 -or $digits.Length -gt 15) { return $null }
    return "+$digits"
}

function Test-ConstantTimeString {
    param([string]$Left, [string]$Right)
    if ($null -eq $Left -or $null -eq $Right -or $Left.Length -ne $Right.Length) { return $false }
    $difference = 0
    for ($index = 0; $index -lt $Left.Length; $index++) {
        $difference = $difference -bor ([int][char]$Left[$index] -bxor [int][char]$Right[$index])
    }
    return $difference -eq 0
}

function Get-HmacSignature {
    param([byte[]]$Body, [string]$Secret)
    $key = [Text.Encoding]::UTF8.GetBytes($Secret)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256(,$key)
    try {
        $digest = $hmac.ComputeHash($Body)
        return 'sha256=' + ([BitConverter]::ToString($digest).Replace('-', '').ToLowerInvariant())
    }
    finally {
        $hmac.Dispose()
    }
}

function Test-WebhookSignature {
    param([byte[]]$Body, [string]$Signature, [string]$Secret)
    if ([string]::IsNullOrWhiteSpace($Signature) -or [string]::IsNullOrWhiteSpace($Secret)) { return $false }
    return Test-ConstantTimeString -Left (Get-HmacSignature -Body $Body -Secret $Secret) -Right $Signature.ToLowerInvariant()
}

function Get-MessageIntent {
    param([string]$Text)
    $normalized = ConvertTo-NormalizedText $Text
    if ($normalized -match 'fuga de gas|olor a gas|emergencia|incendio|electrocut|peligro inmediato|cortocircuito') {
        return @{ Name = 'emergency'; Query = '' }
    }
    if ($normalized -match '^(hola|buenos dias|buenas tardes|buenas noches|menu|ayuda|inicio)$') {
        return @{ Name = 'menu'; Query = '' }
    }
    if ($normalized -match '^(mi perfil|ver mi perfil|mis datos)$') {
        return @{ Name = 'profile'; Query = '' }
    }
    if ($normalized -match '^(pausar perfil|dejar de recibir ofertas|desactivar perfil)$') {
        return @{ Name = 'pause'; Query = '' }
    }
    if ($normalized -match '^(reactivar perfil|volver a recibir ofertas|activar perfil)$') {
        return @{ Name = 'reactivate'; Query = '' }
    }
    if ($normalized -match '^(aceptar|acepto|rechazar|rechazo)\s+([a-z0-9]{4,10})$') {
        return @{ Name = 'offer_response'; Query = $normalized }
    }
    if ($normalized -match '^(buscar|busco|necesito|quiero contratar)\s+(.+)$') {
        return @{ Name = 'search'; Query = $Matches[2] }
    }
    return @{ Name = 'fallback'; Query = '' }
}

function Write-SafeLog {
    param([string]$Level, [string]$Event, [string]$MessageId = '')
    $suffix = if ($MessageId) { " message_id=$MessageId" } else { '' }
    Write-Host "$(Get-Date -Format o) [$Level] $Event$suffix"
}

function Read-XmlFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Archivo requerido no encontrado: $Path" }
    return [xml][IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}

function Save-XmlAtomically {
    param([xml]$Document, [string]$Path)
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        [void](New-Item -ItemType Directory -Path $directory -Force)
    }
    $temporaryPath = "$Path.$PID.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        $Document.Save($temporaryPath)
        [void][xml][IO.File]::ReadAllText($temporaryPath, [Text.Encoding]::UTF8)
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $backupDirectory = Join-Path (Join-Path $ProjectRoot 'backups') ([IO.Path]::GetFileNameWithoutExtension($Path))
            if (-not (Test-Path -LiteralPath $backupDirectory)) {
                [void](New-Item -ItemType Directory -Path $backupDirectory -Force)
            }
            $backupPath = Join-Path $backupDirectory ((Get-Date).ToString('yyyyMMdd') + '.xml')
            if (-not (Test-Path -LiteralPath $backupPath)) {
                Copy-Item -LiteralPath $Path -Destination $backupPath
            }
            $replaceBackupPath = "$Path.$PID.$([guid]::NewGuid().ToString('N')).bak"
            try {
                [IO.File]::Replace($temporaryPath, $Path, $replaceBackupPath)
            }
            finally {
                if (Test-Path -LiteralPath $replaceBackupPath) { Remove-Item -LiteralPath $replaceBackupPath -Force }
            }
            $oldBackups = @(Get-ChildItem -LiteralPath $backupDirectory -Filter '*.xml' -File | Sort-Object Name -Descending | Select-Object -Skip 90)
            foreach ($backup in $oldBackups) { Remove-Item -LiteralPath $backup.FullName -Force }
        }
        else {
            [IO.File]::Move($temporaryPath, $Path)
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
    }
}

function Get-WebhookStore {
    param([int]$Year)
    $path = Join-Path (Join-Path $ProjectRoot 'data/webhook-events') "$Year.xml"
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        return @{ Path = $path; Document = (Read-XmlFile $path) }
    }
    $document = New-Object System.Xml.XmlDocument
    $declaration = $document.CreateXmlDeclaration('1.0', 'UTF-8', $null)
    [void]$document.AppendChild($declaration)
    $root = $document.CreateElement('processedMessages')
    $root.SetAttribute('year', [string]$Year)
    $root.SetAttribute('updatedAt', [DateTime]::UtcNow.ToString('o'))
    [void]$document.AppendChild($root)
    return @{ Path = $path; Document = $document }
}

function Find-WebhookRecord {
    param([xml]$Document, [string]$MessageId)
    foreach ($record in @($Document.processedMessages.SelectNodes('message'))) {
        if ($record.id -ceq $MessageId) { return $record }
    }
    return $null
}

function Initialize-RuntimeFiles {
    $runtimeFiles = @(
        @{ Target = 'data/professionals.xml'; Template = 'data/templates/professionals.template.xml' },
        @{ Target = 'data/requests.xml'; Template = 'data/templates/requests.template.xml' },
        @{ Target = 'data/admin-whatsapp-numbers.xml'; Template = 'data/templates/admin-whatsapp-numbers.template.xml' }
    )
    foreach ($file in $runtimeFiles) {
        $targetPath = Join-Path $ProjectRoot $file.Target
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) { continue }
        $templatePath = Join-Path $ProjectRoot $file.Template
        if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) { throw "Falta plantilla runtime: $($file.Template)" }
        $targetDirectory = Split-Path -Parent $targetPath
        if (-not (Test-Path -LiteralPath $targetDirectory)) { [void](New-Item -ItemType Directory -Path $targetDirectory -Force) }
        Copy-Item -LiteralPath $templatePath -Destination $targetPath
    }
}

function Start-WebhookMessage {
    param([string]$MessageId, [DateTime]$ReceivedAt)
    $store = Get-WebhookStore -Year $ReceivedAt.Year
    $record = Find-WebhookRecord -Document $store.Document -MessageId $MessageId
    if ($null -ne $record -and $record.status -ne 'failed') {
        return @{ ShouldProcess = $false; Store = $store; Record = $record }
    }
    if ($null -eq $record) {
        $record = $store.Document.CreateElement('message')
        $record.SetAttribute('id', $MessageId)
        $record.SetAttribute('receivedAt', $ReceivedAt.ToUniversalTime().ToString('o'))
        $record.SetAttribute('attemptCount', '0')
        [void]$store.Document.processedMessages.AppendChild($record)
    }
    $attempt = 0
    [void][int]::TryParse($record.GetAttribute('attemptCount'), [ref]$attempt)
    $record.SetAttribute('attemptCount', [string]($attempt + 1))
    $record.SetAttribute('status', 'processing')
    $record.SetAttribute('result', '')
    $store.Document.processedMessages.SetAttribute('updatedAt', [DateTime]::UtcNow().ToString('o'))
    Save-XmlAtomically -Document $store.Document -Path $store.Path
    return @{ ShouldProcess = $true; Store = $store; Record = $record }
}

function Complete-WebhookMessage {
    param($Store, [string]$MessageId, [string]$Status, [string]$Result)
    $document = Read-XmlFile $Store.Path
    $record = Find-WebhookRecord -Document $document -MessageId $MessageId
    if ($null -eq $record) { throw 'No se encontró el evento para actualizar.' }
    $record.SetAttribute('status', $Status)
    $record.SetAttribute('result', $Result)
    $document.processedMessages.SetAttribute('updatedAt', [DateTime]::UtcNow().ToString('o'))
    Save-XmlAtomically -Document $document -Path $Store.Path
}

function Get-MatchingService {
    param([string]$Query)
    $catalogPath = Join-Path $ProjectRoot 'data/service-categories.xml'
    $catalog = Read-XmlFile $catalogPath
    $normalizedQuery = ConvertTo-NormalizedText $Query
    $matches = New-Object System.Collections.Generic.List[object]
    foreach ($category in @($catalog.serviceCatalog.category)) {
        if ($category.GetAttribute('active') -ne 'true') { continue }
        $categoryTerms = New-Object System.Collections.Generic.List[string]
        $categoryTerms.Add([string]$category.name)
        foreach ($alias in @($category.aliases.alias)) { if ($alias) { $categoryTerms.Add([string]$alias) } }
        $categoryMatchLength = 0
        foreach ($term in $categoryTerms) {
            $normalizedTerm = ConvertTo-NormalizedText $term
            if ($normalizedTerm.Length -gt 1 -and $normalizedQuery.Contains($normalizedTerm)) {
                $categoryMatchLength = [Math]::Max($categoryMatchLength, $normalizedTerm.Length)
            }
        }
        if ($categoryMatchLength -gt 0) {
            $matches.Add([pscustomobject]@{ Category = $category; JobType = $null; MatchLength = $categoryMatchLength })
        }
        foreach ($jobType in @($category.jobTypes.jobType)) {
            if ($jobType.GetAttribute('active') -eq 'false') { continue }
            $jobTerms = New-Object System.Collections.Generic.List[string]
            if ($jobType.name) { $jobTerms.Add([string]$jobType.name) }
            if ($jobType.description) { $jobTerms.Add([string]$jobType.description) }
            foreach ($alias in @($jobType.aliases.alias)) { if ($alias) { $jobTerms.Add([string]$alias) } }
            $bestLength = 0
            foreach ($term in $jobTerms) {
                $normalizedTerm = ConvertTo-NormalizedText $term
                if ($normalizedTerm.Length -gt 1 -and $normalizedQuery.Contains($normalizedTerm)) {
                    $bestLength = [Math]::Max($bestLength, $normalizedTerm.Length)
                }
            }
            if ($bestLength -gt 0) {
                $matches.Add([pscustomobject]@{ Category = $category; JobType = $jobType; MatchLength = $bestLength })
            }
        }
    }
    if ($matches.Count -eq 0) { return $null }
    $longest = ($matches | Measure-Object -Property MatchLength -Maximum).Maximum
    $best = @($matches | Where-Object { $_.MatchLength -eq $longest })
    $distinctMatches = @($best | Group-Object {
        $categoryId = $_.Category.GetAttribute('id')
        $jobTypeId = if ($null -eq $_.JobType) { '' } else { $_.JobType.GetAttribute('id') }
        "$categoryId|$jobTypeId"
    })
    if ($distinctMatches.Count -ne 1) { return @{ Ambiguous = $true; Category = $null; JobType = $null } }
    return @{ Ambiguous = $false; Category = $best[0].Category; JobType = $best[0].JobType }
}

function Get-MatchingServiceArea {
    param([string]$Query)
    $policy = Read-XmlFile (Join-Path $ProjectRoot 'data/location-policy.xml')
    $normalizedQuery = ConvertTo-NormalizedText $Query
    $areaMatches = New-Object System.Collections.Generic.List[object]
    foreach ($area in @($policy.locationPolicy.serviceAreas.area)) {
        if ($area.GetAttribute('active') -ne 'true') { continue }
        $terms = New-Object System.Collections.Generic.List[string]
        if ($area.name) { $terms.Add([string]$area.name) }
        foreach ($alias in @($area.aliases.alias)) { if ($alias) { $terms.Add([string]$alias) } }
        $bestLength = 0
        foreach ($term in $terms) {
            $normalizedTerm = ConvertTo-NormalizedText $term
            if ($normalizedTerm.Length -gt 1 -and $normalizedQuery.Contains($normalizedTerm)) {
                $bestLength = [Math]::Max($bestLength, $normalizedTerm.Length)
            }
        }
        if ($bestLength -gt 0) {
            $areaMatches.Add([pscustomobject]@{ Area = $area; MatchLength = $bestLength })
        }
    }
    if ($areaMatches.Count -eq 0) { return $null }
    $longest = ($areaMatches | Measure-Object -Property MatchLength -Maximum).Maximum
    $best = @($areaMatches | Where-Object { $_.MatchLength -eq $longest })
    if (@($best | Group-Object { $_.Area.GetAttribute('id') }).Count -ne 1) { return @{ Ambiguous = $true; Area = $null } }
    return @{ Ambiguous = $false; Area = $best[0].Area }
}

function Get-HaversineDistanceKm {
    param([double]$Latitude1, [double]$Longitude1, [double]$Latitude2, [double]$Longitude2)
    $earthRadiusKm = 6371.0088
    $toRadians = [Math]::PI / 180
    $latitudeDelta = ($Latitude2 - $Latitude1) * $toRadians
    $longitudeDelta = ($Longitude2 - $Longitude1) * $toRadians
    $latitude1Radians = $Latitude1 * $toRadians
    $latitude2Radians = $Latitude2 * $toRadians
    $a = [Math]::Pow([Math]::Sin($latitudeDelta / 2), 2) + [Math]::Cos($latitude1Radians) * [Math]::Cos($latitude2Radians) * [Math]::Pow([Math]::Sin($longitudeDelta / 2), 2)
    $centralAngle = 2 * [Math]::Atan2([Math]::Sqrt($a), [Math]::Sqrt([Math]::Max(0, 1 - $a)))
    return [Math]::Round($earthRadiusKm * $centralAngle, 2)
}

function Get-ProfessionalMatches {
    param([string]$CategoryId, [string]$JobTypeId, [string]$Query, [string]$PreferredAreaId)
    $profiles = Read-XmlFile (Join-Path $ProjectRoot 'data/professionals.xml')
    $policy = Read-XmlFile (Join-Path $ProjectRoot 'data/location-policy.xml')
    $projectTimezone = $policy.locationPolicy.GetAttribute('timezone')
    $areaById = @{}
    foreach ($area in @($policy.locationPolicy.serviceAreas.area)) {
        if ($area.GetAttribute('active') -eq 'true') { $areaById[$area.GetAttribute('id')] = $area }
    }
    $normalizedQuery = ConvertTo-NormalizedText $Query
    $requestedDay = $null
    foreach ($day in @('lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo')) {
        if ($normalizedQuery -match "\b$day\b") { $requestedDay = $day; break }
    }
    $requestedTime = $null
    if ($normalizedQuery -match '\b([01]?[0-9]|2[0-3]):([0-5][0-9])\b') {
        $requestedTime = '{0:D2}:{1}' -f [int]$Matches[1], $Matches[2]
    }
    $professionalMatches = New-Object System.Collections.Generic.List[object]
    foreach ($profile in @($profiles.professionals.SelectNodes('professional'))) {
        if ($profile.GetAttribute('status') -ne 'active' -or $profile.GetAttribute('availabilityStatus') -ne 'active') { continue }
        foreach ($serviceCategory in @($profile.SelectNodes('serviceCategories/serviceCategory'))) {
            if ($serviceCategory.GetAttribute('id') -ne $CategoryId) { continue }
            $offersJob = @($serviceCategory.SelectNodes('jobTypes/jobType') | Where-Object { $_.GetAttribute('id') -eq $JobTypeId }).Count -gt 0
            if (-not $offersJob) { continue }
            $availableSlots = @($profile.SelectNodes('availability/slot') | Where-Object {
                $slotDay = ConvertTo-NormalizedText $_.day
                $profileTimezone = $profile.SelectSingleNode('availability').GetAttribute('timezone')
                $slotTimezone = if ($_.GetAttribute('timezone')) { $_.GetAttribute('timezone') } else { $profileTimezone }
                $timezoneMatches = -not [string]::IsNullOrWhiteSpace($projectTimezone) -and $slotTimezone -eq $projectTimezone
                $hasValidRange = $_.start -match '^([01][0-9]|2[0-3]):[0-5][0-9]$' -and $_.end -match '^([01][0-9]|2[0-3]):[0-5][0-9]$' -and $_.start -lt $_.end
                $dayMatches = $null -eq $requestedDay -or $slotDay -eq $requestedDay
                $timeMatches = $null -eq $requestedTime -or ($requestedTime -ge $_.start -and $requestedTime -lt $_.end)
                $timezoneMatches -and $hasValidRange -and $dayMatches -and $timeMatches
            })
            if ($availableSlots.Count -gt 0) {
                $declaredAreas = @($profile.SelectNodes('serviceAreas/area') | Where-Object {
                    $_.GetAttribute('active') -eq 'true' -and $areaById.ContainsKey($_.GetAttribute('id'))
                } | ForEach-Object { $_.GetAttribute('id') })
                if ($declaredAreas.Count -gt 0) {
                    $professionalMatches.Add([pscustomobject]@{ Profile = $profile; AvailableSlots = $availableSlots; AreaIds = $declaredAreas })
                }
                break
            }
        }
    }
    $candidateList = @($professionalMatches.ToArray())
    if (-not $PreferredAreaId) {
        return @{ MatchType = 'unranked'; HasDistance = $false; Candidates = @($candidateList | Sort-Object { $_.Profile.GetAttribute('id') }) }
    }
    $exactArea = @($candidateList | Where-Object { $_.AreaIds -contains $PreferredAreaId })
    if ($exactArea.Count -gt 0) {
        return @{ MatchType = 'requested_area'; HasDistance = $false; Candidates = @($exactArea | Sort-Object { $_.Profile.GetAttribute('id') }) }
    }
    $requestedArea = $areaById[$PreferredAreaId]
    $requestedPoint = $requestedArea.representativePoint
    $requestedLatitude = 0.0
    $requestedLongitude = 0.0
    $requestedBoundary = $requestedArea.SelectSingleNode('boundary')
    $hasRequestedPoint = $null -ne $requestedPoint -and $null -ne $requestedBoundary -and $requestedBoundary.GetAttribute('status') -eq 'configured' -and $requestedPoint.GetAttribute('status') -eq 'configured' -and [double]::TryParse($requestedPoint.GetAttribute('latitude'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$requestedLatitude) -and [double]::TryParse($requestedPoint.GetAttribute('longitude'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$requestedLongitude) -and $requestedLatitude -ge -90 -and $requestedLatitude -le 90 -and $requestedLongitude -ge -180 -and $requestedLongitude -le 180
    if (-not $hasRequestedPoint) {
        return @{ MatchType = 'distance_unavailable'; HasDistance = $false; Candidates = @($candidateList) }
    }
    $rankedCandidates = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in $candidateList) {
        $distances = New-Object System.Collections.Generic.List[double]
        foreach ($areaId in $candidate.AreaIds) {
            $point = $areaById[$areaId].representativePoint
            $latitude = 0.0
            $longitude = 0.0
            $boundary = $areaById[$areaId].SelectSingleNode('boundary')
            $hasPoint = $null -ne $point -and $null -ne $boundary -and $boundary.GetAttribute('status') -eq 'configured' -and $point.GetAttribute('status') -eq 'configured' -and [double]::TryParse($point.GetAttribute('latitude'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$latitude) -and [double]::TryParse($point.GetAttribute('longitude'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$longitude) -and $latitude -ge -90 -and $latitude -le 90 -and $longitude -ge -180 -and $longitude -le 180
            if ($hasPoint) { $distances.Add((Get-HaversineDistanceKm -Latitude1 $requestedLatitude -Longitude1 $requestedLongitude -Latitude2 $latitude -Longitude2 $longitude)) }
        }
        if ($distances.Count -gt 0) {
            $rankedCandidates.Add([pscustomobject]@{ Profile = $candidate.Profile; AvailableSlots = $candidate.AvailableSlots; DistanceKm = ($distances | Measure-Object -Minimum).Minimum })
        }
    }
    if ($rankedCandidates.Count -eq 0) {
        return @{ MatchType = 'distance_unavailable'; HasDistance = $false; Candidates = @($candidateList) }
    }
    return @{ MatchType = 'nearest_area'; HasDistance = $true; Candidates = @($rankedCandidates.ToArray() | Sort-Object DistanceKm, { $_.Profile.GetAttribute('id') }) }
}

function Get-OwnProfessional {
    param([string]$SenderE164)
    $profiles = Read-XmlFile (Join-Path $ProjectRoot 'data/professionals.xml')
    $matches = @($profiles.professionals.SelectNodes('professional') | Where-Object {
        (ConvertTo-WhatsAppE164 $_.whatsappPhone.e164) -eq $SenderE164
    })
    if ($matches.Count -gt 1) { throw 'Número vinculado a más de un perfil; se requiere revisión administrativa.' }
    if ($matches.Count -eq 0) { return $null }
    return @{ Document = $profiles; Profile = $matches[0] }
}

function Get-MenuReply {
    return "Hola. Soy el asistente de servicios de Rawson y Playa Unión.`n`nPuedes escribir:`n- buscar electricidad`n- mi perfil`n- pausar perfil`n- reactivar perfil`n- aceptar A7K2 / rechazar A7K2`n`nTodavía no confirmo direcciones ni creo ofertas hasta configurar el límite geográfico oficial."
}

function Get-EmergencyReply {
    return 'Esto puede ser una emergencia. La plataforma no atiende urgencias ni brinda instrucciones técnicas. Contacta de inmediato los servicios de emergencia locales. No tengo un número local verificado para proporcionarte.'
}

function Get-SearchReply {
    param([string]$Query)
    $match = Get-MatchingService -Query $Query
    if ($null -eq $match) {
        return "No pude identificar un rubro registrado. Escribe `buscar` seguido del trabajo, por ejemplo: `buscar electricidad`."
    }
    if ($match.Ambiguous) {
        return 'La descripción puede corresponder a más de un rubro. Indica la especialidad con otras palabras.'
    }
    $category = $match.Category
    if ($null -eq $match.JobType) {
        $jobNames = @($category.jobTypes.jobType | Where-Object { $_.GetAttribute('active') -ne 'false' } | ForEach-Object { $_.name })
        if ($jobNames.Count -eq 0) { return "El rubro $($category.name) no tiene trabajos activos definidos en el catálogo." }
        $jobList = @($jobNames | ForEach-Object { "- $_" })
        return "¿Qué trabajo de $($category.name) necesitas? Selecciona una opción del catálogo:`n$($jobList -join "`n")"
    }
    $areaMatch = Get-MatchingServiceArea -Query $Query
    if ($areaMatch -and $areaMatch.Ambiguous) { return 'No pude identificar una única zona. Indica Rawson o Playa Unión para ordenar opciones por cercanía.' }
    $preferredAreaId = if ($areaMatch) { $areaMatch.Area.GetAttribute('id') } else { $null }
    $professionalResults = Get-ProfessionalMatches -CategoryId $category.GetAttribute('id') -JobTypeId $match.JobType.GetAttribute('id') -Query $Query -PreferredAreaId $preferredAreaId
    $professionals = @($professionalResults.Candidates)
    if ($professionals.Count -eq 0) {
        return "No encuentro profesionales publicados con disponibilidad declarada para $($match.JobType.name)."
    }
    if ($professionalResults.MatchType -eq 'distance_unavailable') {
        return "Hay profesionales activos con disponibilidad declarada para $($match.JobType.name), pero no puedo ordenarlos por cercanía hasta configurar las zonas y puntos de referencia oficiales."
    }
    $lines = @($professionals | Select-Object -First 5 | ForEach-Object {
        $profile = $_.Profile
        $slotText = @($_.AvailableSlots | ForEach-Object { "$($_.day) $($_.start)-$($_.end)" }) -join ', '
        $distanceText = if ($professionalResults.MatchType -eq 'nearest_area') { " (zona cercana, aprox. $($_.DistanceKm) km)" } else { '' }
        "- $($profile.firstName) $($profile.lastName): $slotText$distanceText"
    })
    $rankLabel = if ($professionalResults.MatchType -eq 'nearest_area') { 'Opciones activas más cercanas que realizan' } elseif ($preferredAreaId) { 'Opciones activas en la zona que realizan' } else { 'Profesionales activos que realizan' }
    $locationHint = if (-not $preferredAreaId) { ' Indica Rawson o Playa Unión para filtrar por zona y ordenar alternativas por cercanía.' } else { '' }
    return "$rankLabel $($match.JobType.name):`n$($lines -join "`n")`n`nLa disponibilidad se basa en horarios y zonas declarados por cada profesional. No comparto teléfonos antes de una aceptación. Las distancias son aproximadas entre zonas, no rutas.$locationHint"
}

function Set-OwnAvailability {
    param([string]$SenderE164, [string]$AvailabilityStatus)
    $own = Get-OwnProfessional -SenderE164 $SenderE164
    if ($null -eq $own) { return 'No encuentro un perfil profesional vinculado a este número de WhatsApp.' }
    $profile = $own.Profile
    if ($profile.status -ne 'active') { return 'El perfil no está publicado. Contacta al administrador para revisar su estado antes de activarlo.' }
    if ($profile.availabilityStatus -eq $AvailabilityStatus) {
        if ($AvailabilityStatus -eq 'active') { return 'Tu perfil ya está activo.' }
        return 'Tu perfil ya está pausado.'
    }
    $previous = $profile.availabilityStatus
    $profile.SetAttribute('availabilityStatus', $AvailabilityStatus)
    $history = $profile.profileChangeHistory
    if ($null -eq $history) {
        $history = $own.Document.CreateElement('profileChangeHistory')
        [void]$profile.AppendChild($history)
    }
    $event = $own.Document.CreateElement('event')
    $event.SetAttribute('action', "availability_$AvailabilityStatus")
    $event.SetAttribute('byWhatsapp', $SenderE164)
    $event.SetAttribute('at', [DateTime]::UtcNow().ToString('o'))
    $event.SetAttribute('previousValue', [string]$previous)
    [void]$history.AppendChild($event)
    Save-XmlAtomically -Document $own.Document -Path (Join-Path $ProjectRoot 'data/professionals.xml')
    if ($AvailabilityStatus -eq 'active') { return 'Tu perfil volvió a estar activo y puede recibir nuevas ofertas.' }
    return 'Tu perfil quedó pausado y no recibirá nuevas ofertas. Las solicitudes ya aceptadas no se cancelan.'
}

function Invoke-OfferResponse {
    param([string]$SenderE164, [string]$Text)
    $normalized = ConvertTo-NormalizedText $Text
    if ($normalized -notmatch '^(aceptar|acepto|rechazar|rechazo)\s+([a-z0-9]{4,10})$') {
        return 'Para responder a una oferta, incluye su código; por ejemplo: `acepto A7K2`.'
    }
    $action = $Matches[1]
    $code = $Matches[2].ToUpperInvariant()
    $own = Get-OwnProfessional -SenderE164 $SenderE164
    if ($null -eq $own -or $own.Profile.status -ne 'active') {
        return 'No puedo validar un perfil profesional activo vinculado a este número.'
    }
    $requestsPath = Join-Path $ProjectRoot 'data/requests.xml'
    $requests = Read-XmlFile $requestsPath
    $candidates = @($requests.requests.SelectNodes('request') | Where-Object {
        $_.requestCode -ceq $code -and $_.professional.id -ceq $own.Profile.id
    })
    if ($candidates.Count -ne 1) { return 'No encuentro una oferta única con ese código para este número.' }
    $request = $candidates[0]
    if ($request.status -ne 'offered' -or $request.professional.response -ne 'pending') {
        return 'Esa oferta ya no está pendiente y no se modificó.'
    }
    if ($request.locationStatus -ne 'validated_in_area') {
        return 'La oferta no puede confirmarse porque su ubicación todavía no está validada dentro del área de servicio.'
    }
    $accepted = $action -in @('aceptar', 'acepto')
    if ($accepted) {
        $request.professional.SetAttribute('response', 'accepted')
        $request.professional.SetAttribute('respondedAt', [DateTime]::UtcNow().ToString('o'))
        $request.SetAttribute('status', 'connected')
        $result = 'accepted'
    }
    else {
        $request.professional.SetAttribute('response', 'rejected')
        $request.professional.SetAttribute('respondedAt', [DateTime]::UtcNow().ToString('o'))
        $request.SetAttribute('status', 'rejected')
        $result = 'rejected'
    }
    $event = $requests.CreateElement('event')
    $event.SetAttribute('status', $result)
    $event.SetAttribute('at', [DateTime]::UtcNow().ToString('o'))
    $event.SetAttribute('actor', $SenderE164)
    [void]$request.timeline.AppendChild($event)
    Save-XmlAtomically -Document $requests -Path $requestsPath

    if ($accepted) {
        $clientNumber = ConvertTo-WhatsAppE164 $request.client.phone
        if ($clientNumber) {
            $professionalName = "$($own.Profile.firstName) $($own.Profile.lastName)"
            Send-WhatsAppText -To $clientNumber -Text "El profesional $professionalName aceptó tu solicitud $code. Su teléfono de WhatsApp es $SenderE164. Ya pueden coordinar el trabajo."
            Send-WhatsAppText -To $SenderE164 -Text "Aceptaste la solicitud $code. El contacto del cliente es $clientNumber."
        }
        return "Registré tu aceptación de la oferta $code."
    }
    $clientNumber = ConvertTo-WhatsAppE164 $request.client.phone
    if ($clientNumber) {
        Send-WhatsAppText -To $clientNumber -Text "El profesional no aceptó la solicitud $code. Puedes volver a buscar otra opción escribiendo `buscar` y el rubro."
    }
    return "Registré el rechazo de la oferta $code."
}

function Get-BotReply {
    param([string]$Sender, [string]$Text)
    $senderE164 = ConvertTo-WhatsAppE164 $Sender
    if ($null -eq $senderE164) { return 'No pude validar el número remitente de WhatsApp.' }
    $intent = Get-MessageIntent -Text $Text
    switch ($intent.Name) {
        'menu' { return Get-MenuReply }
        'emergency' { return Get-EmergencyReply }
        'search' { return Get-SearchReply -Query $intent.Query }
        'profile' {
            $own = Get-OwnProfessional -SenderE164 $senderE164
            if ($null -eq $own) { return 'No encuentro un perfil profesional vinculado a este número. Puedes buscar un servicio escribiendo `buscar` y el rubro.' }
            $categories = @($own.Profile.serviceCategories.serviceCategory | ForEach-Object { $_.id })
            $categoryText = if ($categories.Count) { $categories -join ', ' } else { 'sin rubros publicados' }
            return "Perfil: $($own.Profile.firstName) $($own.Profile.lastName). Estado: $($own.Profile.availabilityStatus). Rubros: $categoryText."
        }
        'pause' { return Set-OwnAvailability -SenderE164 $senderE164 -AvailabilityStatus 'inactive' }
        'reactivate' { return Set-OwnAvailability -SenderE164 $senderE164 -AvailabilityStatus 'active' }
        'offer_response' { return Invoke-OfferResponse -SenderE164 $senderE164 -Text $Text }
        default { return 'No entendí el mensaje. Escribe `menu` para ver opciones o `buscar` seguido de un trabajo.' }
    }
}

function Send-WhatsAppText {
    param([string]$To, [string]$Text)
    $digits = [regex]::Replace($To, '\D', '')
    $uri = "https://graph.facebook.com/$script:GraphApiVersion/$script:PhoneNumberId/messages"
    $payload = @{
        messaging_product = 'whatsapp'
        recipient_type = 'individual'
        to = $digits
        type = 'text'
        text = @{ preview_url = $false; body = $Text }
    } | ConvertTo-Json -Depth 8
    $headers = @{ Authorization = "Bearer $script:AccessToken" }
    [void](Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 20)
}

function Get-InboundText {
    param($Message)
    switch ([string](Get-ObjectField $Message 'type')) {
        'text' { return [string](Get-ObjectField (Get-ObjectField $Message 'text') 'body') }
        'button' { return [string](Get-ObjectField (Get-ObjectField $Message 'button') 'text') }
        'interactive' {
            $interactive = Get-ObjectField $Message 'interactive'
            $buttonReply = Get-ObjectField $interactive 'button_reply'
            if ($null -ne $buttonReply) { return [string](Get-ObjectField $buttonReply 'title') }
            $listReply = Get-ObjectField $interactive 'list_reply'
            if ($null -ne $listReply) { return [string](Get-ObjectField $listReply 'title') }
        }
    }
    return ''
}

function Read-RequestBody {
    param([System.Net.HttpListenerRequest]$Request, [int]$MaximumBytes = 1048576)
    if ($Request.ContentLength64 -gt $MaximumBytes) { throw 'El webhook excede el límite permitido.' }
    $memory = New-Object IO.MemoryStream
    $buffer = New-Object byte[] 8192
    try {
        while (($read = $Request.InputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            if ($memory.Length + $read -gt $MaximumBytes) { throw 'El webhook excede el límite permitido.' }
            $memory.Write($buffer, 0, $read)
        }
        return ,$memory.ToArray()
    }
    finally { $memory.Dispose() }
}

function Send-HttpResponse {
    param([System.Net.HttpListenerResponse]$Response, [int]$StatusCode, [string]$Body = '', [string]$ContentType = 'text/plain; charset=utf-8')
    $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    $Response.ContentLength64 = $bytes.Length
    if ($bytes.Length -gt 0) { $Response.OutputStream.Write($bytes, 0, $bytes.Length) }
    $Response.Close()
}

function Get-WhatsAppMessages {
    param($Payload)
    $messages = New-Object System.Collections.Generic.List[object]
    foreach ($entry in @((Get-ObjectField $Payload 'entry'))) {
        foreach ($change in @((Get-ObjectField $entry 'changes'))) {
            $value = Get-ObjectField $change 'value'
            foreach ($message in @((Get-ObjectField $value 'messages'))) {
                if ($null -ne $message) { $messages.Add($message) }
            }
        }
    }
    return ,$messages.ToArray()
}

function Process-WhatsAppMessage {
    param($Message)
    $messageId = [string](Get-ObjectField $Message 'id')
    $sender = [string](Get-ObjectField $Message 'from')
    if ([string]::IsNullOrWhiteSpace($messageId) -or [string]::IsNullOrWhiteSpace($sender)) {
        Write-SafeLog -Level 'WARN' -Event 'message_missing_id_or_sender'
        return
    }
    $receivedAt = [DateTime]::UtcNow()
    $event = Start-WebhookMessage -MessageId $messageId -ReceivedAt $receivedAt
    if (-not $event.ShouldProcess) {
        Write-SafeLog -Level 'INFO' -Event 'duplicate_or_in_progress' -MessageId $messageId
        return
    }
    try {
        $text = Get-InboundText -Message $Message
        if ([string]::IsNullOrWhiteSpace($text)) {
            $reply = 'Por ahora puedo procesar mensajes de texto. Escribe `menu` para ver las opciones disponibles.'
        }
        else {
            $reply = Get-BotReply -Sender $sender -Text $text
        }
        Send-WhatsAppText -To (ConvertTo-WhatsAppE164 $sender) -Text $reply
        Complete-WebhookMessage -Store $event.Store -MessageId $messageId -Status 'processed' -Result 'reply_sent'
        Write-SafeLog -Level 'INFO' -Event 'message_processed' -MessageId $messageId
    }
    catch {
        try { Complete-WebhookMessage -Store $event.Store -MessageId $messageId -Status 'failed' -Result 'processing_error' } catch { }
        Write-SafeLog -Level 'ERROR' -Event $_.Exception.GetType().Name -MessageId $messageId
        throw
    }
}

function Invoke-SelfTest {
    $tests = 0
    $sourceProjectRoot = $ProjectRoot
    $menuIntent = Get-MessageIntent -Text 'Hola'
    if ($menuIntent.Name -ne 'menu') { throw 'Falló detección de saludo.' }; $tests++
    $searchIntent = Get-MessageIntent -Text 'Necesito un electricista'
    if ($searchIntent.Name -ne 'search') { throw 'Falló detección de búsqueda.' }; $tests++
    $offerIntent = Get-MessageIntent -Text 'ACEPTO A7K2'
    if ($offerIntent.Name -ne 'offer_response') { throw 'Falló detección de oferta.' }; $tests++
    $emergencyIntent = Get-MessageIntent -Text 'Hay olor a gas'
    if ($emergencyIntent.Name -ne 'emergency') { throw 'Falló detección de emergencia.' }; $tests++
    if ((ConvertTo-WhatsAppE164 '5492804000000') -ne '+5492804000000') { throw 'Falló normalización E.164.' }; $tests++
    $body = [Text.Encoding]::UTF8.GetBytes('{"test":"firma"}')
    $signature = Get-HmacSignature -Body $body -Secret 'test-secret'
    if (-not (Test-WebhookSignature -Body $body -Signature $signature -Secret 'test-secret')) { throw 'Falló validación de firma válida.' }; $tests++
    if (Test-WebhookSignature -Body $body -Signature 'sha256=invalid' -Secret 'test-secret') { throw 'Aceptó firma inválida.' }; $tests++
    $text = ConvertTo-NormalizedText 'PLomería en Rawson'
    if ($text -ne 'plomeria en rawson') { throw 'Falló normalización de acentos.' }; $tests++
    $service = Get-MatchingService -Query 'electricidad instalar luminaria'
    if ($null -eq $service -or $service.Category.id -ne 'electricidad' -or $service.JobType.id -ne 'instalaciones') { throw 'Falló búsqueda específica del catálogo XML.' }; $tests++
    $categoryOnly = Get-MatchingService -Query 'electricidad'
    if ($null -eq $categoryOnly -or $null -ne $categoryOnly.JobType) { throw 'Falló detección de consulta solo por rubro.' }; $tests++
    $testRoot = Join-Path $env:TEMP ('bolsaDeTrabajo-selftest-' + [guid]::NewGuid().ToString('N'))
    try {
        [void](New-Item -ItemType Directory -Path $testRoot -Force)
        $ProjectRoot = $testRoot
        $testDataDirectory = Join-Path $testRoot 'data'
        [void](New-Item -ItemType Directory -Path $testDataDirectory -Force)
        $runtimeTemplateDirectory = Join-Path $testDataDirectory 'templates'
        [void](New-Item -ItemType Directory -Path $runtimeTemplateDirectory -Force)
        foreach ($templateName in @('professionals.template.xml', 'requests.template.xml', 'admin-whatsapp-numbers.template.xml')) {
            Copy-Item -LiteralPath (Join-Path (Join-Path $sourceProjectRoot 'data/templates') $templateName) -Destination $runtimeTemplateDirectory
        }
        Initialize-RuntimeFiles
        if (-not (Test-Path (Join-Path $testDataDirectory 'professionals.xml')) -or -not (Test-Path (Join-Path $testDataDirectory 'requests.xml')) -or -not (Test-Path (Join-Path $testDataDirectory 'admin-whatsapp-numbers.xml'))) { throw 'No se inicializaron todos los XML runtime.' }; $tests++
        $testPolicy = New-Object System.Xml.XmlDocument
        [void]$testPolicy.LoadXml('<locationPolicy timezone="America/Argentina/Buenos_Aires"><serviceAreas><area id="rawson" active="true"><boundary status="configured" /><representativePoint latitude="-43.3" longitude="-65.1" status="configured" /></area><area id="playa-union" active="true"><boundary status="configured" /><representativePoint latitude="-43.3" longitude="-65.0" status="configured" /></area><area id="rawson-norte" active="true"><boundary status="configured" /><representativePoint latitude="-43.29" longitude="-65.1" status="configured" /></area></serviceAreas></locationPolicy>')
        Save-XmlAtomically -Document $testPolicy -Path (Join-Path $testDataDirectory 'location-policy.xml')
        $testProfiles = New-Object System.Xml.XmlDocument
        [void]$testProfiles.LoadXml('<professionals><professional id="exact" status="active" availabilityStatus="active"><serviceCategories><serviceCategory id="electricidad"><jobTypes><jobType id="reparaciones" /></jobTypes></serviceCategory></serviceCategories><serviceAreas><area id="rawson" active="true" /></serviceAreas><availability><slot day="lunes" start="09:00" end="17:00" timezone="America/Argentina/Buenos_Aires" /></availability></professional><professional id="near" status="active" availabilityStatus="active"><serviceCategories><serviceCategory id="electricidad"><jobTypes><jobType id="reparaciones" /></jobTypes></serviceCategory></serviceCategories><serviceAreas><area id="playa-union" active="true" /></serviceAreas><availability><slot day="lunes" start="09:00" end="17:00" timezone="America/Argentina/Buenos_Aires" /></availability></professional><professional id="inactive" status="active" availabilityStatus="inactive"><serviceCategories><serviceCategory id="electricidad"><jobTypes><jobType id="reparaciones" /></jobTypes></serviceCategory></serviceCategories><serviceAreas><area id="rawson" active="true" /></serviceAreas><availability><slot day="lunes" start="09:00" end="17:00" timezone="America/Argentina/Buenos_Aires" /></availability></professional><professional id="other-task" status="active" availabilityStatus="active"><serviceCategories><serviceCategory id="electricidad"><jobTypes><jobType id="instalaciones" /></jobTypes></serviceCategory></serviceCategories><serviceAreas><area id="rawson" active="true" /></serviceAreas><availability><slot day="lunes" start="09:00" end="17:00" timezone="America/Argentina/Buenos_Aires" /></availability></professional></professionals>')
        Save-XmlAtomically -Document $testProfiles -Path (Join-Path $testDataDirectory 'professionals.xml')
        $exactResult = Get-ProfessionalMatches -CategoryId 'electricidad' -JobTypeId 'reparaciones' -Query 'lunes 10:00' -PreferredAreaId 'rawson'
        if ($exactResult.MatchType -ne 'requested_area' -or @($exactResult.Candidates).Count -ne 1 -or $exactResult.Candidates[0].Profile.GetAttribute('id') -ne 'exact') { throw 'Falló filtro exacto de rubro, trabajo, disponibilidad y zona.' }; $tests++
        $nearestResult = Get-ProfessionalMatches -CategoryId 'electricidad' -JobTypeId 'reparaciones' -Query 'lunes 10:00' -PreferredAreaId 'rawson-norte'
        if ($nearestResult.MatchType -ne 'nearest_area' -or @($nearestResult.Candidates).Count -ne 2 -or $nearestResult.Candidates[0].Profile.GetAttribute('id') -ne 'exact' -or -not $nearestResult.HasDistance) { throw 'Falló orden de alternativas cercanas.' }; $tests++
        $testPolicy.locationPolicy.serviceAreas.area | Where-Object { $_.GetAttribute('id') -eq 'rawson-norte' } | ForEach-Object { $_.SelectSingleNode('boundary').SetAttribute('status', 'pending') }
        Save-XmlAtomically -Document $testPolicy -Path (Join-Path $testDataDirectory 'location-policy.xml')
        $unconfiguredDistance = Get-ProfessionalMatches -CategoryId 'electricidad' -JobTypeId 'reparaciones' -Query 'lunes 10:00' -PreferredAreaId 'rawson-norte'
        if ($unconfiguredDistance.MatchType -ne 'distance_unavailable' -or $unconfiguredDistance.HasDistance) { throw 'Calculó cercanía sin límite oficial configurado.' }; $tests++
        $timeFilteredResult = Get-ProfessionalMatches -CategoryId 'electricidad' -JobTypeId 'reparaciones' -Query 'martes 10:00' -PreferredAreaId 'rawson'
        if (@($timeFilteredResult.Candidates).Count -ne 0) { throw 'Incluyó un profesional fuera del horario declarado.' }; $tests++
        $exactTestProfile = $testProfiles.professionals.professional | Where-Object { $_.GetAttribute('id') -eq 'exact' }
        $exactTestProfile.SelectSingleNode('availability/slot').SetAttribute('timezone', 'America/Chicago')
        Save-XmlAtomically -Document $testProfiles -Path (Join-Path $testDataDirectory 'professionals.xml')
        $timezoneFilteredResult = Get-ProfessionalMatches -CategoryId 'electricidad' -JobTypeId 'reparaciones' -Query 'lunes 10:00' -PreferredAreaId 'rawson'
        if (@($timezoneFilteredResult.Candidates | Where-Object { $_.Profile.GetAttribute('id') -eq 'exact' }).Count -ne 0) { throw 'Trató una zona horaria distinta como disponibilidad local.' }; $tests++
        $testPath = Join-Path $testRoot 'data/test.xml'
        $testDocument = New-Object System.Xml.XmlDocument
        [void]$testDocument.LoadXml('<test value="one" />')
        Save-XmlAtomically -Document $testDocument -Path $testPath
        $testDocument.DocumentElement.SetAttribute('value', 'two')
        Save-XmlAtomically -Document $testDocument -Path $testPath
        if ((Read-XmlFile $testPath).test.value -ne 'two') { throw 'Falló reemplazo atómico XML.' }
        if (-not (Test-Path (Join-Path $testRoot 'backups/test'))) { throw 'Falló backup previo al reemplazo XML.' }
        $tests += 2
    }
    finally {
        if (Test-Path $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
    }
    Write-Output "Self-test OK: $tests verificaciones"
}

if ($SelfTest) {
    Invoke-SelfTest
    return
}

$script:AppSecret = [Environment]::GetEnvironmentVariable('WA_APP_SECRET')
$script:VerifyToken = [Environment]::GetEnvironmentVariable('WA_VERIFY_TOKEN')
$script:AccessToken = [Environment]::GetEnvironmentVariable('WA_ACCESS_TOKEN')
$script:PhoneNumberId = [Environment]::GetEnvironmentVariable('WA_PHONE_NUMBER_ID')
$script:GraphApiVersion = [Environment]::GetEnvironmentVariable('WA_GRAPH_API_VERSION')

$missing = @()
foreach ($required in @(@{ Name = 'WA_APP_SECRET'; Value = $script:AppSecret }, @{ Name = 'WA_VERIFY_TOKEN'; Value = $script:VerifyToken }, @{ Name = 'WA_ACCESS_TOKEN'; Value = $script:AccessToken }, @{ Name = 'WA_PHONE_NUMBER_ID'; Value = $script:PhoneNumberId }, @{ Name = 'WA_GRAPH_API_VERSION'; Value = $script:GraphApiVersion })) {
    if ([string]::IsNullOrWhiteSpace($required.Value)) { $missing += $required.Name }
}
if ($missing.Count -gt 0) { throw "Configura estas variables de entorno antes de iniciar: $($missing -join ', ')" }
if ($script:GraphApiVersion -notmatch '^v\d+\.\d+$') { throw 'WA_GRAPH_API_VERSION debe tener formato vNN.0.' }
if ($Port -lt 1024 -or $Port -gt 65535) { throw 'El puerto debe estar entre 1024 y 65535.' }
Initialize-RuntimeFiles

$mutex = New-Object System.Threading.Mutex($false, 'Local\BolsaDeTrabajoWhatsAppBot')
$hasMutex = $false
$listener = $null
try {
    try { $hasMutex = $mutex.WaitOne(0, $false) } catch [System.Threading.AbandonedMutexException] { $hasMutex = $true }
    if (-not $hasMutex) { throw 'Ya hay otra instancia del bot ejecutándose.' }
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://127.0.0.1:$Port/")
    $listener.Start()
    Write-SafeLog -Level 'INFO' -Event "webhook_listening_localhost_$Port"
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $request = $context.Request
            if ($request.Url.AbsolutePath -ne '/webhook') {
                Send-HttpResponse -Response $context.Response -StatusCode 404 -Body 'Not found'
                continue
            }
            if ($request.HttpMethod -eq 'GET') {
                $mode = $request.QueryString['hub.mode']
                $token = $request.QueryString['hub.verify_token']
                $challenge = $request.QueryString['hub.challenge']
                if ($mode -eq 'subscribe' -and (Test-ConstantTimeString -Left $token -Right $script:VerifyToken)) {
                    Send-HttpResponse -Response $context.Response -StatusCode 200 -Body $challenge
                }
                else {
                    Send-HttpResponse -Response $context.Response -StatusCode 403 -Body 'Forbidden'
                }
                continue
            }
            if ($request.HttpMethod -ne 'POST') {
                Send-HttpResponse -Response $context.Response -StatusCode 405 -Body 'Method not allowed'
                continue
            }
            if ($request.ContentLength64 -gt 1048576) {
                Send-HttpResponse -Response $context.Response -StatusCode 413 -Body 'Payload too large'
                continue
            }
            $body = Read-RequestBody -Request $request
            $signature = $request.Headers['X-Hub-Signature-256']
            if (-not (Test-WebhookSignature -Body $body -Signature $signature -Secret $script:AppSecret)) {
                Send-HttpResponse -Response $context.Response -StatusCode 401 -Body 'Invalid signature'
                continue
            }
            $payload = [Text.Encoding]::UTF8.GetString($body) | ConvertFrom-Json
            $messages = @(Get-WhatsAppMessages -Payload $payload)
            foreach ($message in $messages) { Process-WhatsAppMessage -Message $message }
            Send-HttpResponse -Response $context.Response -StatusCode 200 -Body 'EVENT_RECEIVED'
        }
        catch {
            Write-SafeLog -Level 'ERROR' -Event $_.Exception.GetType().Name
            try { Send-HttpResponse -Response $context.Response -StatusCode 500 -Body 'Processing failed' } catch { }
        }
    }
}
finally {
    if ($listener -and $listener.IsListening) { $listener.Stop(); $listener.Close() }
    if ($hasMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
