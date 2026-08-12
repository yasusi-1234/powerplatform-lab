#Requires -Version 5.1
<#
    簡易承認アプリ用 SharePoint リスト作成スクリプト (PnP.PowerShell)

    作成するリスト:
      - T_Request        : 申請本体
      - M_Approvers       : 承認者マスター
      - T_RequestHistory  : 承認履歴

    実行方法:
      1. PowerShellを開く(管理者権限は不要)
      2. このファイルのあるフォルダに移動するか、フルパスで実行
      3. .\Provision-SharePointLists.ps1 -SiteUrl "https://yasutake1.sharepoint.com/sites/soumu"
      4. ブラウザでサインイン画面が開くので、SharePointにアクセスできるアカウントでログインする

    既にリスト/列が存在する場合はスキップされるので、何度実行しても安全(冪等)。
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$SiteUrl = "https://yasutake1.sharepoint.com/sites/soumu"
)

$ErrorActionPreference = "Stop"

# --- 1. PnP.PowerShell モジュールの確認・インストール ---
if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Write-Host "PnP.PowerShell が見つからないためインストールします..." -ForegroundColor Yellow
    Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force -AllowClobber
}
else {
    Write-Host "PnP.PowerShell は既にインストール済みです。" -ForegroundColor Green
}

Import-Module PnP.PowerShell

# --- 2. サイトへ接続(対話ログイン) ---
Write-Host "`n$SiteUrl へ接続します。ブラウザでサインインしてください..." -ForegroundColor Cyan
Connect-PnPOnline -Url $SiteUrl -Interactive

# --- ヘルパー: リストが無ければ作成 ---
function Ensure-List {
    param([string]$Title)

    $list = Get-PnPList -Identity $Title -ErrorAction SilentlyContinue
    if ($null -eq $list) {
        Write-Host "リスト [$Title] を作成します..." -ForegroundColor Cyan
        New-PnPList -Title $Title -Template GenericList | Out-Null
    }
    else {
        Write-Host "リスト [$Title] は既に存在します。スキップします。" -ForegroundColor Yellow
    }
}

# --- ヘルパー: 列が無ければ追加 ---
function Ensure-Field {
    param(
        [string]$ListTitle,
        [string]$InternalName,
        [string]$DisplayName,
        [string]$Type,
        [string[]]$Choices = $null,
        [string]$DefaultValue = $null,
        [bool]$Required = $false
    )

    $existing = Get-PnPField -List $ListTitle -Identity $InternalName -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        Write-Host "  列 [$InternalName] は既に存在します。スキップします。" -ForegroundColor Yellow
        return
    }

    Write-Host "  列 [$InternalName] ($Type) を追加します..." -ForegroundColor Cyan

    $params = @{
        List         = $ListTitle
        InternalName = $InternalName
        DisplayName  = $DisplayName
        Type         = $Type
        Required     = $Required
        AddToDefaultView = $true
    }
    if ($Choices) { $params.Choices = $Choices }
    if ($DefaultValue) { $params.DefaultValue = $DefaultValue }

    Add-PnPField @params | Out-Null
}

# ============================================================
# T_Request (申請本体)
# ============================================================
Ensure-List -Title "T_Request"

# 標準の Title 列の表示名を「タイトル」に変更
Set-PnPField -List "T_Request" -Identity "Title" -Values @{ Title = "タイトル" } | Out-Null

Ensure-Field -ListTitle "T_Request" -InternalName "RequestBody" -DisplayName "申請内容" -Type Note -Required $true
Ensure-Field -ListTitle "T_Request" -InternalName "Remarks" -DisplayName "備考" -Type Note
Ensure-Field -ListTitle "T_Request" -InternalName "Status" -DisplayName "ステータス" -Type Choice `
    -Choices @("未申請", "申請中", "承認", "差戻し") -DefaultValue "未申請" -Required $true
Ensure-Field -ListTitle "T_Request" -InternalName "Applicant" -DisplayName "申請者" -Type User -Required $true
Ensure-Field -ListTitle "T_Request" -InternalName "RequestDate" -DisplayName "申請日" -Type DateTime
Ensure-Field -ListTitle "T_Request" -InternalName "UpdateDate" -DisplayName "更新日" -Type DateTime
Ensure-Field -ListTitle "T_Request" -InternalName "ApprovalComment" -DisplayName "承認コメント" -Type Note

# ============================================================
# M_Approvers (承認者マスター)
# ============================================================
Ensure-List -Title "M_Approvers"

Ensure-Field -ListTitle "M_Approvers" -InternalName "ApproverUser" -DisplayName "承認者" -Type User -Required $true
Ensure-Field -ListTitle "M_Approvers" -InternalName "IsActive" -DisplayName "有効" -Type Boolean -DefaultValue "1"

# ============================================================
# T_RequestHistory (承認履歴)
# ============================================================
Ensure-List -Title "T_RequestHistory"

Ensure-Field -ListTitle "T_RequestHistory" -InternalName "RequestID" -DisplayName "申請ID" -Type Number -Required $true
Ensure-Field -ListTitle "T_RequestHistory" -InternalName "ActionUser" -DisplayName "操作者" -Type User -Required $true
Ensure-Field -ListTitle "T_RequestHistory" -InternalName "ActionType" -DisplayName "操作種別" -Type Choice `
    -Choices @("一時保存", "申請", "承認", "差戻し", "取消") -Required $true
Ensure-Field -ListTitle "T_RequestHistory" -InternalName "Comment" -DisplayName "コメント" -Type Note
Ensure-Field -ListTitle "T_RequestHistory" -InternalName "ActionDate" -DisplayName "操作日時" -Type DateTime -Required $true

Write-Host "`n完了しました。SharePointサイトでリストを確認してください: $SiteUrl" -ForegroundColor Green
