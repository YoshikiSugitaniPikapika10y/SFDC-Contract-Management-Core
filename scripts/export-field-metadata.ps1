$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-PicklistValues($fieldNode) {
    $vals = @()
    foreach ($v in $fieldNode.SelectNodes('//*[local-name()="valueSetDefinition"]/*[local-name()="value"]')) {
        $fn = $v.SelectSingleNode('*[local-name()="fullName"]')
        if ($fn -and $fn.InnerText) { $vals += $fn.InnerText }
    }
    if ($vals.Count -eq 0) {
        $vsn = $fieldNode.SelectSingleNode('//*[local-name()="valueSetName"]')
        if ($vsn -and $vsn.InnerText) { return "(グローバル値セット: $($vsn.InnerText))" }
        return '-'
    }
    return ($vals -join ' / ')
}

function Get-DataType($fieldNode) {
    $type = $fieldNode.SelectSingleNode('*[local-name()="type"]').InnerText
    switch ($type) {
        'Lookup' { return "Lookup → $($fieldNode.SelectSingleNode('*[local-name()="referenceTo"]').InnerText)" }
        'MasterDetail' { return "MasterDetail → $($fieldNode.SelectSingleNode('*[local-name()="referenceTo"]').InnerText)" }
        'Summary' {
            $op = $fieldNode.SelectSingleNode('*[local-name()="summaryOperation"]').InnerText
            $sf = $fieldNode.SelectSingleNode('*[local-name()="summarizedField"]').InnerText
            return "Summary ($op of $sf)"
        }
        'Number' {
            $p = $fieldNode.SelectSingleNode('*[local-name()="precision"]')
            $s = $fieldNode.SelectSingleNode('*[local-name()="scale"]')
            $extra = @()
            if ($p) { $extra += "精度$($p.InnerText)" }
            if ($s) { $extra += "小数$($s.InnerText)" }
            if ($extra.Count -gt 0) { return "Number ($($extra -join ', '))" }
            return 'Number'
        }
        'Currency' {
            $p = $fieldNode.SelectSingleNode('*[local-name()="precision"]')
            $s = $fieldNode.SelectSingleNode('*[local-name()="scale"]')
            $extra = @()
            if ($p) { $extra += "精度$($p.InnerText)" }
            if ($s) { $extra += "小数$($s.InnerText)" }
            if ($extra.Count -gt 0) { return "Currency ($($extra -join ', '))" }
            return 'Currency'
        }
        'Text' {
            $len = $fieldNode.SelectSingleNode('*[local-name()="length"]')
            if ($len) { return "Text (最大$($len.InnerText)文字)" }
            return 'Text'
        }
        'LongTextArea' {
            $len = $fieldNode.SelectSingleNode('*[local-name()="length"]')
            if ($len) { return "LongTextArea (最大$($len.InnerText)文字)" }
            return 'LongTextArea'
        }
        default { return $type }
    }
}

function Get-RequiredFlag($fieldNode) {
    $type = $fieldNode.SelectSingleNode('*[local-name()="type"]').InnerText
    if ($type -eq 'MasterDetail') { return 'はい' }
    $req = $fieldNode.SelectSingleNode('*[local-name()="required"]')
    if ($req -and $req.InnerText -eq 'true') { return 'はい' }
    return 'いいえ'
}

