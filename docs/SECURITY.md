# Security Policy

## 🔒 Security Best Practices

### No Hardcoded Secrets
- ✅ No passwords, API keys, or tokens in scripts
- ✅ All secrets are prompted interactively at runtime

### Interactive Secrets Management
- 🔐 Passwords are masked during input (`read -s`)
- 🔐 Secrets never appear in command history
- 🔐 Secrets not visible in process lists

### Secure File Handling
- 📁 Temporary files use restricted permissions (600)
- 📁 Secure deletion with `shred` when available
- 📁 Automatic backups before file modifications

## 📋 For Script Users

### Before Running
```bash
# Always review scripts first
curl -sSL https://raw.githubusercontent.com/metquay/metquay-server-scripts/main/SCRIPT_PATH.sh | less
```

### During Execution
```bash
# ✅ CORRECT - Let scripts prompt you
curl -sSL https://.../script.sh | sudo bash

# ❌ INCORRECT - Never pass secrets as arguments
curl -sSL https://.../script.sh | sudo bash -s -- "MyPassword"  # BAD
```

### After Execution
```bash
# Verify success
echo $?                    # Should return 0
# Check specific services as documented in script output
```

## 🚫 What Scripts NEVER Do
❌ Store passwords in files

❌ Open firewall ports automatically

❌ Disable security features

❌ Send data over the network

❌ Install untrusted software

## ✅ Quick Checklist
Review the script before running

Use interactive prompts only

Verify services after install

Configure the firewall manually if needed

## 📧 Reporting Vulnerabilities
Email: support@metquay.atlassian.net

Do NOT open public issues

Allow 7 days for fixes

## 📚 Resources
- [Docker Security](https://docs.docker.com/engine/security/) - Official Docker security documentation
- [Let's Encrypt Security](https://letsencrypt.org/security/) - Let's Encrypt security practices
- [Certbot Documentation](https://certbot.eff.org/docs/) - Certbot SSL tool documentation
- [OpenSSL Security](https://www.openssl.org/docs/security.html) - OpenSSL security information

---

*Last updated: February 2026*
