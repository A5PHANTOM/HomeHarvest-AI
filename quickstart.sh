#!/bin/bash
# Quick Start Script for AGRIPRO Marketplace Admin Panel

set -e

PROJECT_DIR="/Users/mac/Desktop/AGRIPRO"
cd "$PROJECT_DIR"

echo "🌱 AGRIPRO Marketplace Admin Panel - Quick Start"
echo "================================================"
echo ""

# Activate venv
echo "📦 Activating Python environment..."
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install -q streamlit requests 2>/dev/null || true

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start the system, run in THREE separate terminals:"
echo ""
echo "Terminal 1: Start Backend Server"
echo "  cd $PROJECT_DIR/backend"
echo "  python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload"
echo ""
echo "Terminal 2: Start Streamlit Admin Panel"
echo "  cd $PROJECT_DIR"
echo "  source venv/bin/activate"
echo "  streamlit run admin_panel/marketplace_admin.py"
echo ""
echo "Terminal 3: Start Flutter App"
echo "  cd $PROJECT_DIR/frontend"
echo "  flutter run"
echo ""
echo "🔐 Admin Panel Password: admin123"
echo "🌐 Admin Panel URL: http://localhost:8501"
echo "⚙️  Backend URL: http://127.0.0.1:8000"
echo ""
echo "📋 For more info, see: MARKETPLACE_ADMIN_SETUP.md"
