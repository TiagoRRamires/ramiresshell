

<#
------------------ Sobre ------------------------------------------------------
Conheça nosso projeto em www.ramiresshell.com.br

Descrição:
    Este script copia todos os escopos criados em um servidor DHCP para outro servidor DHCP.
    No cliente WinRM que iniciou a execução do script é validado se o caminho de rede definido no parâmetro -DirBackup esta acessível. Este caminho é fundamental nos processos de export e import dos escopos.
    No servidor DHCP de origem definido no parâmetro -SourceServer, executa as seguintes ações:
        1) Exporta todos os escopos para um arquivo nomeado Backup.dat. O arquivo é armazenado no caminho definido pelo parâmetro -DirBackup. Apenas configurações são copiadas, leases existentes não são salvos no arquivo.
        2) Salva uma lista de todos os escopos existentes no servidor em um arquivo nomeado Escopos.txt aramazeando no caminho de rede definido pelo parametro -DirBackup.
        3) Durante o processo de export, o serviço DHCPServer pode ficar indisponível. O script verifica se o serviço parou e inicia novamente.
    No servidor DHCP de destino definido no parâmetro -DestServer executa as seguintes ações:
        1) Valida se o arquivo Backup.dat esta com no máximo 2 horas de modificação. Isto evita a importação de um arquivo de backup muito antigo.
        2) Importa todos os escopos contidos no arquivo valido Backup.dat.
        3) Desativa todos os escopos listados no arquivo Escopos.txt. Esta etapa é fundamental para evitar que o servidor DHCP de standby distribua o mesmo IP na rede que o servidor DHCP ativo.
    Registra todo processo descrito acima no arquivo de log criado pelo script nomeado "SyncDhcp-$SourceServer-to-$DestServer-<Dia da Semana>.log" armazenado no caminho definido no parametro -DirLog.
    Erros de execução e exceptions serão gravados no arquivo de log criado pelo script nomeado "Error-SyncDhcp-$SourceServer-to-$DestServer-<Dia da Semana>.log" armazenado no mesmo diretorio do scipt.

    Este script é útil para manter um servidor DHCP de standby/backup sincronizado com um outro servidor DHCP (como por exemplo um DHCP ativo em produção). Caso o servidor DHCP principal fique indisponível basta ativar os escopos do servidor de standby.
    Dicas de configuração dos servidores para uso do serviço WinRM podem ser encontradas no artigo: http://ramiresshell.com.br/Site/View/Dica.aspx?Id=201804271


Considerações:
    O usuário que executar este script deve possuir as seguintes permissões NTFS:
        Permissão de Modificação na pasta onde o script será armazenado para criação dos arquivos de log de erros e exceptions.
        Permissão de Modificação nas pastas definidas nos parametros  -DirLog e -DirBackup.
    O usuário para delegação definido no parâmetro -CredDomainUser deve ter permissões para criar sessão WinRM nos servidores definido nos parâmetros -SourceServer e -DestServer.


Descrição dos Parâmetros:
    -DirLog
        Campo Obrigatório. Tipo String. Informe uma pasta compartilhada na rede (Caminho UNC) que devera armazenar o arquivo de log que registra todas as ações executadas pelo script. Um caminho local impossibilita o registro de todas as ações executadas pelo script.
    -SourceServer
        Campo Obrigatório. Tipo String. Informe o nome do servidor DHCP (Cluster ou Standalone) que possui os escopos a serem copiados.
    -DestServer
        Campo Obrigatório. Tipo String. Informe o nome do servidor DHCP (Standalone) que recebera uma copia dos escopos copiados do servidor definido no parâmetro -SourceServer.
    -DirBackup
        Campo Obrigatório. Tipo String. Informe uma pasta compartilhada na rede (Caminho UNC) que devera armazenar o arquivo de backup e arquivo com lista de escopos do servidor definido no parâmetro -SourceServer. Este caminho atuara como uma ponte entre os servidores que exporta o escopo e o que importa o escopo.
    -CredDomainUser
        Campo Obrigatório, Tipo String. Informe domínio e usuário no formato SamAccountName. Esta conta executara o script remotamente nos servidores informados nos parâmetros -SourceServer e -DestServer. Deve ser usado o formato domínio\usuário.
    -CredPass
        Campo Obrigatório. Tipo String. Informe a senha do usuário definido no parâmetro CredDomainUser.


