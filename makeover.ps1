# Firestick Makeover: limpeza, tela inicial bonita, botões do controle e otimizações para Fire TV.
# Rode pelo Start-Here.bat. Funciona no Windows PowerShell 5.1 e no PowerShell 7.
param([string]$Ip)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Here = $PSScriptRoot
$Pkg = 'io.github.vitoradriao.makeover'
$HomeSvc = "$Pkg/$Pkg.HomeService"
$BtnSvc = "$Pkg/$Pkg.ButtonService"
$DeviceList = '/sdcard/makeover-disabled.txt'   # o que este programa desativou, guardado no próprio stick
$DeviceTweaks = '/sdcard/makeover-tweaks.txt'   # valores anteriores dos ajustes, para desfazer
$Apk = @("$Here\makeover.apk", "$Here\dist\makeover.apk") | Where-Object { Test-Path $_ } | Select-Object -First 1
$Script:S = $null

# Botões conhecidos: texto que o Fire OS escreve no log quando o botão é apertado.
$KnownButtons = [ordered]@{
    'Prime Video' = 'deeplink_prime_video'
    'Peacock'     = 'asin=B08BG9MPT9'
    'Disney+'     = 'asin=B07Y8SJGCV'
}
$FriendlyNames = @{
    'com.netflix.ninja' = 'Netflix'; 'com.disney.disneyplus' = 'Disney+'; 'com.hbo.hbonow' = 'HBO Max'
    'com.wbd.stream' = 'Max'; 'com.globo.globotv' = 'Globoplay'; 'com.cbs.ca' = 'Paramount+'
    'com.cbs.ott' = 'Paramount+'; 'org.smarttube.stable' = 'SmartTube'; 'com.esaba.downloader' = 'Downloader'
    'com.amazon.firetv.youtube' = 'YouTube'; 'com.google.android.youtube.tv' = 'YouTube'
    'com.spotify.tv.android' = 'Spotify'; 'org.xbmc.kodi' = 'Kodi'; 'com.plexapp.android' = 'Plex'
    'com.crunchyroll.crunchyroid' = 'Crunchyroll'; 'tv.twitch.android.app' = 'Twitch'
    'com.apple.atve.amazon.appletv' = 'Apple TV'; 'com.amazon.firebat' = 'Prime Video'
}
$GroupInfo = [ordered]@{
    'alexa'      = 'Alexa (assistente de voz, avisos, música por voz). Desative só se você não usa a Alexa.'
    'amazonapps' = 'Apps da Amazon que pouca gente usa (Amazon Music, Amazon Photos, Silk).'
    'casting'    = 'Espelhamento da Amazon (Miracast e "jogar" do celular). Netflix/YouTube do celular continuam funcionando.'
    'livetv'     = 'Aba "Ao vivo" da Amazon e guias de canais.'
    'primevideo' = 'Prime Video. Desative só se você não assina.'
    'updates'    = 'Atualizações automáticas do Fire OS. Menos interrupções, mas você deixa de receber correções.'
}

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Title($text) { Write-Host ""; Write-Host "== $text ==" -ForegroundColor Cyan }
function Ask($question, [bool]$default = $false) {
    $hint = if ($default) { '[S/n]' } else { '[s/N]' }
    $a = (Read-Host "$question $hint").Trim().ToLower()
    if (-not $a) { return $default }
    return $a.StartsWith('s') -or $a.StartsWith('y')
}

# ---------- adb ----------

function Ensure-Adb {
    foreach ($p in "$Here\platform-tools\adb.exe", "$Here\sdk\platform-tools\adb.exe") {
        if (Test-Path $p) { $Script:Adb = $p; return }
    }
    Title 'Ferramenta adb'
    Say 'Para falar com o Fire TV, o programa precisa do platform-tools do Google (cerca de 8 MB).'
    Say 'Baixar significa aceitar a licença do Android SDK: https://developer.android.com/studio/terms'
    if (-not (Ask 'Baixar agora?' $true)) { throw 'Sem o adb não dá para continuar.' }
    $file = 'platform-tools_r37.0.3-win.zip'
    $zip = "$env:TEMP\$file"
    # curl.exe ships with Windows 10/11 and doesn't stall like Invoke-WebRequest can.
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -fsSL -o $zip "https://dl.google.com/android/repository/$file"
        if ($LASTEXITCODE) { throw "Falha ao baixar o platform-tools (curl $LASTEXITCODE). Confira a internet." }
    } else {
        Invoke-WebRequest "https://dl.google.com/android/repository/$file" -OutFile $zip -UseBasicParsing
    }
    $sha1 = (Get-FileHash $zip -Algorithm SHA1).Hash.ToLower()
    if ($sha1 -ne 'b3fde5239ad89229d5a9178375b81c9887a24172') { throw "O arquivo baixado não confere (SHA-1 $sha1)." }
    Expand-Archive $zip $Here -Force
    Remove-Item $zip
    $Script:Adb = "$Here\platform-tools\adb.exe"
    Say 'adb pronto.' Green
}

