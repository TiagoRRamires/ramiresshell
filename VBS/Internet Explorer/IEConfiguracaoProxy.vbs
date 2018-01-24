
'------------------------------------------------------ Sobre ------------------------------------------------------
'Conheça nosso projeto em www.ramiresshell.com.br
'
'Descrição:
'Configura um endereço ip e porta tcp de proxy no navegador e define as exceções de endereços que não devem ser encaminhadas do desktop para o servidor de proxy.
'Esta configuração só é possível por perfil de usuário.
'Util para configuração automatizada de estacoes de usuario em relacao ao enderecamento de proxy do IE
'O bloco de codigo pode ser adicionado ao script de logon ou ser executado via GPO, SCCM ou outra ferramenta de deploy que execute com as credenciais do usuario logado.
'--------------------------------------------------------------------------------------------------------------------


Set WinReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
WinReg.SetDWORDValue &H80000001, "Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyEnable", 1
WinReg.SetStringValue &H80000001, "Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyServer", "192.168.25.246:8080"
WinReg.SetStringValue &H80000001, "Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyOverride", "intranet.local;www.parceiro.local;filial.com.br;<local>"
WScript.Quit
