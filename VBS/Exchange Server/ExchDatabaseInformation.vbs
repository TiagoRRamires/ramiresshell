
'------------------------------------------------------ Sobre ------------------------------------------------------
'Conheça nosso projeto em www.ramiresshell.com.br
'
'Descrição:
'Este script lista todos os servidores Exchange Server em uma Floresta Active Directory, conecta em cada servidor encontrado via CDOEXM para lista informações de regras de armazenamento de cada database do Ms Exchange Server.
'Considera o domínio ao qual o computador que executara o script pertence.
'Salva o resultado da consulta em um arquivo CSV com mesmo nome e caminho do script.
'Útil para levantamento de databases de todos os servidores Ms Exchange Server de uma Floresta Active Directory e suas configurações de quota e regras de armazenamento.
'--------------------------------------------------------------------------------------------------------------------



On Error Resume Next
Set WinFSO = CreateObject("Scripting.FileSystemObject")


Set ADRootDSE = GetObject("LDAP://RootDSE")
Set ExchServerRS = CreateObject("ADODB.RecordSet")
ExchServerRS.Open "SELECT * FROM 'LDAP://" & ADRootDSE.Get("configurationNamingContext") & "' WHERE objectCategory='msExchExchangeServer'", "Provider=ADsDSOObject"

If ExchServerRS.RecordCount > 0 And Err.Number = 0 Then
	CsvFile = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\")) & Left(WScript.ScriptName,Len(WScript.ScriptName) - 4) & ".csv"
	Set TextFile = WinFSO.OpenTextFile (CsvFile, 2, True)

	Do Until ExchServerRS.eof
		Set ExchServer = GetObject(ExchServerRS.Fields.Item(0))
		For Each ExchServerProp In ExchServer.networkAddress
			If Left(ExchServerProp,13) = "ncacn_ip_tcp:" Then
				ServerFQDN = Right(ExchServerProp, Len(ExchServerProp) - 13)
			End If
		Next
		Set ExchServer = Nothing
	
		Err.Clear
		Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!//" & ServerFQDN & "/ROOT/MicrosoftExchangeV2")
		If Err.Number <> 0 Then
			TextFile.WriteLine ("")
			TextFile.WriteLine ("Server: " & ServerFQDN & " -  Erro ao conectar via WMI remotamente")
		Else
			Set CDOServer=CreateObject("CDOEXM.ExchangeServer")
			Set CDOSG=CreateObject("CDOEXM.StorageGroup")
			Set CDOMailboxDB=CreateObject("CDOEXM.MailboxStoreDB")
			Set CDOPublicDB=CreateObject("CDOEXM.PublicStoreDB")

			TextFile.WriteLine ("")
			TextFile.WriteLine ("Server: " & ServerFQDN)

			CDOServer.DataSource.Open ServerFQDN
			ServerSG = CDOServer.StorageGroups

			For i = 0 To UBound(ServerSG)
				Err.Clear
				SGPath = ServerSG(i)
				CDOSG.DataSource.Open "LDAP://" & CDOServer.DirectoryServer & "/" & SGPath
				If Err.Number <> -1056759263 Then
					ServerMailboxDB = CDOSG.MailboxStoreDBs
					For j = 0 To UBound(ServerMailboxDB)
						CDOMailboxDB.DataSource.open "LDAP://" & ServerMailboxDB(j)	
						TextFile.WriteLine ("Storage Group" & vbTab & "Mailbox Database Name" & vbTab & "Keep Deleted Mailbox for Days" & vbTab & "Keep Deleted Itens for Days" & vbTab & "Issue Warning (KB)" & vbTab & "Prohibit Send (KB)" & vbTab & "Prohibit Send Receive (KB)")
						TextFile.WriteLine (SGPath & vbTab & CDOMailboxDB.Name & vbTab & CDOMailboxDB.DaysBeforeDeletedMailboxCleanup & vbTab & CDOMailboxDB.DaysBeforeGarbageCollection & vbTab & CDOMailboxDB.StoreQuota  & vbTab & CDOMailboxDB.OverQuotaLimit & vbTab & CDOMailboxDB.HardLimit )
					Next
					
					PFStores=CDOSG.PublicStoreDBs
					For j=0 To UBound(PFStores)
						CDOPublicDB.DataSource.open "LDAP://" & PFStores(j)	
						TextFile.WriteLine ("Storage Group" & vbTab & "Public Database Name" & vbTab & "Keep Deleted Items for Days" & vbTab & "Age Limits for Folders in Days" & vbTab & "Issue Warning (KB)" & vbTab & "Prohibit Post (KB)" & vbTab & "Maximum Item Size (KB)")
						TextFile.WriteLine (SGPath & vbTab & CDOPublicDB.Name & vbTab & CDOPublicDB.DaysBeforeGarbageCollection & vbTab & CDOPublicDB.DaysBeforeItemExpiration & vbTab & CDOPublicDB.StoreQuota  & vbTab & CDOPublicDB.HardLimit & vbTab & CDOPublicDB.ItemSizeLimit)
					Next
				Else
					TextFile.WriteLine ("Recovery Storage Group")
				End If
			Next
		End If
		
		Err.Clear
		ServerFQDN = ""
		ExchServerRS.MoveNext
	Loop

	ExchServerRS.close
	Set ExchServerRS = Nothing
	Set ADRootDSE = Nothing
	TextFile.Close
	Answer = MsgBox ("Finalizado execução do Script",0,"Databases Information")
Else
	Answer = MsgBox ("Não encontrado servidores Ms Exchange Server no Active Directory",0,"Databases Information")
End If

WScript.Quit
