
'------------------------------------------------------ Sobre ------------------------------------------------------
'Conhe�a nosso projeto em www.ramiresshell.com.br
'
'Descri��o:
'Configura um endere�o ip e porta tcp de proxy no navegador e define as exce��es de endere�os que n�o devem ser encaminhadas do desktop para o servidor de proxy.
'Esta configura��o s� � poss�vel por perfil de usu�rio.
'Util para configura��o automatizada de estacoes de usuario em relacao ao enderecamento de proxy do IE
'O bloco de codigo pode ser adicionado ao script de logon ou ser executado via GPO, SCCM ou outra ferramenta de deploy que execute com as credenciais do usuario logado.
'--------------------------------------------------------------------------------------------------------------------


Set WinReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
WinReg.SetDWORDValue &H80000001, "Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyEnable", 1
WinReg.SetStringValue &H80000001, "Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyServer", "192.168.25.246:8080"
WinReg.SetStringValue &H80000001, "Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyOverride", "intranet.local;www.parceiro.local;filial.com.br;<local>"
WScript.Quit