Exemplos:
    Este exemplo pode ser executado em schedule ou a partir do prompt de comandos de qualquer servidor (WinRM Client). Esta sintaxe realiza um backup (export) dos escopos do servidor SrvDhcpProd, armazenando os arquivos no caminho de rede \\SrvFs\InfraServices\DHCP. Na sequencia os escopos são importados para o servidor SrvDhcpStand. A conexão WinRM para os servidores SrvDhcpProd e SrvDhcpStand, utiliza a conta domínio\usuario1 com senha pass1. Um arquivo de log é gerado no caminho de rede \\SrvLog\script$\DHCP.
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file C:\Script1\BackupDHCP.ps1 -DirLog \\SrvLog\script$\DHCP -SourceServer SrvDhcpProd -DestServer SrvDhcpStand -DirBackup \\SrvFs\InfraServices\DHCP -CredDomainUser dominio\usuario1 -CredPass pass1

    Este exemplo possui a mesma sintxe do exemplo anterior, porem este é executado a partir da da console do Windows PowerShell.
    PS C:\Script1> .\BackupDHCP.ps1 -DirLog \\SrvLog\script$\DHCP -SourceServer SrvDhcpProd -DestServer SrvDhcpStand -DirBackup \\SrvFs\InfraServices\DHCP -CredDomainUser dominio\usuario1 -CredPass pass1
------------------------------------------------------------------------
#>




Param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DirLog,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceServer,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DestServer,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$DirBackup,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$CredDomainUser,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$CredPass
)




#--------------- CredSSP - Usuario e senha ------------------------------
$Pass = ConvertTo-SecureString -String $CredPass -AsPlainText -Force
$PassPort = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $CredDomainUser, $Pass
#---------------------------------------------------


$FileLog = $DirLog + "\SyncDhcp-$SourceServer-to-$DestServer-" + (Get-Date).DayOfWeek + ".log"
$BackupFile = "$DirBackup\$SourceServer\Backup.dat"


Set-Content -LiteralPath $FileLog -Value ("Inicio: " + [string](Get-Date -Format F) + "`r`n") -Force -Encoding Unicode


#Valida caminho para backup do DHCP
if ( -not(Test-Path -LiteralPath "$DirBackup\$SourceServer"))
{
    try
    {
        New-Item -Path "$DirBackup\$SourceServer" -ItemType Directory -ErrorAction Stop
    }
    catch
    {
        Add-Content -LiteralPath $FileLog -Value ("Erro: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   Erro ao criar diretório:  $DirBackup\$SourceServer  " + $Error[0].InvocationInfo + "`r`n" + $Error[0].Exception) -Force -Encoding Unicode
        Exit
    }
}





