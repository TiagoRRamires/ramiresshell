
<#
------------------ Sobre ------------------------------------------------------
Conheça nosso projeto em www.ramiresshell.com.br

Descrição:
    Este script analise os eventos de criação de conta(4720, 4738 e 4724) e os eventos de reset de senha de conta (4738 e 4724) no log de Security de todos os servidores Domain Controllers do domínio a partir de um período de tempo especifico.
    Filtra os eventos encontrados em cada Domain Controller exibindo apenas os reset de senha executados com sucesso.
    Não lista alteração de senha efetuada pelo proprio usuario em sua conta.
    Útil para manter guardado registro de eventos de auditoria e identificar de maneira rápida o executor de um reset de senha de conta no domínio.
    Os logs são analisados, formatados e enviado por e-mail.


Considerações:
O usuário executor do script deve ser administrador local de todos os servidores Domain Controllers do domínio informado no parâmetro -DNDomain
O script converte o parametro criterionMinutes. Exemplos:  Converte: 1 minuto para 60000. 1 hora para 3600000. 3 horas para 10800000. 3 horas - 1 minuto para 10740000. 3 horas + 1 minuto para 10860000.



Descrição dos Parâmetros:
-DNDomain
    Campo Obrigatório. Tipo String. Informe o nome do domínio no formato distinguishedname
-CriterionMinutes
    Campo Obrigatório. Tipo Inteiro. Informe os minutos de logs registrados que se deseja analisar
-Sender
    Campo Obrigatório. Tipo String. Informe o endereço SMTP do remetente da mensagem de e-mail
-SenderTitle
    Campo Obrigatório. Tipo String. Informe um título para o remetente. Este título será visualizado pelo destinatário em sua caixa de correio.
-Recipients
    Campo Obrigatório. Tipo Array String. Informe os endereços SMTP dos destinatários que devem receber a mensagem com os logs.
-SmtpServer
    Campo Obrigatório. Tipo String. Informe o servidor SMTP que deve receber o e-mail ou o servidor SMTP relay.


Exemplos:
    Este exemplo pode ser executado em schedule ou a partir do prompt de comandos. Ele captura eventos registrados ate uma hora passada.
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file C:\Script1\AuditPasswordReset.ps1 -DNDomain "DC=ramiresshell,DC=lab" -CriterionMinutes 60 -Sender "no-reply@ramiresshell.com.br" -Recipients "tiago@ramiresshell.com.br", "ramirestiago@hotmail.com" -SenderTitle "Auditoria AD" -SmtpServer 10.1.1.1

    Este exemplo pode ser executado da console do Windows PowerShell. Ele captura eventos registrados até uma hora passada.
    PS > C:\Script1\AuditPasswordReset.ps1 -DNDomain "DC=ramiresshell,DC=lab" -CriterionMinutes 60 -Sender "no-reply@ramiresshell.com.br" -SenderTitle "Auditoria AD" -Recipients "tiago@ramiresshell.com.br", "ramirestiago@hotmail.com" -SmtpServer 10.1.1.1 
------------------------------------------------------------------------
#>




Param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DNDomain,
	
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [int]$CriterionMinutes,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [String]$Sender,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [String]$SenderTitle,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [String[]]$Recipients,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$SmtpServer
)



$MessageSubject = "Audit AD Password Reset " + (Get-Date -Format F)

$CriterionMinutes = $CriterionMinutes * 60000
$LineDCName = "#515f37"
$LineClear = "#ffd24d"
$LineDark = "#ffffb3"

$MsgHtmlBody = "<html><body><table><tr><td>"

$DSEntryConfig = New-Object System.DirectoryServices.DirectoryEntry("LDAP://CN=Configuration,$DNDomain")

$DsSearcher = New-Object System.DirectoryServices.DirectorySearcher
$DsSearcher.SearchRoot = $DSEntryConfig
$DsSearcher.PageSize = 1000
$DsSearcher.Filter = "(&objectClass=nTDSDSA)"
$DsSearcher.SearchScope = "Subtree"
$DsSearcher.PropertiesToLoad.Add("Name")
$DsSearcher.PropertiesToLoad.Add("distinguishedName")

