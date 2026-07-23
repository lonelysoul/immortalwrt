cat > env-check.sh <<'EOF'
#!/usr/bin/env bash

set +e

OUT="env-check-$(hostname)-$(date +%Y%m%d-%H%M%S).txt"

exec > >(tee "$OUT") 2>&1

echo "============================================================"
echo " OpenWrt / DAED Build Environment Diagnostic"
echo "============================================================"
echo "Time: $(date -Is)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "PWD: $(pwd)"
echo

section() {
    echo
    echo "------------------------------------------------------------"
    echo "[$1]"
    echo "------------------------------------------------------------"
}

cmdver() {
    local name="$1"
    shift
    echo
    echo "### $name"
    if command -v "$1" >/dev/null 2>&1; then
        echo "PATH: $(command -v "$1")"
        "$@" 2>&1
    else
        echo "NOT INSTALLED"
    fi
}

section "OS / Kernel"

cat /etc/os-release 2>/dev/null
echo
uname -a
echo
uname -m
echo
lsb_release -a 2>/dev/null || true

section "CPU / Memory"

lscpu 2>/dev/null
echo
free -h
echo
nproc
echo
getconf _NPROCESSORS_ONLN

section "Disk / Filesystem"

df -h
echo
df -i
echo
mount | head -100

section "Compiler / Build Tools"

cmdver "GCC" gcc --version
cmdver "G++" g++ --version
cmdver "Clang" clang --version
cmdver "Clang++" clang++ --version
cmdver "Make" make --version
cmdver "GNU Make" gmake --version
cmdver "CMake" cmake --version
cmdver "Ninja" ninja --version
cmdver "ccache" ccache --version
cmdver "sccache" sccache --version

section "Binutils"

cmdver "ld" ld --version
cmdver "as" as --version
cmdver "ar" ar --version
cmdver "objcopy" objcopy --version
cmdver "strip" strip --version
cmdver "readelf" readelf --version

section "Git"

cmdver "Git" git --version
echo
git config --list --show-origin 2>/dev/null

section "Programming Languages"

cmdver "Go" go version
cmdver "Rust" rustc --version
cmdver "Cargo" cargo --version
cmdver "Python" python3 --version
cmdver "Python pip" pip3 --version
cmdver "Perl" perl --version
cmdver "Node.js" node --version
cmdver "npm" npm --version

section "Libraries / Development Tools"

cmdver "OpenSSL" openssl version -a
cmdver "pkg-config" pkg-config --version
cmdver "Autoconf" autoconf --version
cmdver "Automake" automake --version
cmdver "Bison" bison --version
cmdver "Flex" flex --version
cmdver "Patch" patch --version
cmdver "Tar" tar --version
cmdver "Gzip" gzip --version
cmdver "XZ" xz --version
cmdver "Bzip2" bzip2 --version
cmdver "Zstd" zstd --version

section "APT"

apt --version
echo
dpkg --print-architecture
echo
dpkg --print-foreign-architectures
echo
apt-mark showmanual 2>/dev/null | sort

section "Important Installed Packages"

dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n' 2>/dev/null | \
grep -E '^(build-essential|gcc|g\+\+|clang|llvm|make|git|python3|python3-dev|python3-setuptools|python3-pip|golang|golang-go|nodejs|npm|rustc|cargo|libc6|libc6-dev|libssl|openssl|libncurses|libncursesw|zlib1g|zlib1g-dev|gawk|gettext|unzip|file|rsync|wget|curl|xsltproc|swig|time|ccache|cmake|ninja-build|pkg-config|perl|bison|flex)' \
| sort

section "Environment Variables"

echo "PATH=$PATH"
echo
echo "HOME=$HOME"
echo
echo "SHELL=$SHELL"
echo
echo "LANG=$LANG"
echo "LC_ALL=$LC_ALL"
echo "CC=$CC"
echo "CXX=$CXX"
echo "AR=$AR"
echo "LD=$LD"
echo "GOFLAGS=$GOFLAGS"
echo "GOPATH=$GOPATH"
echo "GOROOT=$GOROOT"
echo "CGO_ENABLED=$CGO_ENABLED"
echo
env | sort

section "OpenWrt Directory"

if [ -d "./.git" ]; then
    echo "OpenWrt Git Root: $(git rev-parse --show-toplevel 2>/dev/null)"
    echo
    echo "Branch:"
    git branch --show-current 2>/dev/null
    echo
    echo "Commit:"
    git rev-parse HEAD 2>/dev/null
    echo
    echo "Describe:"
    git describe --always --dirty --tags 2>/dev/null
    echo
    echo "Status:"
    git status --short 2>/dev/null
    echo
    echo "Remote:"
    git remote -v 2>/dev/null
else
    echo "Current directory does not appear to be OpenWrt Git root."
fi

section "OpenWrt Version Files"

for f in \
    include/version.mk \
    include/kernel-version.mk \
    version \
    .config
do
    if [ -f "$f" ]; then
        echo
        echo "### $f"
        grep -E 'OPENWRT|VERSION|KERNEL|CONFIG_TARGET|CONFIG_PACKAGE|CONFIG_TOOLCHAIN|CONFIG_DEVEL' "$f" 2>/dev/null | head -200
    fi
done

section "OpenWrt Feeds"

if [ -f "feeds.conf" ]; then
    echo "### feeds.conf"
    cat feeds.conf
fi

if [ -f "feeds.conf.default" ]; then
    echo
    echo "### feeds.conf.default"
    cat feeds.conf.default
fi

section "DAED Source"

if [ -d "package/dae" ]; then
    echo "DAED directory exists: package/dae"
    echo
    find package/dae -maxdepth 2 -type f | sort | head -200
    echo
    if [ -d "package/dae/.git" ]; then
        cd package/dae
        echo "DAED Git:"
        git remote -v 2>/dev/null
        git branch --show-current 2>/dev/null
        git rev-parse HEAD 2>/dev/null
        git describe --always --dirty --tags 2>/dev/null
        cd - >/dev/null
    fi
else
    echo "package/dae not found"
fi

section "Host Tool Versions Summary"

for x in \
    gcc g++ clang clang++ make git python3 pip3 \
    go rustc cargo node npm \
    cmake ninja ccache \
    openssl pkg-config \
    bison flex gawk gettext \
    rsync curl wget unzip file \
    perl patch tar gzip xz zstd
do
    printf "%-15s : " "$x"
    if command -v "$x" >/dev/null 2>&1; then
        command -v "$x"
    else
        echo "NOT FOUND"
    fi
done

section "End"

echo "Output file:"
echo "$OUT"

EOF

chmod +x env-check.sh
./env-check.sh