$objects = @(
    @{
        Label = '取引先'
        Api = 'Account'
        Path = $null
        StandardRows = @(
            @('取引先名', 'Name', 'Text', 'はい', '-')
            @('(標準項目)', 'Id', 'Id', 'はい', '-')
        )
    },
    @{
        Label = '商談'
        Api = 'Opportunity'
        Path = 'force-app/main/default/objects/Opportunity/fields'
        StandardRows = @(
            @('(標準項目)', 'Id', 'Id', 'はい', '-')
            @('(標準項目)', 'Name', 'Text', 'はい', '-')
            @('(標準項目)', 'AccountId', 'Lookup → Account', 'いいえ', '-')
        )
    },
    @{
        Label = '商品'
        Api = 'Product2'
        Path = 'force-app/main/default/objects/Product2/fields'
        StandardRows = @(
            @('(標準項目)', 'Id', 'Id', 'はい', '-')
            @('(標準項目)', 'Name', 'Text', 'はい', '-')
            @('(標準項目)', 'UnitPrice', 'Currency', 'いいえ', '-')
        )
    },
    @{ Label = '請求アカウント'; Api = 'BillingAccount__c'; Path = 'force-app/main/default/objects/BillingAccount__c/fields'; StandardRows = @() },
    @{ Label = '契約サービス'; Api = 'ContractService__c'; Path = 'force-app/main/default/objects/ContractService__c/fields'; StandardRows = @() },
    @{ Label = '契約履歴'; Api = 'ContractHistory__c'; Path = 'force-app/main/default/objects/ContractHistory__c/fields'; StandardRows = @() },
    @{ Label = '契約商品'; Api = 'ContractProduct__c'; Path = 'force-app/main/default/objects/ContractProduct__c/fields'; StandardRows = @() },
    @{ Label = '請求商品'; Api = 'InvoiceProduct__c'; Path = 'force-app/main/default/objects/InvoiceProduct__c/fields'; StandardRows = @() },
    @{ Label = '見積備考マスタ'; Api = 'EstimateNoteMaster__c'; Path = 'force-app/main/default/objects/EstimateNoteMaster__c/fields'; StandardRows = @() },
    @{ Label = '見積備考文マスタ'; Api = 'EstimateRemarkMaster__c'; Path = 'force-app/main/default/objects/EstimateRemarkMaster__c/fields'; StandardRows = @() }
)

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add('見積作成 LWC / Apex 必要オブジェクト・項目一覧')
[void]$lines.Add('（EstimateCreateController, estimateCreateWizard 他 関連 Apex / Trigger / LWC から抽出）')
[void]$lines.Add('')

foreach ($obj in $objects) {
    [void]$lines.Add('=' * 100)
    [void]$lines.Add("【$($obj.Label)】 オブジェクトAPI名: $($obj.Api)")

    $objMeta = Join-Path (Get-Location) "force-app/main/default/objects/$($obj.Api)/$($obj.Api).object-meta.xml"
    if (Test-Path $objMeta) {
        [xml]$ox = Get-Content $objMeta -Encoding UTF8
        $root = $ox.DocumentElement
        $nl = $root.SelectSingleNode('*[local-name()="nameField"]/*[local-name()="label"]')
        $nt = $root.SelectSingleNode('*[local-name()="nameField"]/*[local-name()="type"]')
        $sm = $root.SelectSingleNode('*[local-name()="sharingModel"]')
        if ($nl) {
            [void]$lines.Add("  名前項目: $($nl.InnerText) / タイプ: $($nt.InnerText) / 共有: $($sm.InnerText)")
        }
    }

    [void]$lines.Add('-' * 100)
    [void]$lines.Add("項目名`tAPI名`tデータ型`t必須`t選択リスト値")
    [void]$lines.Add('-' * 100)

    foreach ($row in $obj.StandardRows) {
        [void]$lines.Add(($row -join "`t"))
    }

    if ($obj.Path -and (Test-Path $obj.Path)) {
        Get-ChildItem $obj.Path -Filter '*.field-meta.xml' | Sort-Object Name | ForEach-Object {
            [xml]$doc = Get-Content $_.FullName -Encoding UTF8
            $field = $doc.DocumentElement
            $label = $field.SelectSingleNode('*[local-name()="label"]').InnerText
            $apiName = $field.SelectSingleNode('*[local-name()="fullName"]').InnerText
            $dataType = Get-DataType $field
            $req = Get-RequiredFlag $field
            $typeNode = $field.SelectSingleNode('*[local-name()="type"]').InnerText
            $pick = if ($typeNode -in @('Picklist', 'MultiselectPicklist')) { Get-PicklistValues $field } else { '-' }
            [void]$lines.Add("$label`t$apiName`t$dataType`t$req`t$pick")
        }
    }

    [void]$lines.Add('')
}

$outPath = Join-Path (Get-Location) 'docs/lwc-apex-required-fields.txt'
New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null
[System.IO.File]::WriteAllText($outPath, ($lines -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
Write-Output $outPath
