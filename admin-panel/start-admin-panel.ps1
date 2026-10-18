[CmdletBinding()]
param(
    [int]$Port = 8787,
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$script:PanelRoot = $PSScriptRoot
$script:StorePath = Join-Path $script:ProjectRoot 'runtime/data/admin-review-cases.json'
. (Join-Path $script:ProjectRoot 'src/whatsapp/runtime-config.ps1')
$script:TokenBytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($script:TokenBytes) } finally { $rng.Dispose() }
$script:Token = [Convert]::ToBase64String($script:TokenBytes).TrimEnd('=').Replace('+','-').Replace('/','_')
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

class PanelHttpResponse {
    [int]$StatusCode = 200
    [string]$ContentType = 'text/plain; charset=utf-8'
    [System.Collections.Specialized.NameValueCollection]$Headers
    [System.IO.MemoryStream]$OutputStream
    [long]$ContentLength64 = 0
    PanelHttpResponse() { $this.Headers=New-Object System.Collections.Specialized.NameValueCollection; $this.OutputStream=New-Object System.IO.MemoryStream }
    [void]Close() {}
}

function Read-TcpContext([System.Net.Sockets.TcpClient]$Client) {
    $stream=$Client.GetStream();$headerBuffer=New-Object IO.MemoryStream;$last=New-Object 'System.Collections.Generic.Queue[byte]'
    while($headerBuffer.Length -lt 16384){$b=$stream.ReadByte();if($b -lt 0){throw 'Conexión cerrada antes de leer encabezados.'};$headerBuffer.WriteByte([byte]$b);$last.Enqueue([byte]$b);if($last.Count -gt 4){[void]$last.Dequeue()};if($last.Count -eq 4 -and (@($last.ToArray()) -join ',') -eq '13,10,13,10'){break}}
    if($headerBuffer.Length -ge 16384){throw 'Encabezados HTTP demasiado grandes.'}
    $headerText=[Text.Encoding]::ASCII.GetString($headerBuffer.ToArray());$lines=$headerText -split "`r`n";$requestParts=$lines[0] -split ' ',3
    if($requestParts.Count -lt 2){throw 'Solicitud HTTP inválida.'}
    $headers=New-Object System.Collections.Specialized.NameValueCollection;$contentLength=0
    foreach($line in @($lines | Select-Object -Skip 1)){if(-not $line){continue};$separator=$line.IndexOf(':');if($separator -lt 1){continue};$name=$line.Substring(0,$separator).Trim();$value=$line.Substring($separator+1).Trim();$headers[$name]=$value;if($name -ieq 'Content-Length'){[void][int]::TryParse($value,[ref]$contentLength)}}
    if($contentLength -gt 7500000){throw 'El cuerpo supera el límite permitido.'}
    $bodyBytes=New-Object byte[] $contentLength;$read=0
    while($read -lt $contentLength){$n=$stream.Read($bodyBytes,$read,$contentLength-$read);if($n -le 0){throw 'Cuerpo HTTP incompleto.'};$read+=$n}
    $uri=[Uri]::new("http://127.0.0.1:$Port$($requestParts[1])")
    $request=[pscustomobject]@{HttpMethod=$requestParts[0];Url=$uri;Headers=$headers;ContentLength64=[long]$contentLength;ContentEncoding=[Text.Encoding]::UTF8;InputStream=[IO.MemoryStream]::new($bodyBytes)}
    return [pscustomobject]@{Request=$request;Response=(New-Object PanelHttpResponse);Client=$Client}
}

function Send-TcpResponse($Context) {
    $status=$Context.Response.StatusCode;$reason=switch($status){200{'OK'}201{'Created'}204{'No Content'}400{'Bad Request'}401{'Unauthorized'}403{'Forbidden'}404{'Not Found'}409{'Conflict'}413{'Payload Too Large'}500{'Internal Server Error'}503{'Service Unavailable'}default{'OK'}}
    $bytes=$Context.Response.OutputStream.ToArray();$headers=New-Object Text.StringBuilder
    [void]$headers.Append("HTTP/1.1 $status $reason`r`nContent-Type: $($Context.Response.ContentType)`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n")
    foreach($key in $Context.Response.Headers.AllKeys){[void]$headers.Append("$key`: $($Context.Response.Headers[$key])`r`n")}
    [void]$headers.Append("`r`n");$headerBytes=[Text.Encoding]::ASCII.GetBytes($headers.ToString());$stream=$Context.Client.GetStream();$stream.Write($headerBytes,0,$headerBytes.Length);if($bytes.Length){$stream.Write($bytes,0,$bytes.Length)};$stream.Flush()
}

function Get-XmlDocumentOrNull([string]$RelativePath) {
    $path = Join-Path $script:ProjectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return [xml][IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
}

function Save-XmlDocument([xml]$Document, [string]$RelativePath) {
    $path = Join-Path $script:ProjectRoot $RelativePath
    $directory = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $directory)) { [void](New-Item -ItemType Directory -Path $directory -Force) }
    $temp = "$path.$([guid]::NewGuid().ToString('N')).tmp"
    $backupDirectory = Join-Path $script:ProjectRoot 'runtime/backups/admin-panel'
    try {
        $Document.Save($temp)
        [void][xml][IO.File]::ReadAllText($temp, [Text.Encoding]::UTF8)
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            if (-not (Test-Path -LiteralPath $backupDirectory)) { [void](New-Item -ItemType Directory -Path $backupDirectory -Force) }
            $backup = Join-Path $backupDirectory (([IO.Path]::GetFileNameWithoutExtension($path)) + '-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '.xml')
            Copy-Item -LiteralPath $path -Destination $backup
            [IO.File]::Replace($temp, $path, $null)
        } else { [IO.File]::Move($temp, $path) }
    }
    finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}

