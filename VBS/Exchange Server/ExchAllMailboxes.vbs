

'------------------------------------------------------ Sobre ------------------------------------------------------
'Conhe�a nosso projeto em www.ramiresshell.com.br
'
'Descri��o:
'Este script lista todos os servidores Exchange Server em uma Floresta Active Directory, conecta em cada servidor encontrado e lista o uso de armazenamento de cada mailbox.
'Considera o dom�nio ao qual o computador que executara o script pertence.
'Salva o resultado da consulta em um arquivo CSV com mesmo nome e caminho do script.
'�til para levantamento de todos os mailboxes de todos os servidores Ms Exchange Server de uma Floresta Active Directory e o uso de armazenamento de cada mailbox.
'--------------------------------------------------------------------------------------------------------------------



On Error Resume Next

Set WinNet = WScript.CreateObject("WScript.Network") 
Set WinFSO = CreateObject("Scripting.FileSystemObject")



Set ADRootDSE = GetObject("LDAP://RootDSE")
Set ExchServerRS = CreateObject("ADODB.RecordSet")
ExchServerRS.Open "SELECT * FROM 'LDAP://" & ADRootDSE.Get("configurationNamingContext") & "' WHERE objectCategory='msExchExchangeServer'", "Provider=ADsDSOObject"

If ExchServerRS.RecordCount > 0 And Err.Number = 0 Then
	'Cria arquivo e cabe�alho
	CsvFile = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\")) & Left(WScript.ScriptName,Len(WScript.ScriptName) - 4) & ".csv"
	Set TextFile = WinFSO.OpenTextFile (CsvFile, 2, True)
	TextFile.WriteLine ("Servidor Exchange" & vbTab & "Display Mailbox" & vbTab & "MailboxLegacyDN" & vbTab & "Mailbox Size (KB)" & vbTab & "Mailbox Total Itens" & vbTab & "Mailbox Itens Retention Size (KB)")
	
	Do Until ExchServerRS.eof
		'Identifica servidores Exchange na Floresta AD
		Set ExchServer = GetObject(ExchServerRS.Fields.Item(0))
		For Each ExchServerProp In ExchServer.networkAddress
			If Left(ExchServerProp,13) = "ncacn_ip_tcp:" Then
				ServerFQDN = Right(ExchServerProp, Len(ExchServerProp) - 13)
			End If
		Next
		Set ExchServer = Nothing

		'Conecta em cada servidor via WMI para consulta de mailboxes
		Err.Clear
		Set ExchWMI = GetObject("winmgmts:{impersonationLevel=impersonate}!//" & ServerFQDN & "/root/MicrosoftExchangeV2")
		If err.number = 462 Then
			TextFile.WriteLine (ServerFQDN & vbTab & "Impossivel comunica��o com o servidor")
			Else If Err.Number = 70 Or Err.Number = -2147217405 Then
				TextFile.WriteLine (ServerFQDN & vbTab & "Erro devido falta de privilegios administrativos no servidor remoto.")
				Else If Err.Number <> 0 Then
					TextFile.WriteLine (ServerFQDN & vbTab & "Erro: " & Err.Number & "  Descri��o: " & Err.Description)
				Else
					Set AllMailbox = ExchWMI.InstancesOf ("Exchange_Mailbox")
					For Each Mailbox In AllMailbox
						TextFile.WriteLine (ServerFQDN & vbTab & Mailbox.MailboxDisplayName & vbTab & Mailbox.LegacyDN & vbTab & Mailbox.Size & vbTab & Mailbox.TotalItems & vbTab & Mailbox.DeletedMessageSizeExtended)
					Next
				End If
			End If
		End If
		ExchServerRS.MoveNext
	Loop

	ExchServerRS.Close
	Set ExchServerRS = Nothing
	Set ADRootDSE = Nothing
	TextFile.Close
	Answer = MsgBox("Finalizado execu��o do script",0,"Mailbox")
Else
	Answer = MsgBox ("N�o encontrado servidores Ms Exchange Server no Active Directory",0,"Mailbox")
End If

WScript.Quit
