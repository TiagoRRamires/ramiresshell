
<#
------------------ Sobre ------------------------------------------------------
Conheça nosso projeto em www.ramiresshell.com.br

Descrição:
    Este script alterar o valor de destino (Target) de arquivos de atalho (Shortcut) com extensão lnk.
    Pode alterar a string do valor de destino toda ou apenas uma parte da string informada.
    Útil para modificar uma grande quantia de arquivos de atalho quando houver modificação no destino como por exemplo migração de um servidor de arquivos.


Considerações:
    O usuário que executar este script deve possuir permissões NTFS de Modificação nos arquivos de atalho (lnk) que se deseja alterar.
    O parâmetro -NewFullTarget não deve ser passado junto com os parâmetros -NewParcialTarget e -OldParcialTarget.
    Ao utilizar o parâmetro -NewParcialTarget é obrigado utilizar o parâmetro -OldParcialTarget e vice-versa.


Descrição dos Parâmetros:
    -FileShortCut
        Campo Obrigatário. Tipo String. Informe o caminho do arquivo de atalho com extensão lnk que se deseja alterar o destino.
    -NewFullTarget
        Campo Opcional. Tipo String. Informe o novo caminho do destino que o atalho deve acessar.
    -NewParcialTarget
        Campo Opcional. Tipo String. Informe um novo valor de sub-string que devera substituir o valor informando no parâmetro -OldParcialTarget no destino do arquivo de atalho.
    -OldParcialTarget
        Campo Opcional. Tipo String. Informe o valor de sub-string existente no destino do arquivo de atalho a ser substituído pelo valor de sub-string informado no parâmetro -NewParcialTarget.


Exemplos:
    Este exemplo altera o destino do arquivo de atalho nomeado teste.lnk para o notepad.exe.
    PS > C:\Script1\AlterarAtalho-Shortcut.ps1' -FileShortCut C:\Arquivos\Teste.lnk -NewFullTarget "C:\Windows\System32\Notepad.exe"

    Usando o atalho teste.lnk alterado no exemplo anterior. Este exemplo ira alterar o caminho do destino de C:\Windows\System32\Notepad.exe para C:\WinNT\System32\Notepad.exe
    PS > C:\Script1\AlterarAtalho-Shortcut.ps1' -FileShortCut C:\Arquivos\Teste.lnk -NewParcialTarget "WinNT" -OldParcialTarget "Windows"

    Este exemplo alterar o destino de todos os arquivos de atalho que contem “Teste” no nome armazenados no diretório C:\Arquivos.
    Get-ChildItem -LiteralPath C:\Arquivos -File -Force | Where-Object -Property Name -Like -Value "Teste*" | ForEach { C:\Script1\AlterarAtalho-Shortcut.ps1 -NewFullTarget C:\Windows\System32\notepad.exe -FileShortCut $_.FullName }
------------------------------------------------------------------------
#>




Param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$FileShortCut,


    [ValidateNotNullOrEmpty()]
    [string]$NewFullTarget,


    [ValidateNotNullOrEmpty()]
    [string]$NewParcialTarget,


    [ValidateNotNullOrEmpty()]
    [string]$OldParcialTarget
)


If ($NewFullTarget.Length -eq 0 -and $NewParcialTarget.Length -eq 0 -and $OldParcialTarget.Length -eq 0)
{
    Write-Host "Informe o parametro NewFullTarget ou os parametros NewParcialTarget e OldParcialTarget" -ForegroundColor Red
    Exit
}
If ($NewFullTarget.Length -gt 0 -and ( $NewParcialTarget.Length -gt 0 -or $OldParcialTarget.Length -gt 0))
{
    Write-Host "Parametro NewFullTarget não pode ser usado com NewParcialTarget ou OldParcialTarget" -ForegroundColor Red
    Exit
}
If ($NewParcialTarget.Length -gt 0 -and $OldParcialTarget.Length -eq 0)
{
    Write-Host "Parametro NewParcialTarget necessita do parametro OldParcialTarget" -ForegroundColor Red
    Exit
}
If ($NewParcialTarget.Length -eq 0 -and $OldParcialTarget.Length -gt 0)
{
    Write-Host "Parametro OldParcialTarget necessita do parametro NewParcialTarget" -ForegroundColor Red
    Exit
}




$WsShell = New-Object -ComObject WScript.Shell


If (Test-Path -LiteralPath $FileShortCut)
{
    Try
    {
        $FileItem = Get-Item -LiteralPath $FileShortCut -Force
        $WsShortcut = $WsShell.CreateShortcut($FileItem.FullName)

        Write-Host "Arquivo de atalho: " $FileItem.FullName -ForegroundColor Green
        Write-Host "Destino Atual: " $WsShortcut.TargetPath


        If ($NewFullTarget.Length -eq 0)
        {
            $NewFullTarget = $WsShortcut.TargetPath.ToString().Replace($OldParcialTarget, $NewParcialTarget)
        }

        $WsShortcut.TargetPath = $NewFullTarget
        $WsShortcut.Save()
        Write-Host "Novo Destino: " $WsShortcut.TargetPath "`r`n"
    }
    Catch
    {
        Write-Host ($error[0].Exception.Message + "  Linha no Script: " + $error[0].InvocationInfo.ScriptLineNumber + "`r`n") -ForegroundColor Red
    }

}
Else
{
    Write-Host "Não encontrado arquivo: " $FileShortCut -ForegroundColor Yellow
}