#------------ Inicio Export --------------------------
Invoke-Command -ComputerName $SourceServer -Authentication credssp -Credential $PassPort -ArgumentList $FileLog, $SourceServer, $BackupFile -ScriptBlock {
    #------- Parametros do Bloco --------
    $FileLogBlock = $args[0]
    $SourceServerBlock = $args[1]
    $BackupFileBlock = $args[2]
    #------------------------------------


    Function NetshExport()
    {
        $NetshResult = netsh dhcp server export $BackupFileBlock all
        If ($NetshResult -eq "Command completed successfully.")
        {
            Add-Content -LiteralPath $FileLogBlock -Value ("Info: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   Executado com sucesso ""netsh server export $BackupFileBlock all"" no servidor $SourceServerBlock") -Encoding Unicode
            $DhcpScope = netsh dhcp server show scope
            Set-Content -LiteralPath ($BackupFileBlock.Replace("Backup.dat", "Escopos.txt")) -Value ($DhcpScope) -Encoding Unicode
        }
        Else
        {
            Add-Content -LiteralPath $FileLogBlock -Value ("Erro: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   ""netsh server export $BackupFileBlock all"" retornou erro: " + [string]$NetshResult + " no servidor $SourceServerBlock") -Encoding Unicode
            Remove-Item -LiteralPath ($BackupFileBlock.Replace("Backup.dat", "Escopos.txt")) -Force
        }
    }



    Function DhcpStandalone()
    {
        If ((Get-Service -Name DHCPServer).Status -eq "Running")
        {
            NetshExport
            while ((Get-Service -Name DHCPServer).Status -ne "Running")
            {
                Start-Service -Name DHCPServer
                Start-Sleep 30
                Add-Content -LiteralPath $FileLogBlock -Value ("Info: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   DHCP Server Standalone com status: " + [string](Get-Service -Name DHCPServer).Status + " no servidor $SourceServerBlock") -Encoding Unicode
            }
        }
    }



    #Valida se servidor possui modulo de adm do cluster
    If ((Get-Module -ListAvailable | Where-Object -Property Name -EQ -Value FailoverClusters).Count -eq 1)
    {
        Import-Module FailoverClusters

        If ((Get-ClusterResource -Name "DHCP Server").OwnerGroup.Name -eq $SourceServerBlock)
        {
            #Backup do DHCP
            If ((Get-ClusterResource -Name "DHCP Server").State -eq "Online")
            {
                #Ajusta DHCP para não fazer failover
                $DhcpRes = Get-ClusterResource -Name "DHCP Server"
                $DhcpRes.RestartAction = 0

                NetshExport

                Start-Sleep 30
                $DhcpRes.RestartAction = 2
                Add-Content -LiteralPath $FileLogBlock -Value ("Info: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   Configurado ""Dhcp RestartAction"": " + [string]$DhcpRes.RestartAction + " no servidor $SourceServerBlock") -Encoding Unicode

                while ((Get-ClusterResource -Name "DHCP Server").State -ne "Online")
                {
                    Start-ClusterResource -Name "DHCP Server"
                    Start-Sleep 30
                    Add-Content -LiteralPath $FileLogBlock -Value ("Info: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   ClusterResource ""DHCP Server"" com  Status: " + [string](Get-ClusterResource -Name "DHCP Server").State + " no servidor $SourceServerBlock") -Encoding Unicode
                }
            }
            Else
            {
                Add-Content -LiteralPath $FileLogBlock -Value ("Erro: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   ClusterResource ""DHCP Server"" não esta ""Online"" em $SourceServerBlock. Backup não executado") -Encoding Unicode
            }
        }
        Else
        {
            DhcpStandalone
        }
    }
    Else
    {
        DhcpStandalone

    }
}
#------------ Fim Export --------------------------




#------------------- Import --------------------------
#Sem suporte para Cluster NO DESTINO