$AllDC = $DsSearcher.FindAll()

foreach ($DCLine in $AllDC)
{
    $Dc = [string]$DCLine.Properties.distinguishedname
    $DcPos1 = $Dc.indexof(",CN=Servers,")
    $DcFinal = $Dc.substring(20,$DcPos1 - 20)

    #Trata servidor que so houve tentativa de reset sem exito
    $AttemptAct = $false
        
    $MsgHtmlBody += "<div style=""font-family:Arial;font-size:18px"">Analise Servidor: $DcFinal</div>"

    #conecta em cada DC e lista logs
    Try
    {
        $LogDc = Get-WinEvent -LogName Security -ComputerName $DcFinal -FilterXPath "*[System[(EventID=4720 or EventID=4738 or EventID=4724) and Task=13824 and TimeCreated[timediff(@SystemTime) < $CriterionMinutes]]]" -ErrorAction Stop
        $AttemptAct = $true
    }
    Catch [System.Exception]
    {
        $MsgHtmlBody += "<div style=""font-family:Arial;font-size:10px;color:#000000"">Sem eventos</div>"
    }
    Catch
    {
        $MsgHtmlBody += "<div style=""font-family:Arial;font-size:14px;color:#b30000"">Erro ao ler o log</div>"
    }
    

    Foreach ($LogDcLine in $LogDc)
    {
        # 4724 -->> Tentativa de reset de senha -->> An attempt was made to reset an account's password....
        If ($LogDcLine.Id -eq 4724)
        {
            $ValidEvent = $true
            $LogDcLineXml = New-Object -TypeName System.Xml.XmlDocument
            $LogDcLineXml.LoadXml($LogDcLine.ToXml())

            #Valida que evento 4724 não foi gerado após execução de um evento 4720  -->>   A user account was created....
            $Find4720 = @($LogDc | Where-Object -FilterScript { $_.Id -eq 4720 -and $_.TimeCreated -le $LogdcLine.TimeCreated -and $_.TimeCreated -ge $LogdcLine.TimeCreated.AddSeconds(-1)})

            #Identifica se evento 4720 é do mesmo usuario que executo reset - Subjet e Target
            ForEach ($Find4720Line in $Find4720)
            {
                $Find4720Xml = New-Object -TypeName System.Xml.XmlDocument
                $Find4720Xml.LoadXml($Find4720Line.ToXml())
                If (($LogDcLineXml.Event.EventData.Data | where { $_.Name -eq "TargetUserName" })."#text" -eq ($Find4720Xml.Event.EventData.Data | where { $_.Name -eq "TargetUserName" })."#text" -and ($LogDcLineXml.Event.EventData.Data | where { $_.Name -eq "TargetDomainName" })."#text" -eq ($Find4720Xml.Event.EventData.Data | where { $_.Name -eq "TargetDomainName" })."#text" -and ($LogDcLineXml.Event.EventData.Data | where { $_.Name -eq "SubjectUserName" })."#text" -eq ($Find4720Xml.Event.EventData.Data | where { $_.Name -eq "SubjectUserName" })."#text" -and ($LogDcLineXml.Event.EventData.Data | where { $_.Name -eq "SubjectDomainName" })."#text" -eq ($Find4720Xml.Event.EventData.Data | where { $_.Name -eq "SubjectDomainName" })."#text")
                {
                    $ValidEvent = $false
                }
                $Find4720Xml = $null
            }

            #Valida se existe evento 4738 associado
            If ($ValidEvent)
            {
                #Valida que evento 4738 (confirmação de alteração de senha) foi gerado antes do evento 4724  -->> 4738  A user account was changed....
                $Find4738 = @($LogDc | Where-Object -FilterScript { $_.Id -eq 4738 -and $_.TimeCreated -le $LogdcLine.TimeCreated.AddSeconds(1) -and $_.TimeCreated -ge $LogdcLine.TimeCreated.AddSeconds(-1)})

                #Identifica Target e attibuto de modificação
                ForEach ($Find4738Line in $Find4738)
                {
                    $Find4738Xml = New-Object -TypeName System.Xml.XmlDocument
                    $Find4738Xml.LoadXml($Find4738Line.ToXml())
                    If (($LogDcLineXml.Event.EventData.Data | where { $_.Name -eq "TargetUserName" })."#text" -eq ($Find4738Xml.Event.EventData.Data | where { $_.Name -eq "TargetUserName" })."#text" -and ($LogDcLineXml.Event.EventData.Data | where { $_.Name -eq "TargetDomainName" })."#text" -eq ($Find4738Xml.Event.EventData.Data | where { $_.Name -eq "TargetDomainName" })."#text" -and ($Find4738Xml.Event.EventData.Data | where { $_.Name -eq "PasswordLastSet" })."#text" -ne "-" )
                    {
                        # Registra 4724 para envio
                        $LogMessage = [string]$LogDcLine.Message
                        $LogMessage = $LogMessage -replace ("`r`n", "<br>")
                        $MsgHtmlBody += "<div style=""border:1px solid black;padding:5px"">" + 
                        "<p style=""background-color:$LineDCName;color:#ffffff;padding:5px;margin:1px;""><b>&nbsp&nbspDomain Controller: </b>$DcFinal</p>" + 
                        "<p style=""background-color:$LineDark;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspTimeCreated: </b>" + $LogDcLine.TimeCreated + "</p>" + 
                        "<p style=""background-color:$LineClear;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspProviderName: </b>" + $LogDcLine.ProviderName + "</p>" +
                        "<p style=""background-color:$LineDark;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspLogName: </b>" + $LogDcLine.LogName + "</p>" + 
                        "<p style=""background-color:$LineClear;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspId: </b>" + $LogDcLine.Id + "</p>" + 
                        "<p style=""background-color:$LineDark;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspUserId: </b>" + $LogDcLine.UserId + "</p>" + 
                        "<p><b>Message: </b>$LogMessage</p></div>"


                        # Registra 4738 para envio
                        $LogMessage = [string]$Find4738Line.Message
                        $LogMessage = $LogMessage -replace ("`r`n", "<br>")
                        $MsgHtmlBody += "<div style=""border:1px solid black;padding:5px"">" + 
                        "<p style=""background-color:$LineDCName;color:#ffffff;padding:5px;margin:1px;""><b>&nbsp&nbspDomain Controller: </b>$DcFinal</p>" + 
                        "<p style=""background-color:$LineDark;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspTimeCreated: </b>" + $Find4738Line.TimeCreated + "</p>" + 
                        "<p style=""background-color:$LineClear;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspProviderName: </b>" + $Find4738Line.ProviderName + "</p>" +
                        "<p style=""background-color:$LineDark;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspLogName: </b>" + $Find4738Line.LogName + "</p>" + 
                        "<p style=""background-color:$LineClear;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspId: </b>" + $Find4738Line.Id + "</p>" + 
                        "<p style=""background-color:$LineDark;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspUserId: </b>" + $Find4738Line.UserId + "</p>" + 
                        "<p><b>Message: </b>$LogMessage</p></div>"

                        $AttemptAct = $false
                    }
                    $Find4738Xml = $null
                }
            }
            $LogDcLineXml = $null
        }
    }
    If ($AttemptAct)
    {
        $MsgHtmlBody += "<div style=""font-family:Arial;font-size:10px;color:#000000"">Registrado tentativas sem êxito ou alteração de senha pelo usuário (4723).</div>"
    }

    $LogDc = $null
}

$MsgHtmlBody += "</td></tr></table></body></html>"


$MailMessage = New-Object System.Net.Mail.MailMessage
$SmtpClient = New-Object System.Net.Mail.SmtpClient
$SmtpClient.Host = $SmtpServer
$MailMessage.From = New-Object System.Net.Mail.MailAddress($Sender, $SenderTitle)
$MailMessage.Sender = New-Object System.Net.Mail.MailAddress($Sender ,$SenderTitle)
ForEach ($Recipient in $Recipients)
{
    $MailMessage.To.Add((new-object System.Net.Mail.MailAddress($Recipient, "")))
}
$MailMessage.Subject = $MessageSubject
$MailMessage.IsBodyHtml = $true
$MailMessage.Body =  $MsgHtmlBody
$SmtpClient.Send($MailMessage)
