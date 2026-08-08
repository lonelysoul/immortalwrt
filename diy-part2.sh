# rm -rf feeds/packages/lang/rust
# git clone https://github.com/sbwml/packages_lang_rust feeds/packages/lang/rust
sed -i 's/--set=llvm\.download-ci-llvm=false/--set=llvm.download-ci-llvm=true/' feeds/packages/lang/rust/Makefile