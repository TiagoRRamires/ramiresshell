
<#
------------------ Sobre ------------------------------------------------------
Conhe�a nosso projeto em www.ramiresshell.com.br

Descri��o:
    Este script analise os eventos 4720 e 13824 no log de Security de todos os servidores Domain Controllers do dom�nio a partir de um per�odo de tempo especifico.
    �til para manter guardado registro de eventos de auditoria e identificar de maneira r�pida o criador de uma determinada conta de usu�rio no dom�nio.
    Os logs s�o analisados, formatados e enviado por e-mail.


Considera��es:
O usu�rio executor do script deve ser administrador local de todos os servidores Domain Controllers do dom�nio informado no par�metro -DNDomain


Descri��o dos Par�metros:
-DNDomain
    Campo Obrigat�rio. Tipo String. Informe o nome do dom�nio no formato distinguishedname
-CriterionMinutes
    Campo Obrigat�rio. Tipo Inteiro. Informe os minutos de logs registrados que se deseja analisar
-Sender
    Campo Obrigat�rio. Tipo String. Informe o endere�o SMTP do remetente da mensagem de e-mail
-SenderTitle
    Campo Obrigat�rio. Tipo String. Informe um t�tulo para o remetente. Este t�tulo ser� visualizado pelo destinat�rio em sua caixa de correio.
-Recipients
    Campo Obrigat�rio. Tipo Array String. Informe os endere�os SMTP dos destinat�rios que devem receber a mensagem com os logs.
-SmtpServer
    Campo Obrigat�rio. Tipo String. Informe o servidor SMTP que deve receber o e-mail ou o servidor SMTP relay.


Exemplos:
    Este exemplo pode ser executado em schedule ou a partir do prompt de comandos. Ele captura eventos registrados ate uma hora passada.
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file C:\Script1\SendMailAuditUser.ps1 -DNDomain "DC=ramiresshell,DC=lab" -CriterionMinutes 60 -Sender "no-reply@ramiresshell.com.br" -Recipients "tiago@ramiresshell.com.br", "ramirestiago@hotmail.com" -SenderTitle "Auditoria AD" -SmtpServer 10.1.1.1

    Este exemplo pode ser executado da console do Windows PowerShell. Ele captura eventos registrados at� uma hora passada.
    PS > C:\Script1\SendMailAuditUser.ps1 -DNDomain "DC=ramiresshell,DC=lab" -CriterionMinutes 60 -Sender "no-reply@ramiresshell.com.br" -SenderTitle "Auditoria AD" -Recipients "tiago@ramiresshell.com.br", "ramirestiago@hotmail.com" -SmtpServer 10.1.1.1 
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


$MessageSubject = "Audit AD Create User " + (Get-Date -Format F)

$CriterionMinutes = $CriterionMinutes * 60000
$MsgHtmlBody = "<html><body><table><tr><td>"

$DcFilter = "(&objectClass=nTDSDSA)"
$DSEntryConfig = New-Object System.DirectoryServices.DirectoryEntry("LDAP://CN=Configuration,$DNDomain")

$DsSearcher = New-Object System.DirectoryServices.DirectorySearcher
$DsSearcher.SearchRoot = $DSEntryConfig
$DsSearcher.PageSize = 1000
$DsSearcher.Filter = $DcFilter
$DsSearcher.SearchScope = "Subtree"
$DsSearcher.PropertiesToLoad.Add("Name")
$DsSearcher.PropertiesToLoad.Add("distinguishedName")

$AllDC = $DsSearcher.FindAll()

foreach ($DCLine in $AllDC)
    {
        $Dc = [string]$DCLine.Properties.distinguishedname
        $DcPos1 = $Dc.indexof(",CN=Servers,")
        $DcFinal = $Dc.substring(20,$DcPos1 - 20)
        
        $MsgHtmlBody += "<div style=""font-family:Arial;font-size:18px"">Analise Servidor: $DcFinal</div>"

        Try
        {
            $LogDc = Get-WinEvent -LogName Security -ComputerName $DcFinal -FilterXPath "*[System[EventID=4720 and Task=13824 and TimeCreated[timediff(@SystemTime) < $CriterionMinutes]]]"
        }
        Catch
        { 
            $MsgHtmlBody += "<div style=""font-family:Arial;font-size:14px;color:#b30000"">Erro ao ler o log</div>"
        }

        Foreach ($LogDcLine in $LogDc)
        {
            $LogMessage = [string]$LogDcLine.Message
            $LogMessage = $LogMessage -replace ("`r`n", "<br>")
            $MsgHtmlBody += "<div style=""border:1px solid black;padding:5px"">" + 
            "<p style=""background-color:#515f37;color:#ffffff;padding:5px;margin:1px;""><b>&nbsp&nbspDomain Controller: </b>$DcFinal</p>" + 
            "<p style=""background-color:#d2e2f8;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspTimeCreated: </b>" + $LogDcLine.TimeCreated + "</p>" + 
            "<p style=""background-color:#e9f2fe;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspProviderName: </b>" + $LogDcLine.ProviderName + "</p>" +
            "<p style=""background-color:#d2e2f8;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspLogName: </b>" + $LogDcLine.LogName + "</p>" + 
            "<p style=""background-color:#e9f2fe;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspId: </b>" + $LogDcLine.Id + "</p>" + 
            "<p style=""background-color:#d2e2f8;color:#000000;padding:5px;margin:1px;""><b>&nbsp&nbspUserId: </b>" + $LogDcLine.UserId + "</p>" + 
            "<p><b>Message: </b>$LogMessage</p></div>"
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