# 'Continue': in Windows PowerShell 5.1, adb writing to stderr would otherwise stop the script.
function Adb { $ErrorActionPreference = 'Continue'; & $Script:Adb -s $Script:S @args 2>&1 | Out-String }
function Tv([string]$cmd) { $ErrorActionPreference = 'Continue'; (& $Script:Adb -s $Script:S shell $cmd 2>&1 | Out-String).Trim() }

# Procura aparelhos com o adb aberto (porta 5555) na rede local.
function Find-Sticks {
    $prefixes = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixLength -ge 16 } |
        ForEach-Object { $_.IPAddress.Substring(0, $_.IPAddress.LastIndexOf('.')) } | Select-Object -Unique
    $found = @()
    foreach ($p in $prefixes) {
        $tries = foreach ($i in 1..254) {
            $c = New-Object Net.Sockets.TcpClient
            [pscustomobject]@{ Ip = "$p.$i"; Client = $c; Task = $c.ConnectAsync("$p.$i", 5555) }
        }
        Start-Sleep -Milliseconds 1500
        foreach ($t in $tries) {
            if ($t.Task.Status -eq 'RanToCompletion' -and $t.Client.Connected) { $found += $t.Ip }
            $t.Client.Dispose()
        }
    }
    return $found
}

function Connect-Stick {
    Ensure-Adb
    $target = $Ip
    if (-not $target) {
        Title 'Procurando o Fire TV na sua rede'
        $found = @(Find-Sticks)
        if ($found.Count -eq 1) { $target = $found[0]; Say "Encontrado: $target" Green }
        elseif ($found.Count -gt 1) {
            for ($i = 0; $i -lt $found.Count; $i++) { Say "  $($i + 1)) $($found[$i])" }
            $target = $found[[int](Read-Host 'Qual deles') - 1]
        } else {
            Say 'Não encontrei nenhum Fire TV com a Depuração ADB ligada.' Yellow
            Say '  - A TV está ligada e o Fire TV está na tela inicial?'
            Say '  - Configurações > Minha Fire TV > Opções do desenvolvedor > Depuração ADB está ligada?'
            Say '  - O PC e o Fire TV estão na mesma rede? Roteadores de operadora costumam isolar a rede'
            Say '    5 GHz (nome terminando em _5G) do cabo: ligue o Fire TV na rede 2.4 GHz durante a instalação.'
            $target = (Read-Host 'Digite o IP do Fire TV (Configurações > Minha Fire TV > Sobre > Rede), ou Enter para sair').Trim()
            if (-not $target) { exit }
        }
    }
    $Script:S = if ($target -match ':') { $target } else { "${target}:5555" }
    $ErrorActionPreference = 'Continue'
    & $Script:Adb connect $Script:S | Out-Null
    for ($i = 0; $i -lt 30; $i++) {
        $state = (& $Script:Adb -s $Script:S get-state 2>&1 | Out-String).Trim()
        if ($state -eq 'device') { break }
        if ($i -eq 0) { Say 'Olhe a TV: aparece "Permitir depuração USB?". Marque "Sempre permitir deste computador" e OK.' Yellow }
        Start-Sleep 2
        & $Script:Adb connect $Script:S | Out-Null
    }
    if ($state -ne 'device') { throw "Não consegui conectar em $($Script:S) ($state)." }
    $model = Tv 'getprop ro.product.model'
    $os = Tv 'getprop ro.build.version.name'
    $sdk = [int](Tv 'getprop ro.build.version.sdk')
    Say "Conectado: $model, $os (Android API $sdk)" Green
    if ($os -notmatch 'Fire OS') { Say 'Atenção: isto não parece um Fire TV. O programa foi feito para Fire OS.' Yellow }
    if ($sdk -lt 28) { Say 'Atenção: versão antiga do Fire OS. A tela inicial e os botões podem não funcionar (testado no Fire OS 8).' Yellow }
}

