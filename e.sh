#!/bin/bash

# Exit on any error
set -e

# Get version from project.json
VERSION=$(grep '"version"' ../project.json | sed 's/.*"version": "\([^"]*\)".*/\1/')

echo "📦 Packaging jmakepp version $VERSION"

# --- Create .deb package ---
echo "🔨 Creating .deb package..."
rm -rf deb-package
mkdir -p deb-package/DEBIAN deb-package/usr/bin

# Copy correct binary
if [[ ! -f ../bin/jmakepp ]]; then
    echo "❌ Error: ../bin/jmakepp not found. Please build it first."
    exit 1
fi
cp ../bin/jmakepp deb-package/usr/bin/jmakepp
chmod 755 deb-package/usr/bin/jmakepp

# Fix DEBIAN directory permissions (must be between 0755–0775)
chmod 755 deb-package/DEBIAN

# Ask if user wants git and g++ as dependencies
read -p "Include git as dependency? (y/N): " INCLUDE_GIT
read -p "Include g++ as dependency? (y/N): " INCLUDE_GPP

DEPS=""
[[ "$INCLUDE_GIT" =~ ^[Yy]$ ]] && DEPS="git"
[[ "$INCLUDE_GPP" =~ ^[Yy]$ ]] && DEPS="$DEPS, g++"
DEPS=${DEPS#, }  # remove leading comma if needed

# Create control file
cat > deb-package/DEBIAN/control << EOF
Package: jmakepp
Version: $VERSION
Architecture: amd64
Maintainer: replit-user
Description: Simple C++ Build Tool
Depends: ${DEPS:-g++}
EOF

# Build .deb
dpkg-deb --build deb-package "jmakepp_${VERSION}_amd64.deb"
rm -rf deb-package


# --- Create .msi package ---
echo "🔨 Creating .msi package..."

# Check for WiX toolset (wixl)
if ! command -v wixl &> /dev/null; then
    echo "❌ Error: 'wixl' not found. Please install it via:"
    echo "   sudo apt install msitools"
    exit 1
fi

# Ask for install path
read -p "Enter install folder name (default 'jmakepp'): " INSTALL_NAME
INSTALL_NAME=${INSTALL_NAME:-jmakepp}

# Create staging directory for MSI
rm -rf msi-root
mkdir -p msi-root

# Copy Windows binary
if [[ ! -f ../bin/jmakepp.exe ]]; then
    echo "❌ Error: ../bin/jmakepp.exe not found. Please build it first."
    exit 1
fi
cp ../bin/jmakepp.exe msi-root/

# Ask if user wants git and g++ installed
read -p "Add option to install git and g++ during MSI installation? (y/N): " INSTALL_DEPS
INSTALL_DEPS_FLAG=""
if [[ "$INSTALL_DEPS" =~ ^[Yy]$ ]]; then
    INSTALL_DEPS_FLAG="YES"
fi

# Create WiX XML definition
cat > jmakepp.wxs << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product
      Id="*"
      Name="jmakepp"
      Language="1033"
      Version="$VERSION"
      Manufacturer="replit-user"
      UpgradeCode="6d7d8c9f-1234-4567-89ab-123456789abc">

    <Package InstallerVersion="500" Compressed="yes" InstallScope="perMachine" />
    <MajorUpgrade AllowDowngrades="no" DowngradeErrorMessage="A newer version of jmakepp is already installed." />
    <Media Id="1" Cabinet="product.cab" EmbedCab="yes" />

    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder">
        <Directory Id="INSTALLFOLDER" Name="$INSTALL_NAME">
          <Component Id="MainExecutable" Guid="12345678-90ab-cdef-1234-567890abcdef">
            <File Id="jmakeppExe" Source="msi-root/jmakepp.exe" KeyPath="yes" />
          </Component>
        </Directory>
      </Directory>
    </Directory>

    <Feature Id="DefaultFeature" Level="1">
      <ComponentRef Id="MainExecutable" />
    </Feature>

    <!-- Optional custom actions for installing git and g++ -->
    $(if [ "$INSTALL_DEPS_FLAG" = "YES" ]; then
        echo "<CustomAction Id=\"InstallDeps\" BinaryKey=\"WixCA\" DllEntry=\"CAQuietExec\" Execute=\"deferred\" Return=\"check\" Impersonate=\"no\""
        echo "    ExeCommand=\"cmd /c choco install git -y && choco install mingw -y\" />"
        echo "<InstallExecuteSequence>"
        echo "  <Custom Action=\"InstallDeps\" After=\"InstallFiles\">NOT Installed</Custom>"
        echo "</InstallExecuteSequence>"
    fi)
  </Product>
</Wix>
EOF

# Build MSI
wixl -o "jmakepp_${VERSION}_amd64.msi" jmakepp.wxs

# Cleanup
rm -rf msi-root jmakepp.wxs

echo "✅ Packages created successfully:"
echo "  - jmakepp_${VERSION}_amd64.deb"
echo "  - jmakepp_${VERSION}_amd64.msi"
