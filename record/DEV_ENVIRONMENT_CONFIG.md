# Development Environment Configuration Record

**Date**: 2025-12-02
**Platform**: Windows 11
**Operator**: Development Team

---

## Summary

This document records the development environment configuration for the Platform project, including all installed tools, environment variables, and verification steps.

---

## Configured Tools

### 1. JDK 25

| Item | Value |
|------|-------|
| Version | JDK 25 |
| Installation Path | `C:\Program Files\Java\jdk-25` |
| Environment Variable | `JAVA_HOME=C:\Program Files\Java\jdk-25` |
| PATH Addition | `C:\Program Files\Java\jdk-25\bin` |

**Verification Command**:
```bash
java -version
javac -version
echo %JAVA_HOME%
```

### 2. Apache Maven 3.9.11

| Item | Value |
|------|-------|
| Version | 3.9.11 |
| Installation Path | `D:\Program Files\apache-maven-3.9.11` |
| Environment Variable | `MAVEN_HOME=D:\Program Files\apache-maven-3.9.11` |
| PATH Addition | `D:\Program Files\apache-maven-3.9.11\bin` |

**Verification Command**:
```bash
mvn -version
echo %MAVEN_HOME%
```

### 3. Python

| Item | Value |
|------|-------|
| Version | 3.x (installed via IntelliJ IDEA) |
| Package Manager | pip |

**Verification Command**:
```bash
python --version
pip --version
```

### 4. Node.js

| Item | Value |
|------|-------|
| Version | v24.11.1 |
| Installation Method | Executable installer (.exe) |
| Package Manager | npm 11.6.2 |

**Verification Command**:
```bash
node --version
npm --version
```

### 5. uv (Python Package Manager)

| Item | Value |
|------|-------|
| Version | 0.9.13 |
| Installation Method | winget |
| Includes | uv, uvx |

**Installation Command**:
```powershell
winget install --id=astral-sh.uv -e
```

**Verification Command**:
```bash
uv --version
uvx --version
```

---

## Environment Variables Configuration

### System Environment Variables (Machine Level)

The following environment variables were configured at the system level:

```powershell
# JAVA_HOME
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Java\jdk-25", [System.EnvironmentVariableTarget]::Machine)

# MAVEN_HOME
[System.Environment]::SetEnvironmentVariable("MAVEN_HOME", "D:\Program Files\apache-maven-3.9.11", [System.EnvironmentVariableTarget]::Machine)

# PATH additions
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
$newPath = $currentPath + ";C:\Program Files\Java\jdk-25\bin;D:\Program Files\apache-maven-3.9.11\bin"
[System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
```

### Configuration Steps

1. **Open PowerShell as Administrator**
2. **Set JAVA_HOME**:
   ```powershell
   [System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Java\jdk-25", [System.EnvironmentVariableTarget]::Machine)
   ```
3. **Set MAVEN_HOME**:
   ```powershell
   [System.Environment]::SetEnvironmentVariable("MAVEN_HOME", "D:\Program Files\apache-maven-3.9.11", [System.EnvironmentVariableTarget]::Machine)
   ```
4. **Update PATH**:
   ```powershell
   $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
   $newPath = $currentPath + ";C:\Program Files\Java\jdk-25\bin;D:\Program Files\apache-maven-3.9.11\bin"
   [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
   ```
5. **Restart terminal** to apply changes

---

## Full Verification Script

Save as `verify-dev-tools.ps1` and run:

```powershell
Write-Host "========================================" -ForegroundColor Green
Write-Host "Development Tools Verification" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Java
Write-Host "[Java]" -ForegroundColor Yellow
Write-Host "JAVA_HOME: $env:JAVA_HOME"
java -version 2>&1 | Select-Object -First 1
Write-Host ""

# Maven
Write-Host "[Maven]" -ForegroundColor Yellow
Write-Host "MAVEN_HOME: $env:MAVEN_HOME"
mvn -version 2>&1 | Select-Object -First 1
Write-Host ""

# Python
Write-Host "[Python]" -ForegroundColor Yellow
python --version
pip --version
Write-Host ""

# Node.js
Write-Host "[Node.js]" -ForegroundColor Yellow
node --version
npm --version
Write-Host ""

# uv
Write-Host "[uv/uvx]" -ForegroundColor Yellow
uv --version
uvx --version
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Verification Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
```

---

## Tool Versions Summary

| Tool | Version | Status |
|------|---------|--------|
| JDK | 25 | Configured |
| Maven | 3.9.11 | Configured |
| Python | 3.x | Installed |
| pip | (bundled) | Installed |
| Node.js | v24.11.1 | Installed |
| npm | 11.6.2 | Installed |
| uv | 0.9.13 | Installed |
| uvx | 0.9.13 | Installed |

---

## Notes

1. **Terminal Restart Required**: After configuring environment variables, you must restart your terminal (or IDE) for changes to take effect.

2. **Admin Rights Required**: Setting system environment variables requires Administrator privileges.

3. **Path Order**: The order of directories in PATH matters. Java and Maven bins should be accessible without conflicts.

4. **uv/uvx**: These are modern, fast Python package management tools from Astral. They can replace pip for most use cases:
   - `uv pip install <package>` - Install packages
   - `uvx <tool>` - Run Python tools directly

---

## Troubleshooting

### Issue: Command not found after configuration

**Solution**:
1. Close and reopen terminal
2. If using IDE, restart the IDE
3. Verify PATH contains the correct directories:
   ```powershell
   $env:Path -split ';' | Where-Object { $_ -like '*java*' -or $_ -like '*maven*' }
   ```

### Issue: Wrong Java version

**Solution**:
```powershell
# Check which java is being used
where.exe java

# Should show:
# C:\Program Files\Java\jdk-25\bin\java.exe
```

### Issue: Maven cannot find Java

**Solution**: Ensure JAVA_HOME is set correctly without trailing backslash:
```powershell
echo $env:JAVA_HOME
# Should be: C:\Program Files\Java\jdk-25
```

---

**Document Created**: 2025-12-02
**Last Updated**: 2025-12-02
**Status**: Complete