# ---------- limpeza ----------

function Read-Debloat {
    Get-Content "$Here\debloat.txt" | Where-Object { $_ -match '^\s*[a-z]' } | ForEach-Object {
        $parts = $_ -split '#', 2
        $f = $parts[0].Trim() -split '\s+'
        [pscustomobject]@{ Group = $f[0]; Package = $f[1]; Note = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' } }
    }
}

function Enabled-Packages { (Tv 'pm list packages -e') -split "`n" | ForEach-Object { $_.Trim() -replace '^package:', '' } }

function Choose-Groups {
    $groups = @('safe')
    Say 'O grupo básico (anúncios, rastreamento, telemetria e extras) é sempre aplicado.'
    foreach ($g in $GroupInfo.Keys) {
        if (Ask "Desativar também: $($GroupInfo[$g])") { $groups += $g }
    }
    return $groups
}

function Debloat([bool]$preview) {
    Title $(if ($preview) { 'Prévia da limpeza (nada é alterado)' } else { 'Limpeza' })
    $groups = if ($preview) { @('safe') + @($GroupInfo.Keys) } else { Choose-Groups }
    $enabled = Enabled-Packages
    $done = 0; $refused = 0
    foreach ($item in (Read-Debloat | Where-Object { $groups -contains $_.Group })) {
        if ($enabled -notcontains $item.Package) { continue }   # não instalado ou já desativado
        if ($preview) { Say ("  [{0,-10}] {1}  ({2})" -f $item.Group, $item.Package, $item.Note); $done++; continue }
        $r = Tv "pm disable-user --user 0 $($item.Package)"
        if ($r -match 'disabled') {
            Tv "echo $($item.Package) >> $DeviceList" | Out-Null
            Say "  desativado: $($item.Package)  ($($item.Note))" Green; $done++
        } else { Say "  o Fire OS recusou: $($item.Package)" DarkGray; $refused++ }
    }
    if ($preview) { Say "$done apps seriam desativados (contando todos os grupos opcionais)."; return }
    Say "$done desativados, $refused protegidos pelo Fire OS. Nada foi apagado: 'Desfazer tudo' traz de volta." Green
    if ($done -gt 0 -and (Ask 'Reiniciar o Fire TV agora para liberar a memória?' $true)) { Tv 'reboot' | Out-Null; Say 'Reiniciando. Espere a TV voltar antes de usar outra opção.' }
}

# ---------- tela inicial ----------

function Enable-Services([string[]]$add) {
    $cur = Tv 'settings get secure enabled_accessibility_services'
    $list = @($cur -split ':' | Where-Object { $_ -and $_ -ne 'null' -and $_ -notlike "$Pkg/*" -and $add -notcontains $_ })
    $others = @($list | Where-Object { $_ -match 'fireframe|projectivy|homeonfire|home_on_fire' })
    if ($others.Count -gt 0) {
        Say "Outro launcher também está assumindo o botão Home: $($others -join ', ')" Yellow
        if (Ask 'Desligar esse outro launcher para não brigarem?' $true) { $list = @($list | Where-Object { $others -notcontains $_ }) }
    }
    Tv "settings put secure enabled_accessibility_services $((@($list) + $add) -join ':')" | Out-Null
    Tv 'settings put secure accessibility_enabled 1' | Out-Null
}

function Install-Launcher {
    Title 'Tela inicial Makeover'
    if (-not $Apk) { throw 'makeover.apk não está nesta pasta. Baixe o zip da página de releases.' }
    Say 'Instalando...'
    $r = Adb install -r $Apk
    if ($r -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
        Say 'Já existe um Makeover assinado com outra chave. Ele será removido e instalado de novo (o dock volta ao padrão).' Yellow
        Adb uninstall $Pkg | Out-Null
        $r = Adb install $Apk
    }
    if ($r -notmatch 'Success') { throw "Falha ao instalar: $r" }
    # READ_LOGS é para os botões do controle. O processo precisa reiniciar depois da permissão;
    # force-stop reinicia e também tira os serviços da lista, que Enable-Services recoloca.
    Tv "pm grant $Pkg android.permission.READ_LOGS" | Out-Null
    Tv "appops set $Pkg REQUEST_INSTALL_PACKAGES allow" | Out-Null
    Tv "am force-stop $Pkg" | Out-Null
    Enable-Services @($HomeSvc, $BtnSvc)
    $wall = ''
    $names = @('aurora', 'citylights', 'earthrise', 'southernlights', 'sunrise')
    Say 'Papéis de parede incluídos: 1) aurora  2) citylights  3) earthrise  4) southernlights  5) sunrise'
    $w = (Read-Host 'Escolha um número (Enter = aurora)').Trim()
    $wall = if ($w -match '^[1-5]$') { $names[[int]$w - 1] } else { 'aurora' }
    Tv "am start -n $Pkg/.MainActivity --es wallpaper $wall" | Out-Null
    Say 'Pronto. Aperte Home no controle: deve abrir o Makeover.' Green
    Say 'No Makeover: segure OK num app (ou aperte o botão de menu) para mover, tirar ou pôr no dock.'
    Say 'A grade no topo abre todos os apps; o ícone de imagem troca o papel de parede.'
}

# ---------- botões do controle ----------

function Installed-Apps {
    (Tv 'pm list packages -3 -e') -split "`n" | ForEach-Object { $_.Trim() -replace '^package:', '' } |
        Where-Object { $_ -and $_ -ne $Pkg -and $_ -notlike '*.overlay.*' } | Sort-Object
}

function Remap-Buttons {
    Title 'Botões do controle'
    if ((Tv "pm list packages $Pkg") -notmatch $Pkg) { Say 'Instale a tela inicial Makeover primeiro (opção 3).' Yellow; return }
    $apps = @(Installed-Apps)
    Say 'Apps instalados:'
    for ($i = 0; $i -lt $apps.Count; $i++) {
        $n = $FriendlyNames[$apps[$i]]; Say ("  {0,2}) {1}" -f ($i + 1), $(if ($n) { "$n ($($apps[$i]))" } else { $apps[$i] }))
    }
    $rules = @()
    $buttons = [ordered]@{}; foreach ($k in $KnownButtons.Keys) { $buttons[$k] = $KnownButtons[$k] }
    if (Ask 'Seu controle tem algum outro botão de app que você quer trocar (texto descoberto no README)?') {
        $txt = (Read-Host 'Texto do botão no log (ex.: asin=B0XXXXXXX)').Trim()
        if ($txt) { $buttons["botão $txt"] = $txt }
    }
    foreach ($b in $buttons.Keys) {
        $a = (Read-Host "Botão $b deve abrir qual número? (Enter = não mexer)").Trim()
        if ($a -match '^\d+$' -and [int]$a -ge 1 -and [int]$a -le $apps.Count) { $rules += "$($buttons[$b])>$($apps[[int]$a - 1])" }
    }
    $spec = $rules -join ';'
    Tv "am start -n $Pkg/.MainActivity --es remap '$spec'" | Out-Null
    if ($rules.Count -eq 0) { Say 'Nenhum botão trocado (regras apagadas).' } else { Say "Pronto: $($rules.Count) botão(ões) trocado(s). Teste no controle." Green }
    Say 'O botão da Netflix não pode ser trocado: ele não deixa um texto próprio no log (veja o README).' DarkGray
}

# ---------- otimizações ----------

function Save-Tweak($key) {
    if ((Tv "grep -c '^$key=' $DeviceTweaks 2>/dev/null") -match '^[1-9]') { return }   # guarda só o valor original
    $v = Tv "settings get $($key -replace '\.', ' ')"
    Tv "echo '$key=$v' >> $DeviceTweaks" | Out-Null
}

function Optimize {
    Title 'Otimizações'
    if (Ask 'Animações 2x mais rápidas (menus e troca de apps parecem mais ágeis)?' $true) {
        foreach ($k in 'window_animation_scale', 'transition_animation_scale', 'animator_duration_scale') {
            Save-Tweak "global.$k"; Tv "settings put global $k 0.5" | Out-Null
        }
        Say '  animações em 0.5x' Green
    }
    Say 'DNS que bloqueia anúncios (AdGuard DNS): corta anúncios e rastreadores em vários apps.'
    Say 'Pode atrapalhar apps gratuitos que dependem de anúncio. Desfazer volta ao DNS da sua rede.'
    if (Ask 'Usar o AdGuard DNS?') {
        Save-Tweak 'global.private_dns_mode'; Save-Tweak 'global.private_dns_specifier'
        Tv 'settings put global private_dns_mode hostname' | Out-Null
        Tv 'settings put global private_dns_specifier dns.adguard-dns.com' | Out-Null
        Say '  DNS privado: dns.adguard-dns.com' Green
    }
    Say 'Compilar os apps instalados por completo: a primeira abertura de cada app tende a ficar mais rápida.'
    Say 'Leva alguns minutos e usa um pouco mais de espaço. Atualizar um app desfaz o ajuste dele.'
    if (Ask 'Compilar agora?') {
        foreach ($a in Installed-Apps) {
            $r = Tv "cmd package compile -m speed -f $a"
            Say "  $a : $(if ($r -match 'Success') { 'ok' } else { $r })"
        }
    }
}

# ---------- manutenção ----------

function Reapply {
    Title 'Reaplicar depois de atualização do Fire OS'
    $list = (Tv "cat $DeviceList 2>/dev/null") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique
    $enabled = Enabled-Packages; $n = 0
    foreach ($p in $list) { if ($enabled -contains $p) { Tv "pm disable-user --user 0 $p" | Out-Null; Say "  desativado de novo: $p"; $n++ } }
    Say "$n apps tinham voltado."
    if ((Tv "pm list packages $Pkg") -match $Pkg) {
        Tv "am force-stop $Pkg" | Out-Null
        Enable-Services @($HomeSvc, $BtnSvc)
        Say 'Tela inicial e botões religados.' Green
    }
}

function Undo-All {
    Title 'Desfazer tudo'
    if (-not (Ask 'Reativar tudo o que este programa desativou, voltar os ajustes e remover o Makeover?')) { return }
    $list = (Tv "cat $DeviceList 2>/dev/null") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique
    foreach ($p in $list) { Tv "pm enable $p" | Out-Null; Say "  reativado: $p" }
    $tweaks = (Tv "cat $DeviceTweaks 2>/dev/null") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '=' }
    foreach ($t in $tweaks) {
        $k, $v = $t -split '=', 2; $ns, $name = $k -split '\.', 2
        if ($v -eq 'null') { Tv "settings delete $ns $name" | Out-Null } else { Tv "settings put $ns $name $v" | Out-Null }
        Say "  $name voltou para $v"
    }
    Adb uninstall $Pkg | Out-Null
    Tv "rm -f $DeviceList $DeviceTweaks" | Out-Null
    Say 'Feito. Reinicie o Fire TV para tudo voltar ao normal.' Green
}

