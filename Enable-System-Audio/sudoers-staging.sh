#!/bin/bash
# sudoers-staging.sh
# Jamf Pro Script — deploys sudoers drop-in for NotionAudioEnabler
# Run as: root (Jamf policies run scripts as root by default)
# Frequency: Once per computer

SUDOERS_FILE="/etc/sudoers.d/notion-audio-enabler"

if [ -f "$SUDOERS_FILE" ]; then
    echo "Sudoers rule already exists at $SUDOERS_FILE — skipping."
    exit 0
fi

cat > "$SUDOERS_FILE" << 'EOF'
# Allow staff group to run dseditgroup admin add/remove without password
# Scoped to the exact commands needed by NotionAudioEnabler
%staff ALL=(root) NOPASSWD: /usr/sbin/dseditgroup -o edit -a * -t user admin
%staff ALL=(root) NOPASSWD: /usr/sbin/dseditgroup -o edit -d * -t user admin
EOF

chmod 440 "$SUDOERS_FILE"
chown root:wheel "$SUDOERS_FILE"

# Validate syntax
if /usr/sbin/visudo -c -f "$SUDOERS_FILE" 2>/dev/null; then
    echo "Sudoers rule installed and validated at $SUDOERS_FILE"
    exit 0
else
    echo "ERROR: Sudoers syntax check failed — removing invalid file"
    rm -f "$SUDOERS_FILE"
    exit 1
fi
