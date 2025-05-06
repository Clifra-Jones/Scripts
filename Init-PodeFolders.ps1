$Folders = @(
    "downloads"
    "error"
    "functions"
    "logs"
    "pages"
    "pode_modules"
    "ps_modules"
    "public"
    "scripts"
)

$FOlders | ForEach-Object {
    New-Item -Path $_ -ItemType Directory
}