# Amazon's own settings screen; android.settings.SETTINGS would pass through Amazon's home screen.
function Open-Settings {
    Tv 'am start -a android.intent.action.MAIN -c android.intent.category.LEANBACK_SETTINGS -p com.amazon.tv.launcher' | Out-Null
    Say 'Configurações abertas na TV.'
}

function Full-Setup {
    Title 'Instalação completa'
    Say 'Antes, na TV: Configurações > Preferências > Conteúdo em destaque: desligue reprodução automática de vídeo e áudio.'
    Say 'E em Preferências > Configurações de privacidade: desligue Dados de uso do dispositivo, Coletar dados de uso de apps e Anúncios baseados em interesses.'
    Read-Host 'Enter quando terminar' | Out-Null
    Install-Launcher
    Remap-Buttons
    Optimize
    Debloat $false
}

# ---------- menu ----------

if ($MyInvocation.InvocationName -eq '.') { return }   # dot-sourced: only load the functions (for testing)
try {
    Connect-Stick
    while ($true) {
        Title 'Firestick Makeover'
        Say '  F  Primeira vez? Instalação completa, passo a passo'
        Say '  1  Prévia da limpeza (não altera nada)'
        Say '  2  Limpeza: desativar anúncios, rastreamento e apps da Amazon'
        Say '  3  Instalar ou atualizar a tela inicial Makeover'
        Say '  4  Trocar o que os botões de app do controle abrem'
        Say '  5  Otimizações (animações, DNS anti-anúncio, apps mais rápidos)'
        Say '  6  Reaplicar depois de uma atualização do Fire OS'
        Say '  7  Desfazer tudo'
        Say '  8  Abrir as configurações do Fire TV'
        Say '  0  Sair'
        switch ((Read-Host 'Opção').Trim().ToUpper()) {
            'F' { Full-Setup }
            '1' { Debloat $true }
            '2' { Debloat $false }
            '3' { Install-Launcher }
            '4' { Remap-Buttons }
            '5' { Optimize }
            '6' { Reapply }
            '7' { Undo-All }
            '8' { Open-Settings }
            '0' { exit }
        }
    }
} catch {
    Say "Erro: $($_.Exception.Message)" Red
    Say 'Se precisar de ajuda, abra uma issue em https://github.com/vitoradriao/firestick-makeover/issues com esta mensagem.'
}
