set windows-shell := ["pwsh", "-NoLogo", "-NoProfile", "-Command"]
set script-interpreter := ["pwsh", "-NoLogo", "-NoProfile", "-Command"]

JOB_API_PROJECT_ROOT := "JobApiLib"
JOB_API_PROJECT_PATH := JOB_API_PROJECT_ROOT + "/JobApiLib.csproj"
JOB_API_DLL := JOB_API_PROJECT_ROOT + "/bin/Release/netstandard2.0/JobApiLib.dll"
MEASURE_TIME_MOD_ROOT := "Measure-Time"
MEASURE_TIME_MOD_PSD1 := MEASURE_TIME_MOD_ROOT + "/Measure-Time.psd1"
MEASURE_TIME_MOD_PSM1 := MEASURE_TIME_MOD_ROOT + ".psm1"
MEASURE_TIME_MOD_DLL :=  JOB_API_PROJECT_ROOT + ".dll"
MEASURE_TIME_MOD_VERSION := "1.0.3"

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
[windows]
create-module: build-release
    @cp {{ JOB_API_DLL }} "{{ MEASURE_TIME_MOD_ROOT }}/{{ MEASURE_TIME_MOD_DLL }}"

    @New-ModuleManifest -Verbose \
                        -Path "{{ MEASURE_TIME_MOD_PSD1 }}" \
                        -RootModule "{{ MEASURE_TIME_MOD_PSM1 }}" \
                        -NestedModules "{{ MEASURE_TIME_MOD_DLL }}" \
                        -ModuleVersion {{ MEASURE_TIME_MOD_VERSION }} \
                        -Author "AbdElMoniem ElHifnawy" \
                        -LicenseUri "https://raw.githubusercontent.com/abdalmoniem/Measure-Time/refs/heads/main/LICENSE.md" \
                        -Description "A PowerShell module that exposes Measure-Time command to measure command execution time and cpu usage"

[arg('whatif', help='test if publish will succeed')]
[doc('Publish Measure-Time to PSGallery')]
[group('build')]
[script]
[windows]
publish-module whatif: create-module
    if ({{ whatif }}) {
        Publish-Module -Verbose -WhatIf -Path {{ MEASURE_TIME_MOD_ROOT }} -NuGetApiKey "$(cat -tail 1 nuget_api_key.txt)"
    }
    else {
        Publish-Module -Verbose -Path {{ MEASURE_TIME_MOD_ROOT }} -NuGetApiKey "$(cat -tail 1 nuget_api_key.txt)"
    }

[arg('tag', help='the tag to show changelog for')]
[doc('shows changelog for tag')]
[group('changelog')]
tag_changelog tag:
    @git-cliff --verbose --offline --body="$(cat -raw cliff_body.tera)" \
               "$(git describe --tags --abbrev=0 {{ tag }}^ 2>/dev/null || git rev-list --max-parents=0 HEAD)..{{ tag }}"

[doc('shows changelog for all tagged commits')]
[group('changelog')]
tags_changelog:
    @git-cliff --verbose --offline --body="$(cat -raw cliff_body.tera)" --tag "$(git describe --tags --abbrev=0)"

[doc('shows changelog for untagged commits')]
[group('changelog')]
unreleased_changelog:
    @git-cliff --verbose --offline --body="$(cat -raw cliff_body.tera)" "$(git describe --tags --abbrev=0)..HEAD"

[doc('shows changelog for all commits')]
[group('changelog')]
all_changelog:
    @git-cliff --verbose --offline --body="$(cat -raw cliff_body.tera)"

[doc('updates CHANGELOG.md with changelog from all tagged commits')]
[group('changelog')]
update_changelog:
    @git-cliff --verbose --offline --body="$(cat -raw cliff_body.tera)" --tag "$(git describe --tags --abbrev=0)"
    @git-cliff --verbose --offline --body="$(cat -raw cliff_body.tera)" --tag "$(git describe --tags --abbrev=0)" > CHANGELOG.md
    @echo ""
    @echo "changelog written to '$(Resolve-Path CHANGELOG.md)'!"
