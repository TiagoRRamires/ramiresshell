

<#
------------------ Sobre ------------------------------------------------------
Conheça nosso projeto em www.ramiresshell.com.br

Descrição:
    Este script análisa os seguintes eventos no log de Security de todos os servidores Domain Controllers do domínio a partir de um período de tempo especifico.
       ||==================================== Security Log ===========================================||
       ||    EventID=1102 -->> The audit log was cleared                                              ||
       ||=============================================================================================||
       ||=====================================  Grupos ===============================================||
       ||    EventID=4728 -->> A member was added to a security-enabled global group                  ||
       ||    EventID=4729 -->> A member was removed from a security-enabled global group              ||
       ||                                                                                             ||
       ||    EventID=4732 -->> A member was added to a security-enabled local group                   ||
       ||    EventID=4733 -->> A member was removed from a security-enabled local group               ||
       ||                                                                                             ||
       ||    EventID=4756 -->> A member was added to a security-enabled universal group               ||
       ||    EventID=4757 -->> A member was removed from a security-enabled universal group           ||
       ||                                                                                             ||
       ||    EventID=4764 -->> A groups type was changed                                              ||
       ||                                                                                             ||
       ||    EventID=4727 -->> A security-enabled global group was created                            ||
       ||    EventID=4731 -->> A security-enabled local group was created                             ||
       ||    EventID=4754 -->> A security-enabled universal group was created                         ||
       ||                                                                                             ||
       ||    EventID=4730 -->> A security-enabled global group was deleted                            ||
       ||    EventID=4734 -->> A security-enabled local group was deleted                             ||
       ||    EventID=4758 -->> A security-enabled universal group was deleted                         ||
       ||=============================================================================================||
       ||===================================== Usuarios ==============================================||
       ||    EventID=4720 -->> A user account was created                                             ||
       ||    EventID=4726 -->> A user account was deleted                                             ||
       ||=============================================================================================||
       ||================================= Reset de senha ============================================||
       ||    EventID=4738 -->> A user account was changed                                             ||
       ||    EventID=4724 -->> An attempt was made to reset an accounts password                      ||
       ||=============================================================================================||
    Útil para manter guardado registro de eventos de auditoria e identificar de maneira rápida o administrador que criou ou excluiu um usuário ou grupo de segurança, efetuou um reset de senha de usuário ou alterou o membro ou tipo de um grupo de segurança em um domínio Active Directory.
    Os logs são analisados, formatados e enviado por e-mail.


Considerações:
    O usuário executor do script deve ser administrador local de todos os servidores Domain Controllers do domínio informado no parâmetro -DNDomain


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
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file C:\Script1\AuditADGroupUser.ps1 -DNDomain "DC=ramiresshell,DC=lab" -CriterionMinutes 60 -Sender "no-reply@ramiresshell.com.br" -Recipients "tiago@ramiresshell.com.br", "ramirestiago@hotmail.com" -SenderTitle "Auditoria AD" -SmtpServer 10.1.1.1

    Este exemplo pode ser executado da console do Windows PowerShell. Ele captura eventos registrados até uma hora passada.
    PS > C:\Script1\AuditADGroupUser.ps1 -DNDomain "DC=ramiresshell,DC=lab" -CriterionMinutes 60 -Sender "no-reply@ramiresshell.com.br" -SenderTitle "Auditoria AD" -Recipients "tiago@ramiresshell.com.br", "ramirestiago@hotmail.com" -SmtpServer 10.1.1.1
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



