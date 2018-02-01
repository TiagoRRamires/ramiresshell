
'------------------------------------------------------ Sobre ------------------------------------------------------
'Conheça nosso projeto em www.ramiresshell.com.br
'
'Descrição:
'Este script realiza uma consulta LDAP com ADO no domínio Active Directory para listar informações de quota de armazenamento, envio e recebimento de e-mail configurado para todos os usuários com mailbox habilitada em um servidor Ms Exchange Server.
'Considera o domínio ao qual o computador que executara o script pertence.
'Possui um limite de 20000 mailbox para retorno da consulta ADO que pode ser alterado de acordo com o ambiente.
'Salva o resultado da consulta em um arquivo CSV com mesmo nome e caminho do script.
'Útil para levantamento de configuração quota de mailbox do Ms Exchange Server.
'--------------------------------------------------------------------------------------------------------------------


On Error Resume Next

'-------------- Parametros ----------------------------
LimiteUsuarios = 20000
'------------------------------------------------------

Set WinFSO = CreateObject("Scripting.FileSystemObject")

Set ADRootDSE = GetObject("LDAP://RootDSE")
Set AdODBConn = CreateObject("ADODB.Connection")
AdODBConn.Open "Provider=ADsDSOObject;"
Set AdODBCommand = CreateObject("ADODB.Command")
AdODBCommand.ActiveConnection = AdODBConn
AdODBCommand.Properties("Page Size") = LimiteUsuarios
AdODBCommand.CommandText = "<LDAP://" & ADRootDSE.Get("DefaultNamingContext") & ">;(&(objectCategory=person)(objectClass=user)(|(homeMDB=*)));distinguishedName,name,mail,homeMDB,mDBUseDefaults,mDBStorageQuota,mDBOverQuotaLimit,mDBOverHardQuotaLimit,deletedItemFlags,garbageCollPeriod,delivContLength,submissionContLength,legacyExchangeDN,msExchHomeServerName;subtree"
Set LdapRecordSet = AdODBCommand.Execute

If LdapRecordSet.RecordCount = 0 Or Err.Number <> 0 Then
	Answer = MsgBox ("Não encontrado usuarios com mailbox habilitada no Active Directory",0,"Active Directory")
Else
	CsvFile = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\")) & Left(WScript.ScriptName,Len(WScript.ScriptName) - 4) & ".csv"
	Set TextFile = WinFSO.OpenTextFile (CsvFile, 2, True)
	TextFile.WriteLine ("User Name" & vbTab & "Primary Email Address" & vbTab & "Database" & vbTab & "User Issue Warning (KB)" & vbTab & "User Prohibit Send (KB)" & vbTab & "User Prohibit Send Receive (KB)" & vbTab & "User Retention Item Age (Day)" & vbTab & "User Receive Size (KB)" & vbTab & "User Sending Size (KB)" & vbTab & "DatabaseServer" & vbTab & "ExchangeDN")
	While Not LdapRecordSet.EOF
		UserName =  LdapRecordSet.Fields("name")
		Email = LdapRecordSet.Fields("mail")
		MailboxDatabase = LdapRecordSet.Fields("homeMDB")
				
		DefaultDB = LdapRecordSet.Fields("mDBUseDefaults")
		If DefaultDB Then
			IssueWarning = "Default Database Settings"
			ProhibitSend = "Default Database Settings"
			ProhibitHard = "Default Database Settings"
		Else
			If IsNull(LdapRecordSet.Fields("mDBStorageQuota")) Then
				IssueWarning = "Not Set"
			Else
				IssueWarning = CStr(LdapRecordSet.Fields("mDBStorageQuota"))
			End If

			If IsNull(LdapRecordSet.Fields("mDBOverQuotaLimit")) Then
				ProhibitSend = "Not Set"
			Else
				ProhibitSend = CStr(LdapRecordSet.Fields("mDBOverQuotaLimit"))  
			End If

			If IsNull(LdapRecordSet.Fields("mDBOverHardQuotaLimit")) Then
				ProhibitHard = "Not Set"
			Else
				ProhibitHard = CStr(LdapRecordSet.Fields("mDBOverHardQuotaLimit"))
			End If
		End If
				
		ItemRetention = LdapRecordSet.Fields("deletedItemFlags")
		If ItemRetention <= 0 Or IsNull(ItemRetention) Then
			TempoRetencao = "Default Database Settings"
		Else
			If IsNull(LdapRecordSet.Fields("garbageCollPeriod")) Then
				TempoRetencao = "0"
			Else
				TempoRetencao = CLng(LdapRecordSet.Fields("garbageCollPeriod"))
				TempRet = TempoRetencao / 60
				TempoRetencao = TempRet / 60
				TempRet = TempoRetencao / 24
				TempoRetencao = CStr(TempRet)
			End If
		End If
				
		If LdapRecordSet.Fields("delivContLength") = 0 Or IsNull(LdapRecordSet.Fields("delivContLength")) Then
			ReceiveSizeMail = "Default Organization Settings"
		Else
			ReceiveSizeMail = CStr(LdapRecordSet.Fields("delivContLength"))
		End If

		If LdapRecordSet.Fields("submissionContLength") = 0 Or IsNull(LdapRecordSet.Fields("submissionContLength")) Then
			SendsizeMail = "Default Organization Settings"
		Else
			SendsizeMail = CStr(LdapRecordSet.Fields("submissionContLength"))
		End If
				
		ExchServerTemp = LdapRecordSet.Fields("msExchHomeServerName")
		Pos1 = InStrRev(ExchServerTemp,"cn=",Len(ExchServerTemp),1)
		Pos2 = Len(ExchServerTemp) - pos1 - 2
		ExchServer = Right(ExchServerTemp,Pos2)
		UserEXDN = LdapRecordSet.Fields("legacyExchangeDN")

		TextFile.WriteLine (UserName & vbTab &  Email & vbTab & MailboxDatabase & vbTab & IssueWarning & vbTab & ProhibitSend & vbTab & ProhibitHard & vbTab & TempoRetencao & vbTab & ReceiveSizeMail & vbTab & SendsizeMail & vbTab & ExchServer & vbTab & UserEXDN)
               
		LdapRecordSet.MoveNext
	Wend
	TextFile.Close
	If Err.Number = 0 Then
		Answer = MsgBox ("Script executado com Sucesso" & vbCrLf & "Arquivo gerado: " & CsvFile,0,"Get AD Users")
	Else
		Answer = MsgBox ("Script executado com ERRO" & vbCrLf & "Arquivo gerado pode conter inconsistência: " & CsvFile,0,"Get AD Users")
	End If
End If
AdODBConn.Close		  

WScript.Quit
