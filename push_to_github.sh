#!/bin/bash
# ================================================================
# Push fc_fpga to GitHub
# Prerequisites: VPN connected, gh CLI authenticated
# Usage: bash push_to_github.sh
# ================================================================
set -e

cd "$(dirname "$0")"

echo "=== Step 1: Verify GitHub connectivity ==="
if curl -s --connect-timeout 5 https://github.com > /dev/null 2>&1; then
    echo "  [OK] GitHub is reachable"
else
    echo "  [FAIL] GitHub is NOT reachable — turn on VPN first!"
    exit 1
fi

echo ""
echo "=== Step 2: Log in to GitHub CLI (if needed) ==="
if gh auth status 2>&1 | grep -q "Logged in"; then
    echo "  [OK] Already logged in as: $(gh auth status 2>&1 | grep 'Logged in' | sed 's/.*as //' | head -1)"
else
    echo "  Logging in via browser..."
    gh auth login --web --hostname github.com
fi

echo ""
echo "=== Step 3: Create remote repo ==="
if gh repo view GentleBreezeBlow/fc_fpga --json name 2>/dev/null | grep -q "fc_fpga"; then
    echo "  [OK] Repo fc_fpga already exists"
else
    echo "  Creating GentleBreezeBlow/fc_fpga..."
    gh repo create GentleBreezeBlow/fc_fpga \
        --public \
        --description "FPGA RTL sync tool — auto-sync fpga_v from rtl_v with FPGA_SYN block preservation" \
        --source . \
        --remote origin \
        --push
    echo "  [OK] Repo created and code pushed!"
    exit 0
fi

echo ""
echo "=== Step 4: Add remote and push ==="
if git remote get-url origin 2>/dev/null | grep -q "GentleBreezeBlow"; then
    echo "  [OK] Remote origin already set"
else
    git remote remove origin 2>/dev/null || true
    git remote add origin https://github.com/GentleBreezeBlow/fc_fpga.git
    echo "  [OK] Remote origin added"
fi

echo "  Pushing to origin/master..."
git push -u origin master

echo ""
echo "=== Done! ==="
echo "Repo: https://github.com/GentleBreezeBlow/fc_fpga"
echo ""
echo "=== On another machine, clone with: ==="
echo "  git clone https://github.com/GentleBreezeBlow/fc_fpga.git"
echo "  cd fc_fpga"
echo "  source test_soc/run_test.sh   # set env vars"
echo "  python fpga.py --help"
