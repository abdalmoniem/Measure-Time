set windows-shell := ["pwsh", "-NoLogo", "-NoProfile", "-Command"]
set script-interpreter := ["pwsh", "-NoLogo", "-NoProfile", "-Command"]

JOB_API_PROJECT_ROOT := "JobApiLib"
JOB_API_PROJECT_PATH := JOB_API_PROJECT_ROOT + "/JobApiLib.csproj"
JOB_API_DLL := JOB_API_PROJECT_ROOT + "/bin/Release/netstandard2.0/JobApiLib.dll"
MEASURE_TIME_MOD_ROOT := "Measure-Time"
MEASURE_TIME_MOD_PSD1 := MEASURE_TIME_MOD_ROOT + "/Measure-Time.psd1"
MEASURE_TIME_MOD_PSM1 := MEASURE_TIME_MOD_ROOT + ".psm1"
MEASURE_TIME_MOD_DLL := JOB_API_PROJECT_ROOT + ".dll"

alias f := fmt
alias b := build
alias br := build-release
alias ba := build-all
alias c := clean
alias cr := clean-release
alias ca := clean-all
alias cm := create-module
alias pm := publish-module

[doc('List available recipes')]
default:
    @just --list --unsorted

[doc('Format code with dotnet format')]
[group('lint')]
fmt:
    @dotnet format {{ JOB_API_PROJECT_PATH }} --verbosity diagnostic

[doc('Clean the debug build directory')]
[group('build')]
clean:
    @dotnet clean {{ JOB_API_PROJECT_PATH }} --verbosity diagnostic

[doc('Clean the release build directory')]
[group('build')]
clean-release:
    @dotnet clean {{ JOB_API_PROJECT_PATH }} --verbosity diagnostic --configuration Release

[doc('Clean all build directories')]
[group('build')]
clean-all: clean clean-release

[doc('Build the debug DLL')]
[group('build')]
build: fmt
    @dotnet build {{ JOB_API_PROJECT_PATH }} --verbosity diagnostic

[doc('Build the release DLL')]
[group('build')]
build-release: fmt
    @dotnet build {{ JOB_API_PROJECT_PATH }} --verbosity diagnostic --configuration Release

[doc('Build the debug and release DLLs')]
[group('build')]
build-all: build build-release

[doc('Create Measure-Time PowerShell Module')]
[group('build')]
[script]
[windows]
create-module: build-release
    $MEASURE_TIME_MOD_VERSION = $(just --quiet get_version)
    Copy-Item -Path {{ JOB_API_DLL }} -Destination "{{ MEASURE_TIME_MOD_ROOT }}/{{ MEASURE_TIME_MOD_DLL }}"

    New-ModuleManifest -Verbose `
                       -Author "AbdElMoniem ElHifnawy" `
                       -Path "{{ MEASURE_TIME_MOD_PSD1 }}" `
                       -ModuleVersion $MEASURE_TIME_MOD_VERSION `
                       -RootModule "{{ MEASURE_TIME_MOD_PSM1 }}" `
                       -PowerShellVersion ([version]::new("5.1")) `
                       -NestedModules "{{ MEASURE_TIME_MOD_DLL }}" `
                       -ReleaseNotes 'https://github.com/abdalmoniem/Measure-Time/blob/main/CHANGELOG.md' `
                       -LicenseUri "https://raw.githubusercontent.com/abdalmoniem/Measure-Time/refs/heads/main/LICENSE.md" `
                       -IconUri "https://raw.githubusercontent.com/abdalmoniem/Measure-Time/refs/heads/main/assets/icon.png" `
                       -Description "A PowerShell module that exposes Measure-Time command to measure command execution time and cpu usage"

[doc('Verify Measure-Time before publishing to PSGallery')]
[group('build')]
[windows]
verify-module: create-module
    @Publish-Module -Verbose -WhatIf -Path {{ MEASURE_TIME_MOD_ROOT }} -NuGetApiKey "$(Get-Content -Tail 1 nuget_api_key.txt)"

[doc('Publish Measure-Time to PSGallery')]
[group('build')]
[windows]
publish-module: create-module
    @Publish-Module -Verbose -Path {{ MEASURE_TIME_MOD_ROOT }} -NuGetApiKey "$(Get-Content -Tail 1 nuget_api_key.txt)"

[arg('tag', help='the tag to show changelog for')]
[doc('shows changelog for tag')]
[group('changelog')]
tag_changelog tag:
    @git-cliff --verbose --offline --body="$(Get-Content -Raw cliff_body.tera)" \
               "$(git describe --tags --abbrev=0 {{ tag }}^ 2>/dev/null || git rev-list --max-parents=0 HEAD)..{{ tag }}"

[doc('shows changelog for all tagged commits')]
[group('changelog')]
tags_changelog:
    @git-cliff --verbose --offline --body="$(Get-Content -Raw cliff_body.tera)"

[doc('shows changelog for untagged commits')]
[group('changelog')]
unreleased_changelog:
    @git-cliff --verbose --offline --body="$(Get-Content -Raw cliff_body.tera)" "$(git describe --tags --abbrev=0)..HEAD"

[doc('shows changelog for all commits')]
[group('changelog')]
all_changelog:
    @git-cliff --verbose --offline --body="$(Get-Content -Raw cliff_body.tera)"

[doc('updates CHANGELOG.md with changelog from all tagged commits')]
[group('changelog')]
update_changelog:
    @ $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    @git-cliff --verbose --offline --body="$(Get-Content -Raw cliff_body.tera)" | Tee-Object CHANGELOG.md

    @Write-Host
    @Write-Host "changelog written to '$(Resolve-Path CHANGELOG.md)'!"

[private]
[script]
get_version:
    $csproj_content = $(Get-Content .\JobApiLib\JobApiLib.csproj)
    $version = ($csproj_content | Select-String "\bVersion\b")[0].Line.Trim()
    $version = $version -replace "[</>Version]", ""

    Write-Output $version
