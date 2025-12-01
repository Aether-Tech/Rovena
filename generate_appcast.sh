#!/bin/bash

# Script para gerar appcast.xml a partir de GitHub Releases
# Uso: ./generate_appcast.sh

set -e

# Configurações
GITHUB_REPO="Aether-Tech/Rovena"
APP_NAME="Rovena"
BUNDLE_ID="com.rovena.app"
APPCAST_FILE="appcast.xml"

echo "🔍 Buscando releases do GitHub..."

# Buscar última release usando GitHub API
LATEST_RELEASE=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")

if [ -z "$LATEST_RELEASE" ] || [ "$LATEST_RELEASE" == "null" ]; then
    echo "❌ Nenhuma release encontrada no GitHub"
    exit 1
fi

# Extrair informações da release
VERSION=$(echo "$LATEST_RELEASE" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
RELEASE_URL=$(echo "$LATEST_RELEASE" | grep -o '"html_url": "[^"]*' | cut -d'"' -f4)
PUBLISHED_DATE=$(echo "$LATEST_RELEASE" | grep -o '"published_at": "[^"]*' | cut -d'"' -f4)

# Buscar assets (DMG ou ZIP)
ASSETS=$(echo "$LATEST_RELEASE" | grep -o '"browser_download_url": "[^"]*' | cut -d'"' -f4)
DOWNLOAD_URL=""
SIGNATURE=""

for asset in $ASSETS; do
    if [[ "$asset" == *.dmg ]] || [[ "$asset" == *.zip ]]; then
        DOWNLOAD_URL="$asset"
        break
    fi
done

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Nenhum arquivo DMG ou ZIP encontrado na release"
    exit 1
fi

# Calcular tamanho do arquivo
FILE_SIZE=$(curl -sI "$DOWNLOAD_URL" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')

# Gerar appcast.xml
cat > "$APPCAST_FILE" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>${APP_NAME} Updates</title>
        <link>https://github.com/${GITHUB_REPO}/releases</link>
        <description>Most recent updates to ${APP_NAME}</description>
        <language>en</language>
        
        <item>
            <title>Version ${VERSION}</title>
            <pubDate>$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$PUBLISHED_DATE" "+%a, %d %b %Y %H:%M:%S %z" 2>/dev/null || date -u -d "$PUBLISHED_DATE" "+%a, %d %b %Y %H:%M:%S %z" 2>/dev/null || date "+%a, %d %b %Y %H:%M:%S %z")</pubDate>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <sparkle:releaseNotesLink>${RELEASE_URL}</sparkle:releaseNotesLink>
            <enclosure 
                url="${DOWNLOAD_URL}"
                sparkle:version="${VERSION}"
                sparkle:shortVersionString="${VERSION}"
                length="${FILE_SIZE}"
                type="application/octet-stream"
                ${SIGNATURE:+sparkle:edSignature="$SIGNATURE"}
            />
        </item>
    </channel>
</rss>
EOF

echo "✅ appcast.xml gerado com sucesso!"
echo "📦 Versão: ${VERSION}"
echo "🔗 Download: ${DOWNLOAD_URL}"
echo ""
echo "⚠️  IMPORTANTE:"
echo "1. Faça upload do appcast.xml para a raiz do seu repositório"
echo "2. Configure a URL no UpdateService.swift:"
echo "   private let appcastURL = \"https://raw.githubusercontent.com/${GITHUB_REPO}/main/appcast.xml\""
echo "3. Para assinatura EdDSA, use: sparkle/bin/generate_keys e adicione a chave pública ao appcast"

