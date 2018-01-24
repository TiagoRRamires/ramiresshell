

'------------------------------------------------------ Sobre ------------------------------------------------------
'Conheça nosso projeto em www.ramiresshell.com.br
'
'Descrição:
'Altera a chave de registro que força a atualização da Policy Internet Explorer Maintenance em todos os logons do usuário no computador.
'Util para garantir que todas as alterações de GPO em Internet Explorer Maintenance sejam sempre aplicadas após o logon do usuário.
'--------------------------------------------------------------------------------------------------------------------


Set WindowsReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
WindowsReg.SetDWORDValue &H80000002, "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions\{A2E30F80-D7DE-11D2-BBDE-00C04F86AE3B}", "NoGPOListChanges", 0
WScript.Quit