Invoke-Command -ComputerName $DestServer -Authentication credssp -Credential $PassPort -ArgumentList $FileLog, $BackupFile, $DestServer -ScriptBlock {
    #------- Parametros do Bloco --------
    $FileLogBlock = $args[0]
    $BackupFileBlock = $args[1]
    $DestServerBlock = $args[2]
    #------------------------------------

    Function PrefixInfoLog($CommandReturn)
    {
        if ($CommandReturn -like "*Command completed successfully.*")
        {
            $Prefix = "Info: "
        }
        else
        {
            $Prefix = "Erro: "
        }
        return $Prefix
    }



    if (Test-Path -LiteralPath $BackupFileBlock)
    {
        #Realiza import apenas para arquivos de backup gerado em ate 2 horas
        If ((Get-ChildItem $BackupFileBlock).LastWriteTime -lt (Get-Date).AddHours(-2))
        {
            Add-Content -LiteralPath $FileLogBlock -Value ("Erro: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   Arquivo: $BackupFileBlock com data de alteração: " + (Get-ChildItem $BackupFileBlock).LastWriteTime + " inferior a mais de 2 horas a data atual: " + (Get-Date -Format G)) -Encoding Unicode
        }
        Else
        {
            If ((Get-Service -Name DHCPServer).Status -eq "Running")
            {
                #------------ Exclui escopos atuais ---------------------------
                If (Test-Path -LiteralPath ($BackupFileBlock.Replace("Backup.dat", "Escopos.txt")))
                {
                    $DhcpScope = Get-Content -LiteralPath ($BackupFileBlock.Replace("Backup.dat", "Escopos.txt"))
                    For($I = 5; $I -le ([int]$DhcpScope.Length - 4); $I++)
                    {
                        $DhcpScopeNet = $DhcpScope[$I].substring(1,($DhcpScope[$I].indexof("-") - 2))
                        $DhcpScopeNetRemoveStatus = netsh dhcp server delete scope $DhcpScopeNet.trim() DHCPFULLFORCE
                        Add-Content -LiteralPath $FileLogBlock -Value ((PrefixInfoLog -CommandReturn $DhcpScopeNetRemoveStatus) + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   Removido Escopo: $DhcpScopeNet -->> $DhcpScopeNetRemoveStatus no servidor $DestServerBlock") -Encoding Unicode
                    }
                }
                #--------------------------------------------------------------

                $NetshResult = netsh dhcp server import $BackupFileBlock all
                #
                Add-Content -LiteralPath $FileLogBlock -Value ("Info: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   Restaurando backup: " + [string]$NetshResult + " no servidor $DestServerBlock") -Encoding Unicode
                Start-Sleep 5
            
                while ((Get-Service -Name DHCPServer).Status -ne "Running")
                {
                    Start-Service -Name DHCPServer
                    Start-Sleep 5
                    Add-Content -LiteralPath $FileLogBlock -Value ("Info: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   DHCP Server Standalone com status: " + [string](Get-Service -Name DHCPServer).Status + " no servidor $DestServerBlock") -Encoding Unicode
                }

                #Desativa escopo criado
                If (Test-Path -LiteralPath ($BackupFileBlock.Replace("Backup.dat", "Escopos.txt")))
                {
                    $DhcpScope = Get-Content -LiteralPath ($BackupFileBlock.Replace("Backup.dat", "Escopos.txt"))

                    For($I = 5; $I -le ([int]$DhcpScope.Length - 4); $I++)
                    {
                        $DhcpScopeNet = $DhcpScope[$I].substring(1,($DhcpScope[$I].indexof("-") - 2))
                        $DhcpScopeNetRemoveStatus = netsh dhcp server scope $DhcpScopeNet.trim() set state 0
                        Add-Content -LiteralPath $FileLogBlock -Value ((PrefixInfoLog -CommandReturn $DhcpScopeNetRemoveStatus) + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   Desativado Escopo: $DhcpScopeNet -->> $DhcpScopeNetRemoveStatus no servidor $DestServerBlock") -Encoding Unicode
                    }
                }

            }
            else
            {
                Add-Content -LiteralPath $FileLogBlock -Value ("Erro: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   DHCP Server Standalone com status: " + [string](Get-Service -Name DHCPServer).Status + " no servidor $DestServerBlock") -Encoding Unicode
            }
        }
    }
    Else
    {
        Add-Content -LiteralPath $FileLogBlock -Value ("Erro: " + (Get-Date).ToString("dd/MM/yyyy HH:mm:ss") + "   Arquivo de backup não encontrdo: $BackupFileBlock") -Encoding Unicode
    }
}
#---------------- Fim Import -----------------------




Add-Content -LiteralPath $FileLog -Value ("Script Finalizado " + [string](Get-Date)) -Encoding Unicode

#Loga exceptions, caso ocorra
Set-Content -Path (($MyInvocation.MyCommand.Path).SubString(0,($MyInvocation.MyCommand.Path).LastIndexOfAny("\")) + "\Error-SyncDhcp-$SourceServer-to-$DestServer-" + (Get-Date).DayOfWeek + ".log") -Value ($Error.InvocationInfo + "`r`n" + $Error.Exception ) -Force -Encoding Unicode