Function Colors
{
    switch ($args[0])
    {
        #Clean Log
        1102 {$HashColors = @{"LineDCName" = "#000000"; "LineClear" = "#D8D8D8"; "LineDark" = "#BEB3B3"}}
        # GroupMeber
        {@(4728, 4729, 4732, 4733, 4756, 4757) -contains $_} {$HashColors = @{"LineDCName" = "#3B5737"; "LineClear" = "#C0E4BA"; "LineDark" = "#74D166"}}
        #ChangeGroupType
        4764 {$HashColors = @{"LineDCName" = "#995116"; "LineClear" = "#FAD3B4"; "LineDark" = "#FDA55F"}}
        #Create Group
        {@(4727, 4731, 4754) -contains $_} {$HashColors = @{"LineDCName" = "#212C4E"; "LineClear" = "#DBEAFF"; "LineDark" = "#BCD0EC"}}
        #Remove grupo
        {@(4730, 4734, 4758) -contains $_} {$HashColors = @{"LineDCName" = "#5B0101"; "LineClear" = "#F3A3A3"; "LineDark" = "#E43A3A"}}
        #Cria usuario
        4720 {$HashColors = @{"LineDCName" = "#2E4078"; "LineClear" = "#e9f2fe"; "LineDark" = "#d2e2f8"}}
        #Remove User
        4726 {$HashColors = @{"LineDCName" = "#660000"; "LineClear" = "#ffb3b3"; "LineDark" = "#ff4d4d"}}
        #Password Reset
        {@(4738, 4724) -contains $_} {$HashColors = @{"LineDCName" = "#515f37"; "LineClear" = "#ffffb3"; "LineDark" = "#ffd24d"}}
        default {$HashColors = $null}
    }
    return $HashColors
}


#Funcao Tabela
Function TableEvent
{
    $LogMessage = [string]$LogDcLine.Message
    $LogMessage = $LogMessage -replace ("`r`n", "<br>")
    $Global:MsgHtmlBody += "<div style=""border:1px solid black;padding:5px"">" + 
    "<p style=""background-color:" + $LineColors.LineDCName + ";color:#ffffff;padding:5px;margin:1px;""><b>&nbsp&nbspDomain Controller: </b>$DcFinal</p>" + 
    "<p style=""background-color:" + $LineColors.LineDark + ";color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspTimeCreated: </b>" + $LogDcLine.TimeCreated + "</p>" + 
    "<p style=""background-color:" + $LineColors.LineClear + ";color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspProviderName: </b>" + $LogDcLine.ProviderName + "</p>" +
    "<p style=""background-color:" + $LineColors.LineDark + ";color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspLogName: </b>" + $LogDcLine.LogName + "</p>" + 
    "<p style=""background-color:" + $LineColors.LineClear + ";color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspId: </b>" + $LogDcLine.Id + "</p>" + 
    "<p style=""background-color:" + $LineColors.LineDark + ";color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspUserId: </b>" + $LogDcLine.UserId + "</p>" + 
    "<p><b>Message: </b>$LogMessage</p></div>"            
}


$Global:MsgHtmlBody = "<html><body>
<table style=""color:#000000;border-style:none"">
<tr><td colspan=""2"" style=""background-color:#000000;color:#ffffff"">Legenda</td></tr>
<tr><td style=""background-color:#BEB3B3"">&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>Exclusão de Log</td></tr>
<tr><td style=""background-color:#74D166"">&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>Gerenciamento de membros de grupos de segurança</td></tr>
<tr><td style=""background-color:#FDA55F"">&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>Alteração do tipo do grupo</td></tr>
<tr><td style=""background-color:#BCD0EC"">&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>Criação de grupo de segurança ou usuário</td></tr>
<tr><td style=""background-color:#E43A3A"">&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>Remoção de grupo de segurança ou usuário</td></tr>
<tr><td style=""background-color:#ffd24d"">&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>Reset de senha de usuário</td></tr>
</table><br><br>
<table style=""font-size:12px;font-size:12""><tr><td>"


