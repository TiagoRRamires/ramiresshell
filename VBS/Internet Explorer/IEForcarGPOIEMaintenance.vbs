

'------------------------------------------------------ Sobre ------------------------------------------------------
'Conhe�a nosso projeto em www.ramiresshell.com.br
'
'Descri��o:
'Altera a chave de registro que for�a a atualiza��o da Policy Internet Explorer Maintenance em todos os logons do usu�rio no computador.
'Util para garantir que todas as altera��es de GPO em Internet Explorer Maintenance sejam sempre aplicadas ap�s o logon do usu�rio.
'--------------------------------------------------------------------------------------------------------------------


Set WindowsReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
WindowsReg.SetDWORDValue &H80000002, "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions\{A2E30F80-D7DE-11D2-BBDE-00C04F86AE3B}", "NoGPOListChanges", 0
WScript.Quit
