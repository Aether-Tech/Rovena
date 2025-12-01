#!/bin/bash

# Script para fazer release completa do Rovena
# Uso: ./make_release.sh [versão]
# Exemplo: ./make_release.sh 1.0.0

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "❌ Por favor, forneça uma versão"
    echo "Uso: ./make_release.sh 1.0.0"
    exit 1
fi

echo "🚀 Criando release v${VERSION}..."

# 1. Build
echo ""
echo "📦 Passo 1/6: Buildando o app..."
./build_and_run.sh

# 2. Criar DMG
echo ""
echo "📦 Passo 2/6: Criando DMG..."
DMG_NAME="Rovena-${VERSION}.dmg"

# Remover DMG existente se houver
if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
fi

# Criar DMG
hdiutil create -volname "Rovena" -srcfolder Rovena.app -ov -format UDZO "$DMG_NAME"

echo "✅ DMG criado: $DMG_NAME"

# 3. Criar tag
echo ""
echo "📦 Passo 3/6: Criando tag v${VERSION}..."
git tag "v${VERSION}"
echo "✅ Tag v${VERSION} criada localmente"

# 4. Instruções
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Próximos passos MANUAIS:"
echo ""
echo "1. Push da tag:"
echo "   git push origin v${VERSION}"
echo ""
echo "2. Criar release no GitHub:"
echo "   https://github.com/Aether-Tech/Rovena/releases/new"
echo "   - Selecione tag: v${VERSION}"
echo "   - Título: v${VERSION}"
echo "   - Faça upload do arquivo: $DMG_NAME"
echo "   - Clique em 'Publish release'"
echo ""
echo "3. Após criar a release, execute:"
echo "   ./generate_appcast.sh"
echo "   git add appcast.xml"
echo "   git commit -m 'Update appcast for v${VERSION}'"
echo "   git push origin main"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Release preparada! DMG: $DMG_NAME"

