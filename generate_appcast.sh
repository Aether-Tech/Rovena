#!/usr/bin/env bash
set -euo pipefail

# Script para gerar appcast.xml a partir do DMG gerado no workflow
# Uso local (opcional):
#   VERSION=1.0.0 APP_NAME=Rovena ./generate_appcast.sh
# No GitHub Actions, o VERSION já vem do passo "Set version from tag".

APP_NAME="${APP_NAME:-Rovena}"
VERSION="${VERSION:-0.0.0}"
REPO="${GITHUB_REPOSITORY:-Aether-Tech/Rovena}"
TAG_NAME="${GITHUB_REF_NAME:-v${VERSION}}"
APPCAST_FILE="appcast.xml"

echo "🔍 Gerando appcast para ${APP_NAME} versão ${VERSION} (tag ${TAG_NAME})..."

DMG_FILE="${APP_NAME}-${VERSION}.dmg"
if [[ ! -f "${DMG_FILE}" ]]; then
  echo "⚠️  DMG ${DMG_FILE} não encontrado, procurando qualquer ${APP_NAME}-*.dmg..."
  DMG_FILE=$(ls "${APP_NAME}-"*.dmg 2>/dev/null | head -n 1 || true)
fi

if [[ -z "${DMG_FILE:-}" || ! -f "${DMG_FILE}" ]]; then
  echo "❌ Nenhum DMG encontrado, appcast não será gerado."
  exit 0
fi

# Tamanho do arquivo em bytes (BSD stat – funciona no macOS runner)
FILE_SIZE=$(stat -f%z "${DMG_FILE}")

# Data no formato que o Sparkle espera (RFC 2822)
PUB_DATE=$(LC_ALL=C date -u +"%a, %d %b %Y %T %z")

# URL final que o asset terá depois que o softprops/action-gh-release subir o DMG
DMG_URL="https://github.com/${REPO}/releases/download/${TAG_NAME}/${DMG_FILE}"

echo "📦 DMG: ${DMG_FILE} (${FILE_SIZE} bytes)"
echo "🔗 URL prevista: ${DMG_URL}"

cat > "${APPCAST_FILE}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>${APP_NAME} Updates</title>
    <link>https://github.com/${REPO}/releases/latest</link>
    <description>Most recent updates to ${APP_NAME}</description>
    <language>en</language>

    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/${REPO}/releases/tag/${TAG_NAME}</sparkle:releaseNotesLink>
      <enclosure
        url="${DMG_URL}"
        sparkle:version="${VERSION}"
        sparkle:shortVersionString="${VERSION}"
        length="${FILE_SIZE}"
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "✅ ${APPCAST_FILE} gerado com sucesso para versão ${VERSION}."