function Read-ReviewStore {
    if (-not (Test-Path -LiteralPath $script:StorePath -PathType Leaf)) { return [pscustomobject]@{ version = 1; cases = @(); audit = @() } }
    $raw = [IO.File]::ReadAllText($script:StorePath, [Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($raw)) { return [pscustomobject]@{ version = 1; cases = @(); audit = @() } }
    return ($raw | ConvertFrom-Json)
}

function Save-ReviewStore($Store) {
    $directory = Split-Path -Parent $script:StorePath
    if (-not (Test-Path -LiteralPath $directory)) { [void](New-Item -ItemType Directory -Path $directory -Force) }
    $temp = "$($script:StorePath).$([guid]::NewGuid().ToString('N')).tmp"
    try {
        $json = ConvertTo-Json -InputObject $Store -Depth 12
        [IO.File]::WriteAllText($temp, $json, $script:Utf8NoBom)
        if (Test-Path -LiteralPath $script:StorePath -PathType Leaf) { [IO.File]::Replace($temp, $script:StorePath, $null) }
        else { [IO.File]::Move($temp, $script:StorePath) }
    }
    finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}

function Get-AdminEntries {
    $doc = Get-XmlDocumentOrNull 'runtime/data/admin-whatsapp-numbers.xml'
    $result = @()
    if ($null -eq $doc) { return $result }
    foreach ($node in @($doc.SelectNodes('//*[self::admin or self::entry]'))) {
        $enabled = $node.GetAttribute('enabled')
        if ($enabled -and $enabled -notin @('true','1','yes')) { continue }
        $id = $node.GetAttribute('id')
        if (-not $id) { continue }
        $roles = @()
        foreach ($attrName in @('roles','role')) {
            $attr = $node.GetAttribute($attrName)
            if ($attr) { $roles += @($attr -split '[,;\s]+' | Where-Object { $_ }) }
        }
        foreach ($roleNode in @($node.SelectNodes('.//role'))) {
            $role = $roleNode.GetAttribute('name')
            if (-not $role) { $role = $roleNode.GetAttribute('id') }
            if (-not $role) { $role = $roleNode.InnerText.Trim() }
            if ($role) { $roles += $role }
        }
        $result += [pscustomobject]@{ id = $id; roles = @($roles | Select-Object -Unique) }
    }
    return $result
}

function Test-AdminRole($AdminId, $Role) {
    $matches = @(Get-AdminEntries | Where-Object { $_.id -ceq [string]$AdminId })
    return ($matches.Count -eq 1 -and $Role -in $matches[0].roles)
}

function Get-QueryParameter([Uri]$Url, [string]$Name) {
    foreach ($part in @($Url.Query.TrimStart('?') -split '&')) {
        if (-not $part) { continue }
        $pair = $part -split '=', 2
        $key = [Uri]::UnescapeDataString($pair[0].Replace('+',' '))
        if ($key -ceq $Name) { if ($pair.Count -gt 1) { return [Uri]::UnescapeDataString($pair[1].Replace('+',' ')) }; return '' }
    }
    return ''
}

function Get-RequiredRole($Type) {
    switch -Regex ($Type) {
        '^(commission_payment|professional_deletion)$' { return 'commission_admin' }
        '^(prohibited_service|prohibited_service_policy)$' { return 'catalog_manager' }
        default { return 'professional_reliability_admin' }
    }
}

function Get-AnalyticsSnapshot([string]$FromValue, [string]$ToValue, [string]$ReasonFilter) {
    $from = [DateTimeOffset]::MinValue; $to = [DateTimeOffset]::MaxValue
    if (-not [DateTimeOffset]::TryParse($FromValue, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$from) -or -not [DateTimeOffset]::TryParse($ToValue, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$to) -or $from -gt $to) { throw 'Ventana de tiempo no válida.' }
    $points = New-Object System.Collections.Generic.List[object]
    $doc = Get-XmlDocumentOrNull 'runtime/data/requests.xml'
    if ($null -ne $doc) {
        foreach ($request in @(Get-XmlRecords $doc 'request')) {
            $analytics = $request.SelectSingleNode('analytics')
            $professional = $request.SelectSingleNode('professional')
            $timeline = @($request.SelectNodes('timeline/event'))
            $offerAt = if ($analytics) { $analytics.GetAttribute('offeredAt') } else { '' }
            if (-not $offerAt) { $offer = @($timeline | Where-Object { $_.GetAttribute('status') -eq 'offered' -or $_.GetAttribute('type') -eq 'professional_referred' } | Sort-Object { $_.GetAttribute('at') } | Select-Object -First 1); if ($offer.Count) { $offerAt = $offer[0].GetAttribute('at') } }
            if (-not $offerAt -and $request.GetAttribute('status') -in @('offered','connected','rejected') -and $request.GetAttribute('createdAt')) { $offerAt = $request.GetAttribute('createdAt') }
            if ($offerAt) { $points.Add([pscustomobject]@{ type='referred'; at=$offerAt; reason='' }) }

            $connectedAt = if ($analytics) { $analytics.GetAttribute('connectedAt') } else { '' }
            if (-not $connectedAt) { $connected = @($timeline | Where-Object { $_.GetAttribute('status') -in @('accepted','connected') -or $_.GetAttribute('type') -eq 'professional_connected' } | Sort-Object { $_.GetAttribute('at') } | Select-Object -First 1); if ($connected.Count) { $connectedAt = $connected[0].GetAttribute('at') } }
            if (-not $connectedAt -and $professional.GetAttribute('response') -eq 'accepted') { $connectedAt = $professional.GetAttribute('respondedAt') }
            if ($connectedAt) { $points.Add([pscustomobject]@{ type='connected'; at=$connectedAt; reason='' }) }

            $agreement = $request.SelectSingleNode('agreement'); $duration = $request.SelectSingleNode('agreement/duration'); $subtotal = $request.SelectSingleNode('agreement/laborSubtotal')
            $formalizedAt = if ($analytics) { $analytics.GetAttribute('formalizedAt') } else { '' }
            if (-not $formalizedAt -and $agreement -and $agreement.GetAttribute('status') -eq 'confirmed') { if ($duration) { $formalizedAt = $duration.GetAttribute('agreedAt') }; if (-not $formalizedAt -and $subtotal) { $formalizedAt = $subtotal.GetAttribute('confirmedAt') } }
            if ($formalizedAt) { $points.Add([pscustomobject]@{ type='formalized'; at=$formalizedAt; reason='' }) }

            $completion = $request.SelectSingleNode('completion'); $completionReport = $request.SelectSingleNode('workTiming/completionReport')
            $completedAt = if ($analytics) { $analytics.GetAttribute('completedAt') } else { '' }
            $clientCompletion = if ($completion) { $completion.SelectSingleNode('client') } else { $null }; $professionalCompletion = if ($completion) { $completion.SelectSingleNode('professional') } else { $null }
            if (-not $completedAt -and $completion -and $clientCompletion -and $professionalCompletion -and $completion.GetAttribute('status') -in @('completed','successfully_completed') -and $clientCompletion.GetAttribute('outcome') -eq 'completed' -and $professionalCompletion.GetAttribute('outcome') -eq 'completed') {
                if ($completionReport) { $completedAt = $completionReport.GetAttribute('mutuallyConfirmedAt') }
                if (-not $completedAt) { $completedAt = $clientCompletion.GetAttribute('confirmedAt') }
                if (-not $completedAt) { $completedAt = $professionalCompletion.GetAttribute('confirmedAt') }
            }
            if ($completedAt) { $points.Add([pscustomobject]@{ type='completed'; at=$completedAt; reason='' }) }

            $status = $request.GetAttribute('status')
            if ($status -in @('rejected','cancelled','expired','closed_unconfirmed','not_connected','abandoned','failed','not_materialized')) {
                $closedAt = if ($analytics) { $analytics.GetAttribute('closedAt') } else { '' }
                if (-not $closedAt) { $closedAt = $professional.GetAttribute('respondedAt') }
                if (-not $closedAt) { $closedAt = $request.GetAttribute('closedAt') }
                if (-not $closedAt) { $closedAt = $request.GetAttribute('updatedAt') }
                if (-not $closedAt) { $closedAt = $request.GetAttribute('createdAt') }
                $reason = if ($analytics) { $analytics.GetAttribute('closureReason') } else { '' }
                if (-not $reason) { $reasonEvent = @($timeline | Where-Object { $_.GetAttribute('reason') -or $_.GetAttribute('type') -match 'rejected|cancelled|expired|not_completed' } | Select-Object -Last 1); if ($reasonEvent.Count) { $reason = $reasonEvent[0].GetAttribute('reason'); if (-not $reason) { $reason = $reasonEvent[0].GetAttribute('type') } } }
                if (-not $reason -and $professional.GetAttribute('response') -eq 'rejected') { $reason = 'professional_rejected' }
                if (-not $reason) { $reason = $status }
                if ($reason -notin @('professional_rejected','client_cancelled','professional_cancelled','no_response','agreement_not_reached','work_not_completed','expired','rejected','cancelled','closed_unconfirmed','not_connected','abandoned','failed','not_materialized','other')) { $reason = 'other' }
                if ($closedAt -and -not $completedAt) { $points.Add([pscustomobject]@{ type='not_materialized'; at=$closedAt; reason=$reason }) }
            }
        }
    }
    $filtered = @($points | Where-Object {
        $at = [DateTimeOffset]::MinValue
        [DateTimeOffset]::TryParse([string]$_.at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$at) -and $at -ge $from -and $at -le $to -and ($_.type -ne 'not_materialized' -or -not $ReasonFilter -or $_.reason -eq $ReasonFilter)
    } | ForEach-Object { $at = [DateTimeOffset]::Parse([string]$_.at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal); [pscustomobject]@{ type=$_.type; at=$at.ToUniversalTime().ToString('o'); reason=$_.reason } })
    $windowPoints = @($points | Where-Object { $at=[DateTimeOffset]::MinValue; [DateTimeOffset]::TryParse([string]$_.at,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal,[ref]$at) -and $at -ge $from -and $at -le $to })
    $reasons = @($windowPoints | Where-Object { $_.type -eq 'not_materialized' } | ForEach-Object { $_.reason } | Group-Object | Sort-Object Name | ForEach-Object { [pscustomobject]@{ id=$_.Name; count=$_.Count } })
    return [pscustomobject]@{ points=@($filtered); reasons=@($reasons); from=$from.ToUniversalTime().ToString('o'); to=$to.ToUniversalTime().ToString('o') }
}

function Get-BotServiceStatus {
    $dotenv = Read-DotEnvFile -Path (Join-Path $script:ProjectRoot '.env')
    $getConfiguredValue = { param([string]$Name) $processValue=[Environment]::GetEnvironmentVariable($Name,'Process'); if(-not [string]::IsNullOrWhiteSpace($processValue)){return $processValue}; if($dotenv.ContainsKey($Name)){return [string]$dotenv[$Name]}; return '' }
    $required = @('WA_APP_SECRET','WA_PREFERENCES_HMAC_KEY','WA_VERIFY_TOKEN','WA_ACCESS_TOKEN','WA_PHONE_NUMBER_ID','WA_GRAPH_API_VERSION')
    $missing = @($required | Where-Object { [string]::IsNullOrWhiteSpace((& $getConfiguredValue $_)) })
    $hmacKey = & $getConfiguredValue 'WA_PREFERENCES_HMAC_KEY'; if ($hmacKey -and $hmacKey -notmatch '^[A-Fa-f0-9]{64}$') { $missing += 'WA_PREFERENCES_HMAC_KEY (formato inválido)' }
    $graphVersion = & $getConfiguredValue 'WA_GRAPH_API_VERSION'; if ($graphVersion -and $graphVersion -notmatch '^v\d+\.\d+$') { $missing += 'WA_GRAPH_API_VERSION (formato inválido)' }
    $port = 8080; $portValue = & $getConfiguredValue 'WA_PORT'; if($portValue){$parsed=0;if([int]::TryParse($portValue,[ref]$parsed) -and $parsed -ge 1024 -and $parsed -le 65535){$port=$parsed}}
    if ($portValue -and ($parsed -lt 1024 -or $parsed -gt 65535)) { $missing += 'WA_PORT (fuera de rango)' }
    $phoneNumber = & $getConfiguredValue 'WA_DISPLAY_PHONE_NUMBER'; $phoneNumberSource='not_configured'; if($phoneNumber){$phoneNumberSource='business_number'}else{$phoneNumber=& $getConfiguredValue 'WA_TEST_PHONE_NUMBER';if($phoneNumber){$phoneNumberSource='meta_test_number'}}
    if ([string]$phoneNumber -match '^REPLACE_WITH') { $phoneNumber = '' }
    $configured=($missing.Count -eq 0); $running=$false
    try { $health=Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$port/health" -TimeoutSec 2; $running=($health.service -eq 'whatsapp-bot' -and $health.status -eq 'running'); if($health.PSObject.Properties['configured']){$configured=([bool]$health.configured);if($configured){$missing=@()}}; if($health.phoneNumber -and [string]$health.phoneNumber -notmatch '^REPLACE_WITH'){$phoneNumber=[string]$health.phoneNumber};if($health.phoneNumberSource){$phoneNumberSource=[string]$health.phoneNumberSource} } catch {}
    return [pscustomobject]@{ enabled=$configured; configured=$configured; running=$running; status=$(if($running){'running'}elseif($configured){'stopped'}else{'not_configured'}); port=$port; phoneNumber=[string]$phoneNumber; phoneNumberSource=$phoneNumberSource; missingConfiguration=$missing; checkedAt=[DateTime]::UtcNow.ToString('o') }
}

function Get-ReviewSnapshot {
    $store = Read-ReviewStore
    $profilesDoc = Get-XmlDocumentOrNull 'runtime/data/professionals.xml'
    $requestsDoc = Get-XmlDocumentOrNull 'runtime/data/requests.xml'
    $cases = @()
    foreach ($case in @($store.cases)) { $cases += $case }
    if ($null -ne $requestsDoc) {
        foreach ($request in @(Get-XmlRecords $requestsDoc 'request')) {
            $requestId = $request.GetAttribute('id')
            $code = $request.GetAttribute('requestCode')
            $commission = $request.SelectSingleNode('commission')
            if ($null -ne $commission -and $commission.GetAttribute('status') -eq 'pending_admin_review') {
                $id = "commission:$requestId"
                if (-not (@($cases | Where-Object { $_.id -ceq $id -and $_.status -eq 'pending' }).Count)) {
                    $cases += [pscustomobject]@{ id=$id; type='commission_payment'; title='Confirmación de transferencia'; status='pending'; requestId=$requestId; requestCode=$code; professionalId=$request.professional.GetAttribute('id'); summary='Comprobante pendiente de revisión visual'; createdAt=$commission.GetAttribute('proofSubmittedAt'); amount=$commission.GetAttribute('amountDue'); evidencePath=$commission.GetAttribute('evidencePath'); source='requests.xml' }
                }
            }
            $nonCompletion = $request.SelectSingleNode('nonCompletionCase')
            if ($null -ne $nonCompletion -and $nonCompletion.GetAttribute('status') -in @('pending_review','pending_admin_review','reported')) {
                $id = "reliability:$requestId"
                if (-not (@($cases | Where-Object { $_.id -ceq $id -and $_.status -eq 'pending' }).Count)) {
                    $cases += [pscustomobject]@{ id=$id; type='non_completion'; title='Incumplimiento / trabajo no completado'; status='pending'; requestId=$requestId; requestCode=$code; professionalId=$request.professional.GetAttribute('id'); summary=$nonCompletion.GetAttribute('reason'); createdAt=$nonCompletion.GetAttribute('reportedAt'); source='requests.xml' }
                }
            }
            if($request.GetAttribute('status') -eq 'disputed'){
                $adminReview=$request.SelectSingleNode('administrativeReview')
                if($null -eq $adminReview -or $adminReview.GetAttribute('status') -ne 'reviewed'){
                    $id="dispute:$requestId"
                    if(-not(@($cases|Where-Object{$_.id -ceq $id -and $_.status -eq 'pending'}).Count)){$cases += [pscustomobject]@{id=$id;type='work_dispute';title='Desacuerdo sobre el resultado del trabajo';status='pending';requestId=$requestId;requestCode=$code;professionalId=$request.professional.GetAttribute('id');summary='Revisar el historial de respuestas. La revisión administrativa no reemplaza la confirmación bilateral ni habilita una comisión.';createdAt=$request.GetAttribute('updatedAt');source='requests.xml'}}
                }
            }
        }
    }
    if ($null -ne $profilesDoc) {
        foreach ($profile in @(Get-XmlRecords $profilesDoc 'professional')) {
            $deletion = $profile.SelectSingleNode('dataDeletionRequest')
            $profileId = $profile.GetAttribute('id')
            if ($null -ne $deletion -and $deletion.GetAttribute('status') -eq 'pending_admin_review') {
                $id = "deletion:$profileId"
                if (-not (@($cases | Where-Object { $_.id -ceq $id -and $_.status -eq 'pending' }).Count)) {
                    $cases += [pscustomobject]@{ id=$id; type='professional_deletion'; title='Solicitud de borrado de datos'; status='pending'; professionalId=$profileId; summary='Revisar solicitudes, disputas y comisiones abiertas antes de decidir'; createdAt=$deletion.GetAttribute('requestedAt'); source='professionals.xml' }
                }
            }
        }
    }
    $open = @($cases | Where-Object { $_.status -eq 'pending' } | Sort-Object createdAt)
    $profiles = @()
    if ($null -ne $profilesDoc) {
        foreach ($profile in @(Get-XmlRecords $profilesDoc 'professional')) {
            if($profile.GetAttribute('status') -eq 'anonymized'){continue}
            $history=$profile.SelectSingleNode('reliabilityHistory');$suspensions='0';if($history){$suspensions=$history.GetAttribute('totalSuspensions')}
            $profiles += [pscustomobject]@{ id=$profile.GetAttribute('id'); name=("$($profile.firstName) $($profile.lastName)").Trim(); status=$profile.GetAttribute('status'); availability=$profile.GetAttribute('availabilityStatus'); suspensions=$suspensions }
        }
    }
    return [pscustomobject]@{ cases=@($open); resolved=@(@($store.cases) | Where-Object { $_.status -eq 'resolved' } | Sort-Object reviewedAt -Descending | Select-Object -First 100); profiles=@($profiles); admins=@(Get-AdminEntries); auditCount=@($store.audit).Count }
}

function Get-XmlRecords([xml]$Document, [string]$NodeName) {
    return @($Document.SelectNodes('/' + $Document.DocumentElement.Name + '/' + $NodeName + ' | /' + $Document.DocumentElement.Name + '/records/' + $NodeName))
}

function Find-XmlRecord([xml]$Document, [string]$NodeName, [string]$Id) {
    $found=@()
    foreach($node in @(Get-XmlRecords $Document $NodeName)){ if($node.GetAttribute('id') -ceq $Id){$found += $node} }
    if($found.Count -eq 1){return $found[0]}; return $null
}

function Remove-ProfileFromBackups([string]$ProfileId) {
    $backupRoot=Join-Path $script:ProjectRoot 'runtime/backups'
    if(-not(Test-Path -LiteralPath $backupRoot)){return}
    foreach($file in @(Get-ChildItem -LiteralPath $backupRoot -Filter '*.xml' -File -Recurse -ErrorAction SilentlyContinue | Where-Object {$_.Name -like 'professionals*.xml' -or $_.Directory.Name -eq 'professionals'})){
        try {
            $doc=[xml][IO.File]::ReadAllText($file.FullName,[Text.Encoding]::UTF8)
            $records=@(Get-XmlRecords $doc 'professional' | Where-Object {$_.GetAttribute('id') -ceq $ProfileId})
            if($records.Count){foreach($record in $records){[void]$record.ParentNode.RemoveChild($record)};$tmp="$($file.FullName).$([guid]::NewGuid().ToString('N')).tmp";$doc.Save($tmp);[IO.File]::Replace($tmp,$file.FullName,$null)}
        } catch { throw 'No se pudieron anonimizar todas las copias de seguridad del perfil; revisa el estado manualmente.' }
    }
}

function Invoke-BuiltinDecision($Context, $Body, $Kind, $EntityId) {
    $store=Read-ReviewStore
    $now=[DateTime]::UtcNow.ToString('o')
    if($Kind -eq 'commission'){
        $role='commission_admin'; if(-not(Test-AdminRole $Body.reviewerId $role)){Write-Json $Context 403 @{error='Se requiere commission_admin.'};return}
        if($Body.decision -notin @('accepted','rejected','inconclusive')){Write-Json $Context 400 @{error='Decisión no válida para una transferencia.'};return}
        $doc=Get-XmlDocumentOrNull 'runtime/data/requests.xml';$request=if($doc){Find-XmlRecord $doc 'request' $EntityId}else{$null};$commission=if($request){$request.SelectSingleNode('commission')}else{$null}
        if($null -eq $commission -or $commission.GetAttribute('status') -ne 'pending_admin_review'){Write-Json $Context 409 @{error='La transferencia ya no está pendiente o no existe.'};return}
        if([string]::IsNullOrWhiteSpace([string]$Body.reason)){Write-Json $Context 400 @{error='Es obligatorio registrar el motivo.'};return}
        $commission.SetAttribute('status',$(if($Body.decision -eq 'accepted'){'paid'}elseif($Body.decision -eq 'rejected'){'proof_rejected'}else{'inconclusive'}));$commission.SetAttribute('paidByAdminReview',[string]($Body.decision -eq 'accepted'));$commission.SetAttribute('bankDepositVerified','false');$commission.SetAttribute('reviewedAt',$now);$commission.SetAttribute('reviewerAllowlistId',[string]$Body.reviewerId);$commission.SetAttribute('decision',[string]$Body.decision);$commission.SetAttribute('decisionReason',[string]$Body.reason)
        Save-XmlDocument $doc 'runtime/data/requests.xml'
        $case=[pscustomobject]@{id="commission:$EntityId";type='commission_payment';title='Confirmación de transferencia';status='resolved';requestId=$EntityId;professionalId=$request.professional.GetAttribute('id');summary='Revisión visual del comprobante';decision=[string]$Body.decision;decisionReason=[string]$Body.reason;reviewerId=[string]$Body.reviewerId;reviewedAt=$now;createdAt=$commission.GetAttribute('proofSubmittedAt')}
    } elseif($Kind -eq 'reliability'){
        $role='professional_reliability_admin';if(-not(Test-AdminRole $Body.reviewerId $role)){Write-Json $Context 403 @{error='Se requiere professional_reliability_admin.'};return}
        if($Body.decision -notin @('attributable_to_professional','not_attributable_to_professional','inconclusive')){Write-Json $Context 400 @{error='Decisión no válida para una revisión de confiabilidad.'};return}
        if([string]::IsNullOrWhiteSpace([string]$Body.reason)){Write-Json $Context 400 @{error='Es obligatorio registrar el motivo.'};return}
        $doc=Get-XmlDocumentOrNull 'runtime/data/requests.xml';$request=if($doc){Find-XmlRecord $doc 'request' $EntityId}else{$null};$review=if($request){$request.SelectSingleNode('nonCompletionCase')}else{$null}
        if($null -eq $review -or $review.GetAttribute('status') -notin @('pending_review','pending_admin_review','reported')){Write-Json $Context 409 @{error='El caso ya no está pendiente o no existe.'};return}
        $review.SetAttribute('status','reviewed');$review.SetAttribute('reviewedAt',$now);$review.SetAttribute('reviewerAllowlistId',[string]$Body.reviewerId);$review.SetAttribute('outcome',[string]$Body.decision);$review.SetAttribute('attributedParty',$(if($Body.decision -eq 'attributable_to_professional'){'professional'}else{'none'}));$review.SetAttribute('reason',[string]$Body.reason)
        Save-XmlDocument $doc 'runtime/data/requests.xml'
        $case=[pscustomobject]@{id="reliability:$EntityId";type='non_completion';title='Incumplimiento / trabajo no completado';status='resolved';requestId=$EntityId;professionalId=$request.professional.GetAttribute('id');summary=$review.GetAttribute('reason');decision=[string]$Body.decision;decisionReason=[string]$Body.reason;reviewerId=[string]$Body.reviewerId;reviewedAt=$now;createdAt=$review.GetAttribute('reportedAt')}
    } elseif($Kind -eq 'deletion'){
        $role='commission_admin';if(-not(Test-AdminRole $Body.reviewerId $role)){Write-Json $Context 403 @{error='Se requiere commission_admin.'};return}
        if($Body.decision -notin @('approved_anonymized','rejected')){Write-Json $Context 400 @{error='Decisión no válida para un pedido de borrado.'};return}
        if([string]::IsNullOrWhiteSpace([string]$Body.reason)){Write-Json $Context 400 @{error='Es obligatorio registrar el motivo.'};return}
        $profiles=Get-XmlDocumentOrNull 'runtime/data/professionals.xml';$profile=if($profiles){Find-XmlRecord $profiles 'professional' $EntityId}else{$null};$deletion=if($profile){$profile.SelectSingleNode('dataDeletionRequest')}else{$null}
        if($null -eq $deletion -or $deletion.GetAttribute('status') -ne 'pending_admin_review'){Write-Json $Context 409 @{error='La solicitud ya no está pendiente o no existe.'};return}
        if($Body.decision -eq 'rejected'){
            $profile.SetAttribute('status',[string]$deletion.GetAttribute('previousProfileStatus'));$profile.SetAttribute('availabilityStatus',[string]$deletion.GetAttribute('previousAvailabilityStatus'));$deletion.SetAttribute('status','rejected')
        }else{
            $requests=Get-XmlDocumentOrNull 'runtime/data/requests.xml'
            if($requests){foreach($request in @(Get-XmlRecords $requests 'request'|Where-Object{$_.professional.GetAttribute('id') -ceq $EntityId})){$closed=$request.GetAttribute('status') -in @('completed','cancelled','rejected','closed_unconfirmed');$commission=$request.SelectSingleNode('commission');$commissionOpen=$commission -and $commission.GetAttribute('status') -in @('due','proof_submitted','pending_admin_review','pending_completion');if(-not $closed -or $commissionOpen){Write-Json $Context 409 @{error='Hay solicitudes o comisiones abiertas; resuélvelas antes de aprobar el borrado.'};return}}}
            $profileId=$profile.GetAttribute('id')
            $profile.firstName.InnerText='';$profile.lastName.InnerText='';$profile.whatsappPhone.SetAttribute('e164','');$profile.whatsappPhone.SetAttribute('verifiedAt','')
            foreach($name in @('socialLinks','serviceCategories','serviceAreas','availability','crew','profileChangeHistory','gallery','galleryReferences')){$node=$profile.SelectSingleNode($name);if($node){if($name -in @('serviceCategories','serviceAreas','availability','profileChangeHistory','gallery','galleryReferences')){$node.RemoveAll()}elseif($name -eq 'crew'){$node.SetAttribute('hasAdditionalWorkers','false');$node.SetAttribute('additionalWorkers','0')}elseif($name -eq 'socialLinks'){$node.RemoveAll()}}}
            $profile.SetAttribute('status','anonymized');$profile.SetAttribute('availabilityStatus','inactive');$deletion.SetAttribute('status','approved_anonymized');$deletion.SetAttribute('requestedByProfessionalId','');$deletion.SetAttribute('anonymizedAt',$now)
            $deletion.SetAttribute('status','approved_anonymized')
        }
        $deletion.SetAttribute('reviewedAt',$now);$deletion.SetAttribute('reviewerAllowlistId',[string]$Body.reviewerId);$deletion.SetAttribute('decision',[string]$Body.decision);$deletion.SetAttribute('decisionReason',[string]$Body.reason)
        try{Save-XmlDocument $profiles 'runtime/data/professionals.xml';if($Body.decision -eq 'approved_anonymized'){Remove-ProfileFromBackups $profileId}}catch{Write-Json $Context 500 @{error=$_.Exception.Message};return}
        $case=[pscustomobject]@{id="deletion:$EntityId";type='professional_deletion';title='Solicitud de borrado de datos';status='resolved';professionalId=$(if($Body.decision -eq 'approved_anonymized'){'Perfil anonimizado'}else{$EntityId});summary='Solicitud revisada por Administración';decision=[string]$Body.decision;decisionReason=[string]$Body.reason;reviewerId=[string]$Body.reviewerId;reviewedAt=$now;createdAt=$deletion.GetAttribute('requestedAt')}
    } elseif($Kind -eq 'dispute'){
        $role='professional_reliability_admin';if(-not(Test-AdminRole $Body.reviewerId $role)){Write-Json $Context 403 @{error='Se requiere professional_reliability_admin.'};return}
        if($Body.decision -ne 'reviewed_no_change' -or [string]::IsNullOrWhiteSpace([string]$Body.reason)){Write-Json $Context 400 @{error='Esta revisión solo permite registrar la revisión sin cambiar el resultado bilateral.'};return}
        $doc=Get-XmlDocumentOrNull 'runtime/data/requests.xml';$request=if($doc){Find-XmlRecord $doc 'request' $EntityId}else{$null};if($null -eq $request -or $request.GetAttribute('status') -ne 'disputed'){Write-Json $Context 409 @{error='La solicitud ya no está disputada o no existe.'};return}
        $review=$request.SelectSingleNode('administrativeReview');if($null -eq $review){$review=$doc.CreateElement('administrativeReview');[void]$request.AppendChild($review)};$review.SetAttribute('status','reviewed');$review.SetAttribute('outcome','reviewed_no_change');$review.SetAttribute('reviewedAt',$now);$review.SetAttribute('reviewerAllowlistId',[string]$Body.reviewerId);$review.SetAttribute('reason',[string]$Body.reason);Save-XmlDocument $doc 'runtime/data/requests.xml'
        $case=[pscustomobject]@{id="dispute:$EntityId";type='work_dispute';title='Desacuerdo sobre el resultado del trabajo';status='resolved';requestId=$EntityId;professionalId=$request.professional.GetAttribute('id');summary='La disputa continúa hasta recibir confirmación bilateral';decision='reviewed_no_change';decisionReason=[string]$Body.reason;reviewerId=[string]$Body.reviewerId;reviewedAt=$now;createdAt=$request.GetAttribute('updatedAt')}
    }else{Write-Json $Context 400 @{error='Tipo de revisión incorporada no válido.'};return}
    $store.cases=@($store.cases)+@($case);Add-AuditEvent $store 'builtin_review_decided' $case.id $Body.reviewerId $role $Body.reason $Body.decision;Save-ReviewStore $store
    Write-Json $Context 200 @{case=$case}
}

function Write-HttpResponse($Context, [int]$Status, [string]$ContentType, [byte[]]$Bytes) {
    $Context.Response.StatusCode = $Status
    $Context.Response.ContentType = $ContentType
    $Context.Response.Headers['X-Content-Type-Options'] = 'nosniff'
    $Context.Response.Headers['Cache-Control'] = 'no-store'
    $Context.Response.ContentLength64 = $Bytes.Length
    if ($Bytes.Length -gt 0) { $Context.Response.OutputStream.Write($Bytes, 0, $Bytes.Length) }
    $Context.Response.Close()
}

function Write-Json($Context, [int]$Status, $Value) {
    $json = ConvertTo-Json -InputObject $Value -Depth 12
    Write-HttpResponse $Context $Status 'application/json; charset=utf-8' $script:Utf8NoBom.GetBytes($json)
}

function Read-RequestJson($Context) {
    if ($Context.Request.ContentLength64 -gt 7500000) { throw 'El cuerpo supera el límite permitido.' }
    $reader = New-Object IO.StreamReader($Context.Request.InputStream, $Context.Request.ContentEncoding)
    try { return ($reader.ReadToEnd() | ConvertFrom-Json) } finally { $reader.Dispose() }
}

function Add-AuditEvent($Store, $Action, $ItemId, $ReviewerId, $Role, $Reason, $Outcome) {
    $Store.audit = @($Store.audit) + @([pscustomobject]@{ at=[DateTime]::UtcNow.ToString('o'); action=$Action; itemId=$ItemId; reviewerId=$ReviewerId; role=$Role; outcome=$Outcome; reason=$Reason })
}

function Invoke-Api($Context) {
    $path = $Context.Request.Url.AbsolutePath
    if ($path -eq '/api/health' -and $Context.Request.HttpMethod -eq 'GET') { Write-Json $Context 200 @{ ok=$true }; return }
    $provided = $Context.Request.Headers['X-Admin-Token']
    if (-not $provided -or -not [string]::Equals($provided, $script:Token, [StringComparison]::Ordinal)) { Write-Json $Context 401 @{ error='Sesión local no autorizada. Recarga el panel.' }; return }
    if ($Context.Request.HttpMethod -eq 'GET' -and $path -eq '/api/reviews') { Write-Json $Context 200 (Get-ReviewSnapshot); return }
    if ($Context.Request.HttpMethod -eq 'GET' -and $path -eq '/api/analytics') {
        $from = Get-QueryParameter $Context.Request.Url 'from'; $to = Get-QueryParameter $Context.Request.Url 'to'; $reason = Get-QueryParameter $Context.Request.Url 'reason'
        if (-not $from) { $from = [DateTimeOffset]::UtcNow.AddDays(-29).ToString('yyyy-MM-ddT00:00:00Z') }; if (-not $to) { $to = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddT23:59:59.999Z') }
        try { Write-Json $Context 200 (Get-AnalyticsSnapshot $from $to $reason) } catch { Write-Json $Context 400 @{error=$_.Exception.Message} }; return
    }
    if ($Context.Request.HttpMethod -eq 'GET' -and $path -eq '/api/service-status') { Write-Json $Context 200 (Get-BotServiceStatus); return }
    if ($Context.Request.HttpMethod -eq 'GET' -and $path -eq '/api/evidence') {
        $relative=Get-QueryParameter $Context.Request.Url 'path'
        $evidenceRoot=[IO.Path]::GetFullPath((Join-Path $script:ProjectRoot 'storage/evidence/commission-payments') + [IO.Path]::DirectorySeparatorChar)
        $file=[IO.Path]::GetFullPath((Join-Path $script:ProjectRoot $relative))
        if(-not $file.StartsWith($evidenceRoot,[StringComparison]::OrdinalIgnoreCase) -or -not(Test-Path -LiteralPath $file -PathType Leaf)){Write-Json $Context 404 @{error='Evidencia no encontrada.'};return}
        $info=Get-Item -LiteralPath $file;if($info.Length -gt 6000000){Write-Json $Context 413 @{error='El archivo supera el límite de visualización.'};return}
        $ext=[IO.Path]::GetExtension($file).ToLowerInvariant();$mime=switch($ext){'.png'{'image/png'}'.jpg'{'image/jpeg'}'.jpeg'{'image/jpeg'}'.webp'{'image/webp'}'.pdf'{'application/pdf'}default{'application/octet-stream'}}
        $dataUrl="data:$mime;base64,$([Convert]::ToBase64String([IO.File]::ReadAllBytes($file)))";Write-Json $Context 200 @{type=$mime;url=$dataUrl};return
    }
    if ($Context.Request.HttpMethod -eq 'POST' -and $path -eq '/api/cases') {
        $body = Read-RequestJson $Context
        $type = [string]$body.type
        $requiredRole = Get-RequiredRole $type
        if ($type -notin @('commission_payment','non_completion','repeated_cancellations','fraud_report','onboarding_linkage','prohibited_service','phone_change','professional_deletion')) { Write-Json $Context 400 @{error='Tipo de revisión no válido.'}; return }
        if (-not (Test-AdminRole $body.reviewerId $requiredRole)) { Write-Json $Context 403 @{error="El revisor no tiene el rol requerido: $requiredRole"}; return }
        if($type -eq 'non_completion'){
            if(-not [string]$body.requestId -or -not [string]$body.summary){Write-Json $Context 400 @{error='Indica la solicitud y los hechos del caso.'};return}
            $doc=Get-XmlDocumentOrNull 'runtime/data/requests.xml';$request=if($doc){Find-XmlRecord $doc 'request' ([string]$body.requestId)}else{$null};if($null -eq $request){Write-Json $Context 404 @{error='Solicitud no encontrada de forma única.'};return}
            $subtotal=$request.agreement.laborSubtotal;$duration=$request.agreement.duration
            if($request.agreement.GetAttribute('status') -ne 'confirmed' -or $subtotal.GetAttribute('confirmedByClient') -ne 'true' -or $subtotal.GetAttribute('confirmedByProfessional') -ne 'true' -or -not $duration.GetAttribute('confirmedByClientAt') -or -not $duration.GetAttribute('confirmedByProfessionalAt')){Write-Json $Context 409 @{error='Solo se puede abrir este caso cuando ambas partes confirmaron alcance, subtotal y duración.'};return}
            $nonCompletion=$request.SelectSingleNode('nonCompletionCase');if($null -eq $nonCompletion){$nonCompletion=$doc.CreateElement('nonCompletionCase');[void]$request.AppendChild($nonCompletion)}
            if($nonCompletion.GetAttribute('status') -in @('pending_review','pending_admin_review','reported','reviewed')){Write-Json $Context 409 @{error='La solicitud ya tiene un caso de confiabilidad abierto o revisado.'};return}
            $now=[DateTime]::UtcNow.ToString('o');$nonCompletion.SetAttribute('status','pending_admin_review');$nonCompletion.SetAttribute('agreedAt',$duration.GetAttribute('agreedAt'));$nonCompletion.SetAttribute('reportedAt',$now);$nonCompletion.SetAttribute('reason',[string]$body.summary);Save-XmlDocument $doc 'runtime/data/requests.xml'
            $store=Read-ReviewStore;Add-AuditEvent $store 'reliability_case_opened' $body.requestId $body.reviewerId $requiredRole $body.summary 'pending';Save-ReviewStore $store
            Write-Json $Context 201 @{case=[pscustomobject]@{id="reliability:$($body.requestId)";type='non_completion';title='Incumplimiento / trabajo no completado';status='pending';requestId=[string]$body.requestId;requestCode=$request.GetAttribute('requestCode');professionalId=$request.professional.GetAttribute('id');summary=[string]$body.summary;createdAt=$now}};return
        }
        if($type -eq 'commission_payment'){
            if(-not [string]$body.requestId -or -not [string]$body.evidencePath){Write-Json $Context 400 @{error='Indica el ID de solicitud y la ruta del comprobante.'};return}
            $root=[IO.Path]::GetFullPath((Join-Path $script:ProjectRoot 'storage/evidence/commission-payments')+[IO.Path]::DirectorySeparatorChar);$file=[IO.Path]::GetFullPath((Join-Path $script:ProjectRoot ([string]$body.evidencePath)));
            if(-not $file.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $file -PathType Leaf)){Write-Json $Context 400 @{error='El comprobante debe existir dentro de storage/evidence/commission-payments/.'};return}
            $doc=Get-XmlDocumentOrNull 'runtime/data/requests.xml';$request=if($doc){Find-XmlRecord $doc 'request' ([string]$body.requestId)}else{$null};if($null -eq $request){Write-Json $Context 404 @{error='Solicitud no encontrada de forma única.'};return}
            if ($request.completion.client.GetAttribute('outcome') -ne 'completed' -or $request.completion.professional.GetAttribute('outcome') -ne 'completed') { Write-Json $Context 409 @{error='La comisión requiere finalización confirmada por Cliente y Profesional.'}; return }
            $subtotal=$request.agreement.laborSubtotal; $subtotalAmount=0m
            $subtotalValid=[decimal]::TryParse($subtotal.GetAttribute('amount'),[Globalization.NumberStyles]::Number,[Globalization.CultureInfo]::InvariantCulture,[ref]$subtotalAmount)
            if ($subtotal.GetAttribute('confirmedByClient') -ne 'true' -or $subtotal.GetAttribute('confirmedByProfessional') -ne 'true' -or -not $subtotalValid -or $subtotalAmount -le 0) { Write-Json $Context 409 @{error='El subtotal de mano de obra debe estar confirmado bilateralmente.'}; return }
            $expected=[decimal][Math]::Floor([double]($subtotalAmount*0.05)); $given=0m
            $givenValid=[decimal]::TryParse(([string]$body.amount).Replace(',','.'),[Globalization.NumberStyles]::Number,[Globalization.CultureInfo]::InvariantCulture,[ref]$given)
            if (-not $givenValid -or $given -ne $expected) { Write-Json $Context 409 @{error="El importe debe coincidir con la comisión configurada: ARS $([int]$expected)."}; return }
            $commission=$request.SelectSingleNode('commission');if($null -eq $commission){$commission=$doc.CreateElement('commission');$request.AppendChild($commission)|Out-Null};if($commission.GetAttribute('status') -eq 'paid'){Write-Json $Context 409 @{error='La comisión ya figura pagada.'};return}
            $commission.SetAttribute('status','pending_admin_review');$commission.SetAttribute('amountDue',[string][int]$expected);$commission.SetAttribute('currency','ARS');$commission.SetAttribute('proofSubmittedAt',[DateTime]::UtcNow.ToString('o'));$commission.SetAttribute('evidencePath',[string]$body.evidencePath);$commission.SetAttribute('paidByAdminReview','false');$commission.SetAttribute('bankDepositVerified','false');Save-XmlDocument $doc 'runtime/data/requests.xml'
            $store=Read-ReviewStore;Add-AuditEvent $store 'commission_proof_submitted' $body.requestId $body.reviewerId $requiredRole 'Comprobante incorporado a revisión manual' 'pending';Save-ReviewStore $store
            Write-Json $Context 201 @{case=[pscustomobject]@{id="commission:$($body.requestId)";type=$type;title='Confirmación de transferencia';status='pending';requestId=[string]$body.requestId;professionalId=$request.professional.GetAttribute('id');summary='Comprobante pendiente de revisión visual';amount=[string][int]$expected;evidencePath=[string]$body.evidencePath;createdAt=$commission.GetAttribute('proofSubmittedAt')}};return
        }
        $store = Read-ReviewStore
        $case = [pscustomobject]@{ id=[guid]::NewGuid().ToString('N'); type=$type; title=[string]$body.title; status='pending'; requestId=[string]$body.requestId; professionalId=[string]$body.professionalId; summary=[string]$body.summary; amount=[string]$body.amount; evidencePath=[string]$body.evidencePath; createdAt=[DateTime]::UtcNow.ToString('o'); updatedAt=[DateTime]::UtcNow.ToString('o'); decision=''; decisionReason=''; reviewerId=''; reviewerRole=''; reviewedAt='' }
        $store.cases = @($store.cases) + @($case)
        Add-AuditEvent $store 'case_created' $case.id $body.reviewerId $requiredRole $case.summary 'pending'
        Save-ReviewStore $store
        Write-Json $Context 201 @{case=$case}; return
    }
    if ($Context.Request.HttpMethod -eq 'POST' -and $path -eq '/api/decision') {
        $body = Read-RequestJson $Context
        $store = Read-ReviewStore
        $custom = @($store.cases | Where-Object { $_.id -ceq [string]$body.caseId -and $_.status -eq 'pending' })
        if($custom.Count -eq 0 -and [string]$body.caseId -match '^(commission|reliability|deletion|dispute):(.+)$') { Invoke-BuiltinDecision $Context $body $Matches[1] $Matches[2];return }
        if ($custom.Count -ne 1) { Write-Json $Context 404 @{error='No se encontró una revisión pendiente con ese ID.'}; return }
        $case = $custom[0]
        $role = Get-RequiredRole $case.type
        if (-not (Test-AdminRole $body.reviewerId $role)) { Write-Json $Context 403 @{error="El revisor no tiene el rol requerido: $role"}; return }
        if ([string]::IsNullOrWhiteSpace([string]$body.reason)) { Write-Json $Context 400 @{error='Es obligatorio registrar el motivo de la decisión.'}; return }
        $allowed=@{fraud_report=@('substantiated','not_substantiated','inconclusive');onboarding_linkage=@('substantiated','not_substantiated','inconclusive');repeated_cancellations=@('substantiated','not_substantiated','inconclusive');prohibited_service=@('substantiated','not_substantiated','inconclusive');phone_change=@('approved','rejected','inconclusive');non_completion=@('attributable_to_professional','not_attributable_to_professional','inconclusive');work_dispute=@('reviewed_no_change')}
        if($allowed.ContainsKey($case.type) -and $body.decision -notin $allowed[$case.type]){Write-Json $Context 400 @{error='La decisión no es válida para este tipo de caso.'};return}
        $case.status = 'resolved'; $case.decision=[string]$body.decision; $case.decisionReason=[string]$body.reason; $case.reviewerId=[string]$body.reviewerId; $case.reviewerRole=$role; $case.reviewedAt=[DateTime]::UtcNow.ToString('o'); $case.updatedAt=$case.reviewedAt
        Add-AuditEvent $store 'case_decided' $case.id $case.reviewerId $role $case.decisionReason $case.decision
        Save-ReviewStore $store
        Write-Json $Context 200 @{case=$case}; return
    }
    if ($Context.Request.HttpMethod -eq 'POST' -and $path -eq '/api/suspension') {
        $body = Read-RequestJson $Context
        if (-not (Test-AdminRole $body.reviewerId 'professional_reliability_admin')) { Write-Json $Context 403 @{error='Se requiere professional_reliability_admin.'}; return }
        if ([string]::IsNullOrWhiteSpace([string]$body.reason)) { Write-Json $Context 400 @{error='Es obligatorio registrar el motivo.'}; return }
        $doc = Get-XmlDocumentOrNull 'runtime/data/professionals.xml'
        if ($null -eq $doc) { Write-Json $Context 503 @{error='No existe runtime/data/professionals.xml.'}; return }
        $profile=Find-XmlRecord $doc 'professional' ([string]$body.professionalId)
        if ($null -eq $profile) { Write-Json $Context 404 @{error='Perfil no encontrado de forma única.'}; return }
        $history=$profile.SelectSingleNode('reliabilityHistory')
        if ($null -eq $history) { $history=$doc.CreateElement('reliabilityHistory'); $history.SetAttribute('totalSuspensions','0'); [void]$profile.AppendChild($history) }
        $suspensions=$history.SelectSingleNode('suspensions')
        if ($null -eq $suspensions) { $suspensions=$doc.CreateElement('suspensions'); [void]$history.AppendChild($suspensions) }
        $now=[DateTime]::UtcNow
        if ($body.action -eq 'suspend') {
            if($profile.GetAttribute('status') -ne 'active'){Write-Json $Context 409 @{error='Solo se puede suspender desde el estado active.'};return}
            if ($profile.GetAttribute('status') -in @('suspended','deactivated','permanently_deactivated')) { Write-Json $Context 409 @{error='El perfil ya está restringido.'}; return }
            $requests=Get-XmlDocumentOrNull 'runtime/data/requests.xml';$eligible=@()
            if($requests){foreach($request in @(Get-XmlRecords $requests 'request')){if($request.professional.GetAttribute('id') -ne [string]$body.professionalId){continue};$nc=$request.SelectSingleNode('nonCompletionCase');if($null -eq $nc -or $nc.GetAttribute('outcome') -ne 'attributable_to_professional' -or $nc.GetAttribute('attributedParty') -ne 'professional' -or $nc.GetAttribute('suspensionId')){continue};$reviewed=[DateTime]::MinValue;if([DateTime]::TryParse($nc.GetAttribute('reviewedAt'),[ref]$reviewed) -and $reviewed.ToUniversalTime() -ge $now.AddDays(-60)){$eligible+=@{Request=$request;Case=$nc}}}}
            if($eligible.Count -lt 3 -or -not(@($eligible | Where-Object {$_.Request.GetAttribute('id') -ceq [string]$body.requestId}).Count)){Write-Json $Context 409 @{error='La política requiere tres casos distintos atribuibles al profesional, revisados dentro de 60 días y aún no asociados a una suspensión.'};return}
            $days=if ([int]$body.days -ge 1 -and [int]$body.days -le 365) { [int]$body.days } else { 60 }
            $count=0; [void][int]::TryParse($history.GetAttribute('totalSuspensions'),[ref]$count);$eventId=[guid]::NewGuid().ToString('N');$newCount=$count+1;$lifeStatus=if($newCount -ge 3){'deactivated'}else{'suspended'}
            $event=$doc.CreateElement('event'); $event.SetAttribute('id',$eventId); $event.SetAttribute('type',$(if($lifeStatus -eq 'deactivated'){'third_suspension_deactivation'}else{'suspension'})); $event.SetAttribute('status','active'); $event.SetAttribute('startedAt',$now.ToString('o')); $event.SetAttribute('expiresAt',$now.AddDays($days).ToString('o')); $event.SetAttribute('causeRequestIds',(($eligible | ForEach-Object {$_.Request.GetAttribute('id')}) -join ',')); $event.SetAttribute('reviewedAt',$now.ToString('o')); $event.SetAttribute('reviewerAllowlistId',[string]$body.reviewerId); $event.SetAttribute('decision',$lifeStatus); [void]$suspensions.AppendChild($event)
            $history.SetAttribute('totalSuspensions',[string]$newCount); $history.SetAttribute('updatedAt',$now.ToString('o')); $profile.SetAttribute('status',$lifeStatus)
            foreach($item in $eligible){$item.Case.SetAttribute('suspensionId',$eventId)}
        } elseif ($body.action -eq 'reactivate') {
            if ($profile.GetAttribute('status') -notin @('suspended','deactivated')) { Write-Json $Context 409 @{error='El perfil no tiene una suspensión temporal que pueda levantarse.'}; return }
            $active=@($suspensions.SelectNodes('event[@status="active"]') | Sort-Object { $_.GetAttribute('startedAt') } -Descending | Select-Object -First 1)
            if ($active.Count -eq 1) { $active[0].SetAttribute('status','reactivated'); $active[0].SetAttribute('reactivatedAt',$now.ToString('o')); $active[0].SetAttribute('reactivationSource','admin_panel'); $active[0].SetAttribute('decisionReason',[string]$body.reason) }
            $profile.SetAttribute('status','active'); $history.SetAttribute('updatedAt',$now.ToString('o'))
        } else { Write-Json $Context 400 @{error='Acción no válida.'}; return }
        Save-XmlDocument $doc 'runtime/data/professionals.xml'
        if($body.action -eq 'suspend'){Save-XmlDocument $requests 'runtime/data/requests.xml'}
        $store=Read-ReviewStore; Add-AuditEvent $store 'professional_status_changed' $body.professionalId $body.reviewerId 'professional_reliability_admin' $body.reason $body.action; Save-ReviewStore $store
        Write-Json $Context 200 @{ok=$true;profileId=$body.professionalId;status=$profile.GetAttribute('status')}; return
    }
    Write-Json $Context 404 @{error='Ruta API no encontrada.'}
}

function Serve-Static($Context) {
    $relative = [Uri]::UnescapeDataString($Context.Request.Url.AbsolutePath.TrimStart('/'))
    if (-not $relative) { $relative = 'index.html' }
    $relative = $relative.Replace('/', [IO.Path]::DirectorySeparatorChar)
    $path = [IO.Path]::GetFullPath((Join-Path $script:PanelRoot $relative))
    $root = [IO.Path]::GetFullPath($script:PanelRoot + [IO.Path]::DirectorySeparatorChar)
    if (-not $path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { Write-HttpResponse $Context 404 'text/plain; charset=utf-8' $script:Utf8NoBom.GetBytes('No encontrado'); return }
    $extension=[IO.Path]::GetExtension($path).ToLowerInvariant()
    $contentType=switch ($extension) { '.html' {'text/html; charset=utf-8'} '.js' {'text/javascript; charset=utf-8'} '.css' {'text/css; charset=utf-8'} default {'application/octet-stream'} }
    $Context.Response.Headers['Content-Security-Policy']="default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"
    Write-HttpResponse $Context 200 $contentType ([IO.File]::ReadAllBytes($path))
}

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$Port)
try { $listener.Start() } catch { throw "No se pudo iniciar el panel en 127.0.0.1:$Port. $($_.Exception.Message)" }
$url = "http://127.0.0.1:$Port/#$($script:Token)"
Write-Host "Panel administrativo local: $url"
Write-Host 'Solo acepta conexiones locales. Mantén esta consola abierta y presiona Ctrl+C para cerrar.'
try {
    while ($true) {
        $client=$listener.AcceptTcpClient();$context=$null
        try {
            $context=Read-TcpContext $client
            if ($context.Request.HttpMethod -eq 'OPTIONS') { Write-HttpResponse $context 204 'text/plain' ([byte[]]@());Send-TcpResponse $context;continue }
            if ($context.Request.Url.AbsolutePath.StartsWith('/api/')) { Invoke-Api $context }
            else { Serve-Static $context }
            Send-TcpResponse $context
        } catch {
            if($null -ne $context){try { Write-Json $context 500 @{error='No se pudo procesar la operación.'};Send-TcpResponse $context } catch {}}
            Write-Warning ("Admin panel error: " + $_.Exception.GetType().Name)
        } finally { $client.Close() }
    }
}
finally { $listener.Stop(); $listener.Close(); [Array]::Clear($script:TokenBytes,0,$script:TokenBytes.Length) }
