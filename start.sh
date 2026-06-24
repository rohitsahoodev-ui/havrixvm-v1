#!/bin/bash
echo "🚀 Installing Havrix VM..."

# Clone repository
git clone https://github.com/rohitsahoodev-ui/havrixvm-v1.git
cd havrixvm-v1

# Unzip if zip file exists
if [ -f "havrixvm-v1.zip" ]; then
    echo "📦 Extracting files..."
    unzip -o havrixvm-v1.zip
    # Move files from extracted folder to current directory
    if [ -d "havrixvm-v1" ]; then
        cp -r havrixvm-v1/* .
        rm -rf havrixvm-v1
    fi
fi

# Install Python
apt update
apt install python3 python3-pip python3-venv -y

# Setup virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Create database directory
mkdir -p database
chmod 777 database

# Fix database init
cat > database/__init__.py << 'EOF'
from flask_sqlalchemy import SQLAlchemy
import os
db = SQLAlchemy()
def init_db(app):
    os.makedirs(os.path.join(app.root_path, 'database'), exist_ok=True)
    db.init_app(app)
    with app.app_context():
        db.create_all()
        print("✅ Database ready")
def get_db():
    return db
EOF

# Fix app.py import
sed -i 's/from database import db, init_db/from database import db\nfrom database import init_db/g' app.py

# Install PM2
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install nodejs -y
npm install -g pm2

# Start with PM2
pm2 start app.py --name havrix --interpreter python3
pm2 save
pm2 startup

echo "✅ Installation Complete!"
echo "🌐 Access: http://localhost:5000"
echo "👤 Username: admin"
echo "🔑 Password: admin123"
