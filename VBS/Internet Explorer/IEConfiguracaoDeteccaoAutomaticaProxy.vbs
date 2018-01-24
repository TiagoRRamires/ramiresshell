

'------------------------------------------------------ Sobre ------------------------------------------------------
'Conheça nosso projeto em www.ramiresshell.com.br
'
'Descrição:
'Este script habilita a opção "Detectar automaticamente as configurações" do Proxy do IE via WMI.
'Esta configuração só é possível por perfil de usuário.
'Util para configuração automatizada de estacoes de usuario em relacao a configuração de detecção de proxy do IE
'O bloco de codigo pode ser adicionado ao script de logon ou ser executado via GPO, SCCM ou outra ferramenta de deploy que execute com as credenciais do usuario logado.
'--------------------------------------------------------------------------------------------------------------------


Set WindowsWMI = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2\Applications\MicrosoftIE")
Set IESet = WindowsWMI.ExecQuery ("Select * from MicrosoftIE_ConnectionSettings")
For Each IESetLine in IESet
	Set IESetLine.AutoProxyDetectMode = enable
Next
