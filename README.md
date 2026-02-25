# Server Setup & Management Scripts Collection

A collection of bash scripts for automated server setup and management.

## 📁 Repository Structure
```
server-scripts/
├── docker/     # Docker and Portainer installation scripts
├── ssl/        # SSL/Certbot setup scripts
└── docs/       # Additional documentation
```

## 🚀 Available Scripts

### Docker & Portainer
- **`docker/install-docker-and-portainer.sh`** - Installs Docker and Portainer with interactive prompts

### SSL Configuration
- **`ssl/install-certbot-and-update-ssl.sh`** - Sets up Certbot and configures SSL certificates

## 📋 Usage

Each script is designed to be run directly from GitHub:

```bash
# Run Docker/Portainer installer
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/server-scripts/main/docker/install-docker-and-portainer.sh | bash

# Run SSL installer
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/server-scripts/main/ssl/install-certbot-and-update-ssl.sh | bash
```

## 🔒 Security Notes
All scripts use interactive prompts for sensitive information

No passwords or tokens are ever stored in the repository

Scripts prompt for secrets at runtime only

## 📝 Requirements
Ubuntu/Debian-based Linux system

Sudo privileges

Internet connection

## 🤝 Contributing
Feel free to submit issues or pull requests to improve these scripts.

## 📄 License
MIT
