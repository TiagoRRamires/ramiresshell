

'------------------------------------------------------ Sobre ------------------------------------------------------
'Conhe�a nosso projeto em www.ramiresshell.com.br
'
'Descri��o:
'Este script habilita a op��o "Detectar automaticamente as configura��es" do Proxy do IE via WMI.
'Esta configura��o s� � poss�vel por perfil de usu�rio.
'Util para configura��o automatizada de estacoes de usuario em relacao a configura��o de detec��o de proxy do IE
'O bloco de codigo pode ser adicionado ao script de logon ou ser executado via GPO, SCCM ou outra ferramenta de deploy que execute com as credenciais do usuario logado.
'--------------------------------------------------------------------------------------------------------------------


Set WindowsWMI = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2\Applications\MicrosoftIE")
Set IESet = WindowsWMI.ExecQuery ("Select * from MicrosoftIE_ConnectionSettings")
For Each IESetLine in IESet
	Set IESetLine.AutoProxyDetectMode = enable
Next