$MessageSubject = "Audit AD GrupoFolha " + (Get-Date -Format F)
$CriterionMinutes = $CriterionMinutes * 60000
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

    $Global:MsgHtmlBody += "<div style=""font-family:Arial;font-size:18px"">Analise Servidor: $DcFinal</div>"
    #conecta em cada DC e lista logs
    Try
    {
        $LogDc = Get-WinEvent -LogName Security -ComputerName $DcFinal -FilterXPath "*[System[((EventID=1102 and Task=104) or ((EventID=4720 or EventID=4738 or EventID=4724 or EventID=4726) and Task=13824) or ((EventID=4728 or EventID=4729 or EventID=4732 or EventID=4733 or EventID=4756 or EventID=4757 or EventID=4764 or EventID=4727 or EventID=4731 or EventID=4754 or EventID=4730 or EventID=4734 or EventID=4758) and Task=13826)) and TimeCreated[timediff(@SystemTime) < $CriterionMinutes]]]" -ErrorAction Stop
    }
    Catch [System.Exception]
    {
        $Global:MsgHtmlBody += "<div style=""font-family:Arial;font-size:10px;color:#000000"">Sem eventos</div>"
    }
    Catch
    {
        $Global:MsgHtmlBody += "<div style=""font-family:Arial;font-size:14px;color:#b30000"">Erro ao ler o log</div>"
    }
    

    Foreach ($LogDcLine in $LogDc)
    {
        #ignora 4738 -confirmação de alteracao de sennha
        If ($LogDcLine.Id -ne 4738)
        {
            #Define Cor
            $LineColors = Colors $LogDcLine.Id

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
                    $Register4724 = $false
                    ForEach ($Find4738Line in $Find4738)
                    {
                        $Find4738Xml = New-Object -TypeName System.Xml.XmlDocument
                        $Find4738Xml.LoadXml($Find4738Line.ToXml())
                        If (($LogDcLineXml.Event.EventData.Data | where { $_.Name -eq "TargetUserName" })."#text" -eq ($Find4738Xml.Event.EventData.Data | where { $_.Name -eq "TargetUserName" })."#text" -and ($LogDcLineXml.Event.EventData.Data | where { $_.Name -eq "TargetDomainName" })."#text" -eq ($Find4738Xml.Event.EventData.Data | where { $_.Name -eq "TargetDomainName" })."#text" -and ($Find4738Xml.Event.EventData.Data | where { $_.Name -eq "PasswordLastSet" })."#text" -ne "-" )
                        {
                            # Registra 4724 para envio
                            $Register4724 = $true

                            # Registra 4738 para envio
                            $LogMessage = [string]$Find4738Line.Message
                            $LogMessage = $LogMessage -replace ("`r`n", "<br>")
                            $Global:MsgHtmlBody += "<div style=""border:1px solid black;padding:5px"">" + 
                            "<p style=""background-color:" + $LineColors.LineDCName + ";color:#ffffff;padding:5px;margin:1px;""><b>&nbsp&nbspDomain Controller: </b>$DcFinal</p>" + 
                            "<p style=""background-color:" + $LineColors.LineDark + ";color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspTimeCreated: </b>" + $Find4738Line.TimeCreated + "</p>" + 
                            "<p style=""background-color:" + $LineColors.LineClear + ";color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspProviderName: </b>" + $Find4738Line.ProviderName + "</p>" +
                            "<p style=""background-color:" + $LineColors.LineDark + ";color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspLogName: </b>" + $Find4738Line.LogName + "</p>" + 
                            "<p style=""background-color:" + $LineColors.LineClear + ";color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspId: </b>" + $Find4738Line.Id + "</p>" + 
                            "<p style=""background-color:" + $LineColors.LineDark + ";color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspUserId: </b>" + $Find4738Line.UserId + "</p>" + 
                            "<p><b>Message: </b>$LogMessage</p></div>"
                        }
                        $Find4738Xml = $null
                    }
                    If ($Register4724)
                    {
                        TableEvent
                    }
                }
                $LogDcLineXml = $null
            }
            else
            #Eventos de criação, exclusão, limpeza de log e gerenciamento de grupo
            {
                TableEvent
            }
        }
    }
    $LogDc = $null
}

$Global:MsgHtmlBody += "</td></tr></table></body></html>"

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

