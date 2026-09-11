#Requires -Version 7.2
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path)

$ErrorActionPreference = 'Stop'
$file = Get-Item -LiteralPath $Path -ErrorAction Stop
if ($file -isnot [IO.FileInfo] -or $file.Length -gt 8MB) { throw 'Expected an XML file no larger than 8 MiB.' }
$settings = [Xml.XmlReaderSettings]::new()
$settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
$settings.XmlResolver = $null
$settings.MaxCharactersInDocument = 8MB
$stream = [IO.File]::Open($file.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream))
    $stream.Position = 0
    $reader = [Xml.XmlReader]::Create($stream, $settings)
    $doc = [Xml.XmlDocument]::new()
    $doc.XmlResolver = $null
    try { $doc.Load($reader) } finally { $reader.Dispose() }
} finally { $stream.Dispose() }
$ns = [Xml.XmlNamespaceManager]::new($doc.NameTable)
$ns.AddNamespace('tm', 'http://schemas.microsoft.com/sdl/2014/12/ThreatModel')
$root = $doc.SelectSingleNode('/tm:ThreatModel', $ns)
if (-not $root -or $root.GetAttribute('FixtureProfile') -cne 'Synthetic-TM7-1' -or
    $root.SelectSingleNode('tm:Version', $ns).InnerText -cne '4.1') {
    throw 'Unsupported input: this reader accepts only the reduced Synthetic-TM7-1 fixture profile.'
}
function Read-Text($Node, [string]$XPath) {
    $found = $Node.SelectSingleNode($XPath, $ns)
    if ($null -eq $found) { return $null }
    $found.InnerText
}
function Read-Entries($Node) {
    if ($null -eq $Node) { throw 'Required dictionary collection missing.' }
    foreach ($entry in $Node.SelectNodes('*')) {
        $key = Read-Text $entry 'tm:Key'
        $value = $entry.SelectSingleNode('tm:Value', $ns)
        if ([string]::IsNullOrWhiteSpace($key) -or $null -eq $value) { throw 'Unsupported dictionary entry: expected Key and Value.' }
        [pscustomobject]@{ Key=$key; Value=$value }
    }
}
function Read-Properties($Node) {
    $map = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    $container = $Node.SelectSingleNode('tm:Properties', $ns)
    if ($null -eq $container) { throw 'Required Properties collection missing.' }
    foreach ($property in $container.SelectNodes('*')) {
        if ($property.LocalName -cne 'anyType' -or $property.NamespaceURI -cne $root.NamespaceURI) {
            throw 'Unsupported property collection shape.'
        }
        $key = Read-Text $property 'tm:Name'
        $value = $property.SelectSingleNode('tm:Value', $ns)
        if ([string]::IsNullOrWhiteSpace($key) -or $null -eq $value -or $value.SelectNodes('*').Count) {
            throw 'Unsupported property: expected a named scalar Value.'
        }
        if (-not $map.TryAdd($key, $value.InnerText)) { throw 'Duplicate property key.' }
    }
    return ,$map
}
function Property-Value($Map, [string]$Key) {
    if ($Map.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace($Map[$Key])) { return $Map[$Key] }
    return $null
}
$diagnostics = [Collections.Generic.List[object]]::new()
function Problem([string]$Kind, [string]$Owner, [string]$Reference) {
    $diagnostics.Add([pscustomobject]@{Kind=$Kind;Owner=$Owner;Reference=$Reference})
}
$diagrams = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
$surfaces = $root.SelectSingleNode('tm:DrawingSurfaceList', $ns)
if ($null -eq $surfaces) { throw 'DrawingSurfaceList is missing.' }
foreach ($surface in $surfaces.SelectNodes('*')) {
    if ($surface.LocalName -cne 'DrawingSurfaceModel' -or $surface.NamespaceURI -cne $root.NamespaceURI) {
        throw 'Unsupported drawing surface collection shape.'
    }
    $id = Read-Text $surface 'tm:Guid'
    if ([string]::IsNullOrWhiteSpace($id) -or $diagrams.ContainsKey($id)) { throw 'Missing or duplicate diagram ID.' }
    $elements = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($entry in @(Read-Entries ($surface.SelectSingleNode('tm:Borders',$ns)))) {
        $props = Read-Properties $entry.Value
        $name = Property-Value $props 'Name'
        if (-not $name) { Problem 'MissingName' $id $entry.Key }
        if (-not $elements.TryAdd($entry.Key, [pscustomobject]@{Id=$entry.Key;Name=$name})) { throw 'Duplicate element key.' }
    }
    $flows = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($entry in @(Read-Entries ($surface.SelectSingleNode('tm:Lines',$ns)))) {
        $source = Read-Text $entry.Value 'tm:SourceGuid'
        $target = Read-Text $entry.Value 'tm:TargetGuid'
        foreach ($endpoint in @($source,$target)) {
            if (-not $endpoint -or -not $elements.ContainsKey($endpoint)) { Problem 'UnresolvedEndpoint' "$id/$($entry.Key)" $endpoint }
        }
        $props = Read-Properties $entry.Value
        if (-not $flows.TryAdd($entry.Key, [pscustomobject]@{Id=$entry.Key;Source=$source;Target=$target;Name=(Property-Value $props 'Name')})) { throw 'Duplicate flow key.' }
    }
    $diagrams.Add($id, [pscustomobject]@{Id=$id;Name=(Read-Text $surface 'tm:Header');Elements=@($elements.Values);Flows=@($flows.Values);FlowIndex=$flows})
}
$threats = [Collections.Generic.List[object]]::new()
$threatKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($entry in @(Read-Entries ($root.SelectSingleNode('tm:ThreatInstances',$ns)))) {
    if (-not $threatKeys.Add($entry.Key)) { throw 'Duplicate threat key.' }
    $props = Read-Properties $entry.Value
    $diagram = Property-Value $props 'DiagramId'
    $flow = Property-Value $props 'FlowId'
    $resolved = $diagram -and $diagrams.ContainsKey($diagram) -and $flow -and $diagrams[$diagram].FlowIndex.ContainsKey($flow)
    if (-not $resolved) { Problem 'UnresolvedThreatFlow' $entry.Key "$diagram/$flow" }
    $state = Property-Value $props 'State'
    if (-not $state) { $state='Unknown'; Problem 'MissingState' $entry.Key 'State' }
    $category = Property-Value $props 'Category'
    if (-not $category) { $category='Unknown'; Problem 'MissingCategory' $entry.Key 'Category' }
    $threats.Add([pscustomobject]@{Id=$entry.Key;Title=(Property-Value $props 'Title');Category=$category;State=$state;DiagramId=$diagram;FlowId=$flow;RelationshipResolved=[bool]$resolved})
}
[pscustomobject]@{
    SourceHash=$hash; Profile='Synthetic-TM7-1'; ModelVersion='4.1'
    Diagrams=@($diagrams.Values | Select-Object Id,Name,Elements,Flows)
    Threats=$threats.ToArray()
    CategoryCounts=@($threats | Group-Object Category | Select-Object Name,Count)
    StateCounts=@($threats | Group-Object State | Select-Object Name,Count)
    IntegrityProblems=$diagnostics.ToArray()
    Inferences=@()
    Recommendations=@()
}
